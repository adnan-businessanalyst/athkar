from datetime import datetime, timezone

from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models import RefreshToken, User
from app.security import current_user

router = APIRouter()


@router.delete("/account", status_code=status.HTTP_204_NO_CONTENT)
def delete_account(
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    now = datetime.now(timezone.utc)
    user.deleted_at = now
    user.updated_at = now
    tokens = db.scalars(
        select(RefreshToken).where(
            RefreshToken.user_id == user.id,
            RefreshToken.revoked_at.is_(None),
        )
    )
    for token in tokens:
        token.revoked_at = now
    db.commit()
