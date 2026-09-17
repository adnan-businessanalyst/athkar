import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.db import engine
from app.logging_setup import configure_logging
from app.routers import account, auth, sync

configure_logging()

app = FastAPI(title="Athkar API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://athkar.ghurabi.com",
        "http://localhost",
        "http://127.0.0.1",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(auth.router, prefix="/auth")
app.include_router(account.router)
app.include_router(sync.router)


@app.middleware("http")
async def access_log(request: Request, call_next):
    response = await call_next(request)
    logging.info("%s %s %s", request.method, request.url.path, response.status_code)
    return response


@app.get("/health")
def health():
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    return {"ok": True}
