import json

import httpx
import pytest

from app.config import Settings
from app.core import build_services

TOKEN = "123456789:AAFakeTokenForTestsOnly_abcdefghijklmnop"
OWNER = 1111


def make_settings(tmp_path, **kw):
    base = dict(app_env="test", data_dir=tmp_path / "data", log_dir=tmp_path / "logs",
                telegram_allowed_user_ids=[OWNER], telegram_dry_run=True)
    base.update(kw)
    return Settings(_env_file=None, **base)


class FakeTelegram:
    """Records Bot API requests and returns canned responses."""

    def __init__(self, updates=None):
        self.requests, self.updates = [], updates or []

    def __call__(self, request: httpx.Request):
        method = request.url.path.rsplit("/", 1)[-1]
        body = json.loads(request.content or b"{}")
        self.requests.append((method, body))
        if method == "getUpdates":
            off = body.get("offset") or 0
            return httpx.Response(200, json={"ok": True, "result": [u for u in self.updates if u["update_id"] >= off]})
        if method == "getMe":
            return httpx.Response(200, json={"ok": True, "result": {"id": 1, "username": "test_bot"}})
        return httpx.Response(200, json={"ok": True, "result": {"message_id": 1}})


@pytest.fixture
def fake_tg():
    return FakeTelegram()


@pytest.fixture
def svc(tmp_path, fake_tg):
    s = build_services(make_settings(tmp_path), http_transport=httpx.MockTransport(fake_tg))
    yield s
    s.db.close()


def msg(update_id, user_id, text, chat_type="private", chat_id=None):
    return {"update_id": update_id, "message": {
        "message_id": update_id, "text": text, "from": {"id": user_id, "first_name": "t"},
        "chat": {"id": chat_id if chat_id is not None else user_id, "type": chat_type}}}
