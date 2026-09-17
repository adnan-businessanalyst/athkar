import logging
import re

_SECRET = re.compile(
    r"(bearer\s+[a-z0-9._\-]+|refresh_token|access_token|password)([\"':=\s]+)[^,\s\"']+",
    re.IGNORECASE,
)


class RedactingFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        record.msg = _SECRET.sub(r"\1\2***", str(record.msg))
        if record.args:
            record.args = tuple(
                _SECRET.sub(r"\1\2***", str(arg)) if isinstance(arg, str) else arg
                for arg in record.args
            )
        return True


def configure_logging() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    redactor = RedactingFilter()
    for handler in logging.getLogger().handlers:
        handler.addFilter(redactor)
