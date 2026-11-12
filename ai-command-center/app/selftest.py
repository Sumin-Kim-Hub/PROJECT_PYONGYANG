"""Offline self-check (no network). Used after install, e.g. on the Windows laptop."""
from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo


def run_selftest(svc) -> int:
    results: list[tuple[str, bool, str]] = []

    def check(name, fn):
        try:
            detail = fn()
            results.append((name, True, detail or ""))
        except Exception as e:
            results.append((name, False, f"{type(e).__name__}: {e}"))

    s = svc.settings
    check("database", lambda: f"{s.db_path}" if svc.db.ok() else 1 / 0)
    check("timezone", lambda: datetime.now(ZoneInfo(s.timezone)).strftime("%Y-%m-%d %H:%M %Z"))
    check("task ping", lambda: svc.tasks.submit("ping", {"echo": "selftest"}, actor="selftest")["status"]
          == "succeeded" and "ok" or 1 / 0)
    check("ai guard", lambda: f"enabled={s.llm_enabled} limit={s.llm_daily_call_limit}/day")
    check("telegram config", lambda: (
        f"token={'set' if s.telegram_bot_token else 'MISSING'}, "
        f"allowed_users={len(s.telegram_allowed_user_ids)}, mode={'dry-run' if s.telegram_dry_run else 'live'}"))
    ok = all(r[1] for r in results)
    for name, passed, detail in results:
        print(f"[{'PASS' if passed else 'FAIL'}] {name}: {detail}")
    if not s.telegram_bot_token:
        print("[INFO] Telegram token not set: real sending/receiving is not possible yet.")
    print("SELFTEST", "OK" if ok else "FAILED")
    return 0 if ok else 1
