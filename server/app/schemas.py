import uuid
from datetime import date, datetime

from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str | None = Field(default=None, max_length=120)
    device_id: str | None = Field(default=None, max_length=128)
    platform: str | None = Field(default=None, max_length=32)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)
    device_id: str | None = Field(default=None, max_length=128)
    platform: str | None = Field(default=None, max_length=32)


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str


class UserOut(BaseModel):
    id: uuid.UUID
    email: str
    display_name: str | None = None


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserOut


class LocationSync(BaseModel):
    latitude: float
    longitude: float
    label: str = Field(max_length=255)
    source: str = Field(max_length=32)
    city: str | None = Field(default=None, max_length=120)
    country: str | None = Field(default=None, max_length=120)
    updated_at: datetime
    revision: int = 0


class SettingsSync(BaseModel):
    adhan_enabled: bool = True
    muted_prayers: list[str] = Field(default_factory=list)
    calculation_method: str = Field(default="umm_al_qura", max_length=64)
    madhab: str = Field(default="shafi", max_length=32)
    updated_at: datetime
    revision: int = 0


class CounterSync(BaseModel):
    id: str = Field(min_length=1, max_length=64)
    name: str = Field(max_length=120)
    count: int = 0
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None
    revision: int = 0


class CollectionSync(BaseModel):
    id: str = Field(min_length=1, max_length=64)
    name: str = Field(max_length=120)
    description: str = ""
    is_default: bool = False
    is_favorite: bool = False
    reminder_enabled: bool = False
    reminder_hour: int | None = None
    reminder_minute: int | None = None
    updated_at: datetime
    deleted_at: datetime | None = None
    revision: int = 0


class ItemSync(BaseModel):
    id: str = Field(min_length=1, max_length=64)
    collection_id: str = Field(min_length=1, max_length=64)
    text: str
    repeat_count: int = 1
    progress: int = 0
    sort_order: int = 0
    updated_at: datetime
    deleted_at: datetime | None = None
    revision: int = 0


class DailyProgressSync(BaseModel):
    collection_id: str = Field(min_length=1, max_length=64)
    date: date
    completed: bool = False
    completed_at: datetime | None = None
    items_done: int = 0
    items_total: int = 0
    updated_at: datetime
    deleted_at: datetime | None = None
    revision: int = 0


class SyncPushRequest(BaseModel):
    since: int = 0
    location: LocationSync | None = None
    settings: SettingsSync | None = None
    counters: list[CounterSync] = Field(default_factory=list)
    collections: list[CollectionSync] = Field(default_factory=list)
    items: list[ItemSync] = Field(default_factory=list)
    daily_progress: list[DailyProgressSync] = Field(default_factory=list)


class SyncResponse(BaseModel):
    revision: int
    location: LocationSync | None = None
    settings: SettingsSync | None = None
    counters: list[CounterSync] = Field(default_factory=list)
    collections: list[CollectionSync] = Field(default_factory=list)
    items: list[ItemSync] = Field(default_factory=list)
    daily_progress: list[DailyProgressSync] = Field(default_factory=list)
