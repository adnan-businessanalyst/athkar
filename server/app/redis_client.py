import redis

from app.config import settings

redis_client = redis.Redis.from_url(settings.redis_url, decode_responses=True)


def rate_limit(key: str, limit: int, window_seconds: int) -> bool:
    """Return True if the caller is allowed. Fail open if Redis is down."""
    try:
        current = redis_client.incr(key)
        if current == 1:
            redis_client.expire(key, window_seconds)
        return current <= limit
    except redis.RedisError:
        return True
