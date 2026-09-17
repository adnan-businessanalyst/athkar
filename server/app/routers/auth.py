from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.deps import get_db
from app.models import Device, Profile, RefreshToken, User
from app.redis_client import rate_limit
from app.schemas import (
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
    UserOut,
)
from app.security import (
    DUMMY_PASSWORD_HASH,
    create_access_token,
    current_user,
    hash_password,
    hash_refresh_token,
    new_refresh_token,
    verify_password,
)

router = APIRouter()


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _touch_device(db: Session, user: User, device_id: str | None, platform: str | None) -> None:
    if not device_id:
        return
    row = db.scalar(
        select(Device).where(Device.user_id == user.id, Device.device_id == device_id)
    )
    now = datetime.now(timezone.utc)
    if row:
        row.last_seen = now
        if platform:
            row.platform = platform
        return
    db.add(
        Device(
            user_id=user.id,
            device_id=device_id,
            platform=platform or "unknown",
            last_seen=now,
        )
    )


def _issue_tokens(db: Session, user: User, display_name: str | None) -> TokenResponse:
    raw_refresh = new_refresh_token()
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_refresh_token(raw_refresh),
            expires_at=datetime.now(timezone.utc)
            + timedelta(days=settings.jwt_refresh_days),
        )
    )
    db.commit()
    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=raw_refresh,
        expires_in=settings.jwt_access_minutes * 60,
        user=UserOut(id=user.id, email=user.email, display_name=display_name),
    )


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(body: RegisterRequest, request: Request, db: Session = Depends(get_db)):
    if not rate_limit(f"rl:register:{_client_ip(request)}", limit=5, window_seconds=3600):
        raise HTTPException(status_code=429, detail="Too many registrations")
    email = _normalize_email(str(body.email))
    existing = db.scalar(select(User).where(User.email == email))
    if existing is not None:
        raise HTTPException(status_code=409, detail="Email already registered")
    user = User(email=email, password_hash=hash_password(body.password))
    db.add(user)
    db.flush()
    profile = Profile(user_id=user.id, display_name=body.display_name)
    db.add(profile)
    _touch_device(db, user, body.device_id, body.platform)
    return _issue_tokens(db, user, body.display_name)


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest, request: Request, db: Session = Depends(get_db)):
    if not rate_limit(f"rl:login:{_client_ip(request)}", limit=8, window_seconds=900):
        raise HTTPException(status_code=429, detail="Too many login attempts")
    email = _normalize_email(str(body.email))
    user = db.scalar(select(User).where(User.email == email))
    password_hash = user.password_hash if user is not None else DUMMY_PASSWORD_HASH
    ok = verify_password(body.password, password_hash)
    if user is None or user.deleted_at is not None or not ok:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    _touch_device(db, user, body.device_id, body.platform)
    profile = db.get(Profile, user.id)
    return _issue_tokens(db, user, profile.display_name if profile else None)


@router.post("/refresh", response_model=TokenResponse)
def refresh(body: RefreshRequest, request: Request, db: Session = Depends(get_db)):
    if not rate_limit(f"rl:refresh:{_client_ip(request)}", limit=30, window_seconds=900):
        raise HTTPException(status_code=429, detail="Too many refresh attempts")
    token_hash = hash_refresh_token(body.refresh_token)
    row = db.scalar(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
    now = datetime.now(timezone.utc)
    expires_at = row.expires_at if row is not None else now
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if (
        row is None
        or row.revoked_at is not None
        or expires_at <= now
    ):
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    user = db.get(User, row.user_id)
    if user is None or user.deleted_at is not None:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    row.revoked_at = now
    profile = db.get(Profile, user.id)
    return _issue_tokens(db, user, profile.display_name if profile else None)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    body: LogoutRequest,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    token_hash = hash_refresh_token(body.refresh_token)
    row = db.scalar(
        select(RefreshToken).where(
            RefreshToken.token_hash == token_hash,
            RefreshToken.user_id == user.id,
        )
    )
    if row is not None and row.revoked_at is None:
        row.revoked_at = datetime.now(timezone.utc)
        db.commit()


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(current_user), db: Session = Depends(get_db)):
    profile = db.get(Profile, user.id)
    return UserOut(
        id=user.id,
        email=user.email,
        display_name=profile.display_name if profile else None,
    )
