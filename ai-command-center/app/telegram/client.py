"""Minimal Telegram Bot API client (httpx). No third-party bot framework needed.

Dry-run mode (default outside prod): messages are written to the 'outbox' table
and the log instead of being sent. The token is never logged.
"""
from __future__ import annotations

import httpx

from app.config import Settings
from app.db import Database, utcnow
from app.errors import TelegramError
from app.logging_setup import get_logger

log = get_logger("telegram")
MAX_LEN = 4096  # Telegram message length limit


class TelegramClient:
    def __init__(self, settings: Settings, db: Database, transport: httpx.BaseTransport | None = None):
        self.s, self.db = settings, db
        self._http = httpx.Client(timeout=40, transport=transport)

    def _url(self, method: str) -> str:
        if not self.s.telegram_bot_token:
            raise TelegramError("TELEGRAM_BOT_TOKEN is not set")
        return f"{self.s.telegram_api_base}/bot{self.s.telegram_bot_token.get_secret_value()}/{method}"

    def call(self, method: str, **params) -> dict:
        try:
            r = self._http.post(self._url(method), json=params)
            data = r.json()
        except (httpx.HTTPError, ValueError) as e:
            # str(e) can contain the URL (with the token) -> only report the type.
            raise TelegramError(f"{method} failed: {type(e).__name__}") from None
        if not data.get("ok"):
            raise TelegramError(f"{method} rejected: {data.get('error_code')} {data.get('description')}")
        return data["result"]

    def send_message(self, chat_id: int, text: str) -> bool:
        """Returns True if really sent, False if dry-run."""
        text = text if len(text) <= MAX_LEN else text[: MAX_LEN - 20] + "\n…(잘림)"
        sent = not self.s.telegram_dry_run
        if sent:
            self.call("sendMessage", chat_id=chat_id, text=text, disable_web_page_preview=True)
        else:
            log.info("[dry-run] to %s: %s", chat_id, text.replace("\n", " | ")[:200])
        self.db.execute("INSERT INTO outbox(at, channel, target, text, sent) VALUES (?,?,?,?,?)",
                        (utcnow(), "telegram", str(chat_id), text, int(sent)))
        return sent

    def get_updates(self, offset: int | None = None, timeout: int = 0) -> list[dict]:
        params = {"timeout": timeout, "allowed_updates": ["message"]}
        if offset is not None:
            params["offset"] = offset
        return self.call("getUpdates", **params)

    def get_me(self) -> dict:
        return self.call("getMe")
