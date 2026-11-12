"""Logging with automatic secret masking (console + rotating file per environment)."""
from __future__ import annotations

import logging
import re
from logging.handlers import RotatingFileHandler

from app.config import Settings

# Telegram bot tokens, Google API keys, Anthropic/OpenAI style keys, Bearer tokens.
_PATTERNS = [
    re.compile(r"(?<![0-9])\d{6,12}:[A-Za-z0-9_-]{30,}"),  # also inside URLs (".../bot<token>/...")
    re.compile(r"\bAIza[0-9A-Za-z_-]{30,}\b"),
    re.compile(r"\bsk-[A-Za-z0-9_-]{16,}\b"),
    re.compile(r"(?i)(bearer\s+)[A-Za-z0-9._-]{8,}"),
]
MASK = "***REDACTED***"


def redact(text: str, extra_secrets: list[str] | None = None) -> str:
    for s in extra_secrets or []:
        if s and len(s) >= 4:
            text = text.replace(s, MASK)
    for p in _PATTERNS:
        text = p.sub(lambda m: (m.group(1) if m.lastindex else "") + MASK, text)
    return text


class RedactingFilter(logging.Filter):
    def __init__(self, secrets: list[str]):
        super().__init__()
        self.secrets = secrets

    def filter(self, record: logging.LogRecord) -> bool:
        msg = record.getMessage()
        if record.exc_info:
            msg += "\n" + logging.Formatter().formatException(record.exc_info)
            record.exc_info = None
            record.exc_text = None
        record.msg = redact(msg, self.secrets)
        record.args = None
        return True


def setup_logging(settings: Settings) -> logging.Logger:
    root = logging.getLogger("acc")
    root.setLevel(settings.log_level.upper())
    for h in list(root.handlers):
        root.removeHandler(h)
        h.close()
    fmt = logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s")
    settings.log_dir.mkdir(parents=True, exist_ok=True)
    handlers = [
        logging.StreamHandler(),
        RotatingFileHandler(settings.log_dir / f"{settings.app_env.value}.log",
                            maxBytes=1_000_000, backupCount=3, encoding="utf-8"),
    ]
    flt = RedactingFilter(settings.secret_values())
    for h in handlers:
        h.setFormatter(fmt)
        h.addFilter(flt)
        root.addHandler(h)
    root.propagate = False
    return root


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(f"acc.{name}")
