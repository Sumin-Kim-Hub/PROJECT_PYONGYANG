import logging

import pytest

from app.config import Settings
from app.errors import ApprovalError, BudgetExceeded, ConfigError, PolicyViolation, TaskError
from app.llm import FakeProvider, LLMRouter, Sensitivity
from app.logging_setup import MASK, redact
from app.tasks import TaskManager, TaskRegistry
from tests.conftest import TOKEN, make_settings


# --- config ---------------------------------------------------------------
def test_settings_parse_ids_and_hide_secrets(tmp_path):
    s = make_settings(tmp_path, telegram_allowed_user_ids="1, 2,3", telegram_bot_token=TOKEN)
    assert s.telegram_allowed_user_ids == [1, 2, 3]
    assert TOKEN not in repr(s)
    assert s.db_path.name == "test.db"


def test_env_vars_are_read(monkeypatch, tmp_path):
    monkeypatch.setenv("TELEGRAM_ALLOWED_USER_IDS", "42")
    monkeypatch.setenv("LLM_DAILY_CALL_LIMIT", "7")
    s = Settings(_env_file=None, data_dir=tmp_path)
    assert s.telegram_allowed_user_ids == [42] and s.llm_daily_call_limit == 7


def test_fail_closed_validation(tmp_path):
    with pytest.raises(ConfigError):
        make_settings(tmp_path, telegram_allowed_user_ids=[]).validate_for("telegram")
    with pytest.raises(ConfigError):
        make_settings(tmp_path, telegram_dry_run=False).validate_for("telegram")  # no token
    with pytest.raises(ConfigError):
        make_settings(tmp_path, app_env="prod").validate_for("api")  # no API token
    with pytest.raises(ConfigError):
        make_settings(tmp_path, app_env="prod", api_token="x" * 20, api_host="0.0.0.0").validate_for("api")


# --- logging --------------------------------------------------------------
def test_redaction_masks_known_secret_shapes():
    text = f"url=https://api.telegram.org/bot{TOKEN}/x key=AIza{'a' * 35} Bearer abcdefghijkl custom=hunter2pass"
    out = redact(text, ["hunter2pass"])
    assert TOKEN not in out and "AIza" not in out and "abcdefghijkl" not in out and "hunter2pass" not in out
    assert out.count(MASK) == 4


def test_log_file_never_contains_token(tmp_path):
    from app.core import build_services
    s = build_services(make_settings(tmp_path, telegram_bot_token=TOKEN))
    logging.getLogger("acc.test").error("leak attempt %s", TOKEN)
    for h in logging.getLogger("acc").handlers:
        h.flush()
    content = (tmp_path / "logs" / "test.log").read_text(encoding="utf-8")
    assert "leak attempt" in content and TOKEN not in content
    s.db.close()


# --- database -------------------------------------------------------------
def test_db_init_is_idempotent(svc):
    svc.db.init()
    assert svc.db.ok()
    with pytest.raises(RuntimeError):
        with svc.db.tx():
            svc.db.audit("t", "inside")
            raise RuntimeError("boom")
    assert svc.db.one("SELECT COUNT(*) n FROM audit_log WHERE action='inside'")["n"] == 0  # rolled back


# --- tasks & approvals ----------------------------------------------------
def _manager(svc):
    reg = TaskRegistry()
    calls = []

    @reg.task("ok")
    def ok(payload, ctx):
        return {"n": payload["n"] * 2}

    @reg.task("flaky", max_attempts=3)
    def flaky(payload, ctx):
        calls.append(1)
        if len(calls) < 3:
            raise ValueError("temporary")
        return "done"

    @reg.task("boom")
    def boom(payload, ctx):
        raise RuntimeError(f"failed with {TOKEN}")

    @reg.task("post_blog", requires_approval=True)
    def post(payload, ctx):
        calls.append("posted")
        return "posted"

    return TaskManager(svc.db, reg, svc), calls


def test_task_success_retry_and_failure(svc):
    tm, calls = _manager(svc)
    assert tm.submit("ok", {"n": 21})["result"] == '{"n": 42}'
    flaky = tm.submit("flaky")
    assert flaky["status"] == "succeeded" and flaky["attempts"] == 3
    bad = tm.submit("boom")
    assert bad["status"] == "failed" and "RuntimeError" in bad["error"] and TOKEN not in bad["error"]
    with pytest.raises(TaskError):
        tm.submit("does-not-exist")


def test_approval_gate_blocks_until_approved(svc):
    tm, calls = _manager(svc)
    t = tm.submit("post_blog", summary="블로그 게시")
    assert t["status"] == "awaiting_approval" and "posted" not in calls
    appr = tm.pending_approvals()[0]
    assert tm.approve(appr["id"], actor="owner")["status"] == "succeeded" and "posted" in calls
    with pytest.raises(ApprovalError):
        tm.approve(appr["id"], actor="owner")  # cannot approve twice


def test_reject_and_expiry(svc):
    tm, calls = _manager(svc)
    tm.submit("post_blog")
    a1 = tm.pending_approvals()[0]["id"]
    assert tm.reject(a1, actor="owner")["status"] == "rejected"
    tm.submit("post_blog")
    a2 = tm.pending_approvals()[0]["id"]
    svc.db.execute("UPDATE approvals SET expires_at='2000-01-01T00:00:00+00:00' WHERE id=?", (a2,))
    with pytest.raises(ApprovalError):
        tm.approve(a2, actor="owner")
    assert "posted" not in calls
    actions = {r["action"] for r in svc.db.query("SELECT action FROM audit_log")}
    assert {"approval.request", "approval.rejected", "approval.expired"} <= actions


# --- AI router safety -----------------------------------------------------
def _router(svc, providers, **kw):
    opts = dict(enabled=True, daily_call_limit=3, monthly_budget_krw=100, cache=True)
    opts.update(kw)
    return LLMRouter(svc.db, providers, **opts)


def test_ai_disabled_by_default(svc):
    with pytest.raises(BudgetExceeded):
        svc.llm.ask("hi")


def test_secret_data_never_goes_to_cloud(svc):
    cloud_free = FakeProvider("gemini-free", is_local=False, trains_on_input=True)
    cloud_paid = FakeProvider("claude", is_local=False, trains_on_input=False)
    local = FakeProvider("ollama", is_local=True)
    r = _router(svc, [cloud_free, cloud_paid])
    with pytest.raises(PolicyViolation):
        r.ask("카드 내역", sensitivity=Sensitivity.secret)
    assert r.ask("메모", sensitivity=Sensitivity.personal).provider == "claude"
    assert r.ask("뉴스", sensitivity=Sensitivity.public).provider == "gemini-free"
    r2 = _router(svc, [cloud_free, local])
    assert r2.ask("카드 내역2", sensitivity=Sensitivity.secret).provider == "ollama"
    assert cloud_free.calls == 1  # only the public request


def test_daily_limit_budget_and_cache(svc):
    p = FakeProvider("paid", is_local=False, price_in=1000.0, price_out=1000.0)
    r = _router(svc, [p], daily_call_limit=2, monthly_budget_krw=1_000_000)
    r.ask("a"); r.ask("a")  # second is a cache hit, not counted
    assert p.calls == 1
    r.ask("b")
    with pytest.raises(BudgetExceeded):
        r.ask("c")
    poor = _router(svc, [FakeProvider("p2", price_in=1000.0, price_out=1000.0)], monthly_budget_krw=1)
    with pytest.raises(BudgetExceeded):
        poor.ask("expensive", max_tokens=800)
