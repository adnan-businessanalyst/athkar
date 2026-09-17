from fastapi import FastAPI
from sqlalchemy import text

from app.db import engine

app = FastAPI(title="Athkar API", version="0.1.0")


@app.get("/health")
def health():
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    return {"ok": True}
