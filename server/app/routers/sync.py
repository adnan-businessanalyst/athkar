from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models import (
    Collection,
    CollectionItem,
    Counter,
    DailyProgress,
    Location,
    Settings,
    User,
)
from app.redis_client import rate_limit, redis_client
from app.schemas import (
    CollectionSync,
    CounterSync,
    DailyProgressSync,
    ItemSync,
    LocationSync,
    SettingsSync,
    SyncPushRequest,
    SyncResponse,
)
from app.security import current_user

router = APIRouter()


def _aware(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _newer(client_at: datetime, server_at: datetime | None) -> bool:
    if server_at is None:
        return True
    return _aware(client_at) > _aware(server_at)  # type: ignore[operator]


def _guard_sync(user: User) -> None:
    if not rate_limit(f"rl:sync:{user.id}", limit=60, window_seconds=900):
        raise HTTPException(status_code=429, detail="Too many sync requests")


def _invalidate_snapshot(user_id) -> None:
    try:
        redis_client.delete(f"user:{user_id}:snapshot")
    except Exception:
        return


def _location_out(row: Location) -> LocationSync:
    return LocationSync(
        latitude=row.latitude,
        longitude=row.longitude,
        label=row.label,
        source=row.source,
        city=row.city,
        country=row.country,
        updated_at=row.updated_at,
        revision=row.revision,
    )


def _settings_out(row: Settings) -> SettingsSync:
    return SettingsSync(
        adhan_enabled=row.adhan_enabled,
        muted_prayers=list(row.muted_prayers or []),
        calculation_method=row.calculation_method,
        madhab=row.madhab,
        updated_at=row.updated_at,
        revision=row.revision,
    )


def _counter_out(row: Counter) -> CounterSync:
    return CounterSync(
        id=row.id,
        name=row.name,
        count=row.count,
        created_at=row.created_at,
        updated_at=row.updated_at,
        deleted_at=row.deleted_at,
        revision=row.revision,
    )


def _collection_out(row: Collection) -> CollectionSync:
    return CollectionSync(
        id=row.id,
        name=row.name,
        description=row.description,
        is_default=row.is_default,
        is_favorite=row.is_favorite,
        reminder_enabled=row.reminder_enabled,
        reminder_hour=row.reminder_hour,
        reminder_minute=row.reminder_minute,
        updated_at=row.updated_at,
        deleted_at=row.deleted_at,
        revision=row.revision,
    )


def _item_out(row: CollectionItem) -> ItemSync:
    return ItemSync(
        id=row.id,
        collection_id=row.collection_id,
        text=row.text,
        repeat_count=row.repeat_count,
        progress=row.progress,
        sort_order=row.sort_order,
        updated_at=row.updated_at,
        deleted_at=row.deleted_at,
        revision=row.revision,
    )


def _progress_out(row: DailyProgress) -> DailyProgressSync:
    return DailyProgressSync(
        collection_id=row.collection_id,
        date=row.date,
        completed=row.completed,
        completed_at=row.completed_at,
        items_done=row.items_done,
        items_total=row.items_total,
        updated_at=row.updated_at,
        deleted_at=row.deleted_at,
        revision=row.revision,
    )


def _pull(db: Session, user: User, since: int) -> SyncResponse:
    location = db.get(Location, user.id)
    settings = db.get(Settings, user.id)
    counters = db.scalars(
        select(Counter).where(Counter.user_id == user.id, Counter.revision > since)
    ).all()
    collections = db.scalars(
        select(Collection).where(
            Collection.user_id == user.id, Collection.revision > since
        )
    ).all()
    items = db.scalars(
        select(CollectionItem).where(
            CollectionItem.user_id == user.id, CollectionItem.revision > since
        )
    ).all()
    progress = db.scalars(
        select(DailyProgress).where(
            DailyProgress.user_id == user.id, DailyProgress.revision > since
        )
    ).all()
    return SyncResponse(
        revision=user.sync_revision,
        location=_location_out(location)
        if location is not None and location.revision > since
        else None,
        settings=_settings_out(settings)
        if settings is not None and settings.revision > since
        else None,
        counters=[_counter_out(row) for row in counters],
        collections=[_collection_out(row) for row in collections],
        items=[_item_out(row) for row in items],
        daily_progress=[_progress_out(row) for row in progress],
    )


@router.get("/sync", response_model=SyncResponse)
def get_sync(
    since: int = Query(default=0, ge=0),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    _guard_sync(user)
    return _pull(db, user, since)


@router.post("/sync", response_model=SyncResponse)
def post_sync(
    body: SyncPushRequest,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    _guard_sync(user)
    applied = False
    new_rev = (user.sync_revision or 0) + 1

    if body.location is not None:
        row = db.get(Location, user.id)
        if row is None or _newer(body.location.updated_at, row.updated_at):
            if row is None:
                row = Location(user_id=user.id)
                db.add(row)
            row.latitude = body.location.latitude
            row.longitude = body.location.longitude
            row.label = body.location.label
            row.source = body.location.source
            row.city = body.location.city
            row.country = body.location.country
            row.updated_at = _aware(body.location.updated_at)
            row.revision = new_rev
            applied = True

    if body.settings is not None:
        row = db.get(Settings, user.id)
        if row is None or _newer(body.settings.updated_at, row.updated_at):
            if row is None:
                row = Settings(user_id=user.id)
                db.add(row)
            row.adhan_enabled = body.settings.adhan_enabled
            row.muted_prayers = body.settings.muted_prayers
            row.calculation_method = body.settings.calculation_method
            row.madhab = body.settings.madhab
            row.updated_at = _aware(body.settings.updated_at)
            row.revision = new_rev
            applied = True

    for item in body.counters:
        row = db.get(Counter, (user.id, item.id))
        if row is None or _newer(item.updated_at, row.updated_at):
            if row is None:
                row = Counter(id=item.id, user_id=user.id, created_at=_aware(item.created_at))
                db.add(row)
            row.name = item.name
            row.count = item.count
            row.updated_at = _aware(item.updated_at)
            row.deleted_at = _aware(item.deleted_at)
            row.revision = new_rev
            applied = True

    for item in body.collections:
        row = db.get(Collection, (user.id, item.id))
        if row is None or _newer(item.updated_at, row.updated_at):
            if row is None:
                row = Collection(id=item.id, user_id=user.id)
                db.add(row)
            row.name = item.name
            row.description = item.description
            row.is_default = item.is_default
            row.is_favorite = item.is_favorite
            row.reminder_enabled = item.reminder_enabled
            row.reminder_hour = item.reminder_hour
            row.reminder_minute = item.reminder_minute
            row.updated_at = _aware(item.updated_at)
            row.deleted_at = _aware(item.deleted_at)
            row.revision = new_rev
            applied = True

    db.flush()

    for item in body.items:
        row = db.get(CollectionItem, (user.id, item.id))
        collection = db.get(Collection, (user.id, item.collection_id))
        if collection is None:
            raise HTTPException(status_code=400, detail="Unknown collection for item")
        if row is None or _newer(item.updated_at, row.updated_at):
            if row is None:
                row = CollectionItem(id=item.id, user_id=user.id)
                db.add(row)
            row.collection_id = item.collection_id
            row.text = item.text
            row.repeat_count = item.repeat_count
            row.progress = item.progress
            row.sort_order = item.sort_order
            row.updated_at = _aware(item.updated_at)
            row.deleted_at = _aware(item.deleted_at)
            row.revision = new_rev
            applied = True

    for item in body.daily_progress:
        row = db.get(DailyProgress, (user.id, item.collection_id, item.date))
        if row is None or _newer(item.updated_at, row.updated_at):
            if row is None:
                row = DailyProgress(
                    user_id=user.id,
                    collection_id=item.collection_id,
                    date=item.date,
                )
                db.add(row)
            row.completed = item.completed
            row.completed_at = _aware(item.completed_at)
            row.items_done = item.items_done
            row.items_total = item.items_total
            row.updated_at = _aware(item.updated_at)
            row.deleted_at = _aware(item.deleted_at)
            row.revision = new_rev
            applied = True

    if applied:
        user.sync_revision = new_rev
        _invalidate_snapshot(user.id)
    db.commit()
    db.refresh(user)
    return _pull(db, user, body.since)
