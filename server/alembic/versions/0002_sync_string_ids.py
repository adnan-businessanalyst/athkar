"""sync revision, string ids, composite keys per user

Revision ID: 0002_sync_ids
Revises: 0001_initial
Create Date: 2026-09-17

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0002_sync_ids"
down_revision: Union[str, Sequence[str], None] = "0001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("sync_revision", sa.BigInteger(), nullable=False, server_default="0"),
    )

    op.drop_constraint(
        "collection_items_collection_id_fkey", "collection_items", type_="foreignkey"
    )
    op.drop_constraint("collection_items_pkey", "collection_items", type_="primary")
    op.drop_constraint("collections_pkey", "collections", type_="primary")
    op.drop_constraint("counters_pkey", "counters", type_="primary")

    op.alter_column(
        "counters",
        "id",
        existing_type=postgresql.UUID(as_uuid=True),
        type_=sa.String(64),
        postgresql_using="id::text",
    )
    op.alter_column(
        "collections",
        "id",
        existing_type=postgresql.UUID(as_uuid=True),
        type_=sa.String(64),
        postgresql_using="id::text",
    )
    op.alter_column(
        "collection_items",
        "id",
        existing_type=postgresql.UUID(as_uuid=True),
        type_=sa.String(64),
        postgresql_using="id::text",
    )
    op.alter_column(
        "collection_items",
        "collection_id",
        existing_type=postgresql.UUID(as_uuid=True),
        type_=sa.String(64),
        postgresql_using="collection_id::text",
    )
    op.alter_column(
        "daily_progress",
        "collection_id",
        existing_type=postgresql.UUID(as_uuid=True),
        type_=sa.String(64),
        postgresql_using="collection_id::text",
    )

    op.create_primary_key("counters_pkey", "counters", ["user_id", "id"])
    op.create_primary_key("collections_pkey", "collections", ["user_id", "id"])
    op.create_primary_key("collection_items_pkey", "collection_items", ["user_id", "id"])
    op.create_foreign_key(
        "collection_items_collection_fkey",
        "collection_items",
        "collections",
        ["user_id", "collection_id"],
        ["user_id", "id"],
        ondelete="CASCADE",
    )
    op.create_index("ix_counters_user_revision", "counters", ["user_id", "revision"])
    op.create_index(
        "ix_collections_user_revision", "collections", ["user_id", "revision"]
    )
    op.create_index(
        "ix_collection_items_user_revision",
        "collection_items",
        ["user_id", "revision"],
    )
    op.create_index(
        "ix_daily_progress_user_revision", "daily_progress", ["user_id", "revision"]
    )


def downgrade() -> None:
    op.drop_index("ix_daily_progress_user_revision", table_name="daily_progress")
    op.drop_index("ix_collection_items_user_revision", table_name="collection_items")
    op.drop_index("ix_collections_user_revision", table_name="collections")
    op.drop_index("ix_counters_user_revision", table_name="counters")
    op.drop_constraint(
        "collection_items_collection_fkey", "collection_items", type_="foreignkey"
    )
    op.drop_constraint("collection_items_pkey", "collection_items", type_="primary")
    op.drop_constraint("collections_pkey", "collections", type_="primary")
    op.drop_constraint("counters_pkey", "counters", type_="primary")
    op.alter_column(
        "daily_progress",
        "collection_id",
        existing_type=sa.String(64),
        type_=postgresql.UUID(as_uuid=True),
        postgresql_using="collection_id::uuid",
    )
    op.alter_column(
        "collection_items",
        "collection_id",
        existing_type=sa.String(64),
        type_=postgresql.UUID(as_uuid=True),
        postgresql_using="collection_id::uuid",
    )
    op.alter_column(
        "collection_items",
        "id",
        existing_type=sa.String(64),
        type_=postgresql.UUID(as_uuid=True),
        postgresql_using="id::uuid",
    )
    op.alter_column(
        "collections",
        "id",
        existing_type=sa.String(64),
        type_=postgresql.UUID(as_uuid=True),
        postgresql_using="id::uuid",
    )
    op.alter_column(
        "counters",
        "id",
        existing_type=sa.String(64),
        type_=postgresql.UUID(as_uuid=True),
        postgresql_using="id::uuid",
    )
    op.create_primary_key("counters_pkey", "counters", ["id"])
    op.create_primary_key("collections_pkey", "collections", ["id"])
    op.create_primary_key("collection_items_pkey", "collection_items", ["id"])
    op.create_foreign_key(
        "collection_items_collection_id_fkey",
        "collection_items",
        "collections",
        ["collection_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.drop_column("users", "sync_revision")
