"""Receive messages by long polling (no public server/port needed).

poll_once(): process pending messages once and exit (usable from GitHub Actions or manually).
run_forever(): continuous loop - only meaningful on an always-on machine (ROADMAP step 9/11).
The next offset is stored in the DB so messages are not processed twice.
"""
from __future__ import annotations

import time

from app.errors import TelegramError
from app.logging_setup import get_logger
from app.telegram.bot import CommandBot

log = get_logger("poller")
_OFFSET_KEY = "telegram_offset"


def _get_offset(db) -> int | None:
    row = db.one("SELECT value FROM meta WHERE key=?", (_OFFSET_KEY,))
    return int(row["value"]) if row else None


def poll_once(services, timeout: int = 0) -> int:
    services.settings.validate_for("telegram")
    bot = CommandBot(services)
    updates = services.telegram.get_updates(offset=_get_offset(services.db), timeout=timeout)
    for u in updates:
        try:
            bot.handle_update(u)
        except Exception:
            log.exception("update %s failed", u.get("update_id"))
        services.db.execute("INSERT OR REPLACE INTO meta(key, value) VALUES (?, ?)",
                            (_OFFSET_KEY, str(u["update_id"] + 1)))
    return len(updates)


def run_forever(services) -> None:  # pragma: no cover - needs a real always-on host
    log.info("telegram polling started (Ctrl+C to stop)")
    backoff = 1
    while True:
        try:
            poll_once(services, timeout=30)
            backoff = 1
        except TelegramError as e:
            log.warning("polling error: %s (retry in %ss)", e, backoff)
            time.sleep(backoff)
            backoff = min(backoff * 2, 60)
