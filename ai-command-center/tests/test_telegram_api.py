import httpx
import pytest

from app.api import create_app
from app.core import build_services
from app.errors import ConfigError, TelegramError
from app.telegram.bot import CommandBot, is_authorized
from app.telegram.poller import poll_once
from tests.conftest import OWNER, TOKEN, FakeTelegram, make_settings, msg


def test_authorization_rules():
    ids = [OWNER]
    assert is_authorized(msg(1, OWNER, "/start"), ids)
    assert not is_authorized(msg(1, 999, "/start"), ids)
    assert not is_authorized(msg(1, OWNER, "/start", chat_type="group", chat_id=-5), ids)
    assert not is_authorized({"update_id": 1}, ids)


@pytest.mark.parametrize("text,expect", [
    ("/start", "허용된 사용자"), ("/help", "/today"), ("/status", "시스템 상태"),
    ("/today", "승인 대기"), ("/status@my_bot", "시스템 상태"), ("/nope", "모르는 명령"),
    ("안녕", "자유 대화는 지원하지 않아요"),
])
def test_commands(svc, text, expect):
    reply = CommandBot(svc).handle_update(msg(1, OWNER, text))
    assert expect in reply


def test_unauthorized_gets_no_reply_and_is_audited(svc):
    assert CommandBot(svc).handle_update(msg(1, 999, "/status")) is None
    assert svc.db.one("SELECT COUNT(*) n FROM outbox")["n"] == 0
    assert svc.db.one("SELECT actor FROM audit_log WHERE action='telegram.unauthorized'")["actor"] == "tg:999"


def test_dry_run_does_not_call_telegram(svc, fake_tg):
    CommandBot(svc).handle_update(msg(1, OWNER, "/help"))
    assert fake_tg.requests == []
    assert svc.db.one("SELECT sent FROM outbox")["sent"] == 0


def test_live_poll_once_processes_and_advances_offset(tmp_path):
    fake = FakeTelegram([msg(10, OWNER, "/status"), msg(11, 999, "/status")])
    s = build_services(make_settings(tmp_path, telegram_dry_run=False, telegram_bot_token=TOKEN),
                       http_transport=httpx.MockTransport(fake))
    assert poll_once(s) == 2
    sent = [b for m, b in fake.requests if m == "sendMessage"]
    assert len(sent) == 1 and sent[0]["chat_id"] == OWNER  # only the owner got a reply
    assert poll_once(s) == 0  # offset stored -> no reprocessing
    s.db.close()


def test_telegram_errors_do_not_leak_token(tmp_path):
    def broken(request):
        raise httpx.ConnectError("cannot reach " + str(request.url))
    s = build_services(make_settings(tmp_path, telegram_dry_run=False, telegram_bot_token=TOKEN),
                       http_transport=httpx.MockTransport(broken))
    with pytest.raises(TelegramError) as ei:
        s.telegram.get_me()
    assert TOKEN not in str(ei.value)
    s.db.close()


def test_poll_refuses_without_allowlist(tmp_path):
    s = build_services(make_settings(tmp_path, telegram_allowed_user_ids=[]))
    with pytest.raises(ConfigError):
        poll_once(s)
    s.db.close()


def test_api_auth_and_endpoints(tmp_path):
    from fastapi.testclient import TestClient
    s = build_services(make_settings(tmp_path, api_token="secret-token-123"))
    c = TestClient(create_app(s))
    assert c.get("/health").json()["ok"] is True
    assert c.get("/api/status").status_code == 401
    assert c.get("/api/status", headers={"Authorization": "Bearer wrong"}).status_code == 401
    h = {"Authorization": "Bearer secret-token-123"}
    assert c.get("/api/status", headers=h).json()["env"] == "test"
    s.tasks.submit("ping")
    assert c.get("/api/tasks", headers=h).json()[0]["name"] == "ping"
    assert c.post("/api/approvals/999/approve", headers=h).status_code == 409
    s.db.close()


def test_api_without_token_refuses_protected_routes(svc):
    from fastapi.testclient import TestClient
    c = TestClient(create_app(svc))
    assert c.get("/api/status").status_code == 503


def test_cli_selftest_runs(tmp_path, monkeypatch, capsys):
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv("DATA_DIR", str(tmp_path / "d"))
    monkeypatch.setenv("LOG_DIR", str(tmp_path / "l"))
    from app import __main__ as cli
    from app.config import get_settings
    get_settings.cache_clear()
    assert cli.main(["selftest"]) == 0
    assert "SELFTEST OK" in capsys.readouterr().out
    get_settings.cache_clear()
