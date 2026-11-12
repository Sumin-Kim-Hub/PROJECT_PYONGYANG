"""Wires settings, database, tasks, AI router and Telegram client into one Services object."""
from __future__ import annotations

import time
from dataclasses import dataclass, field

from app import __version__
from app.config import Settings, get_settings
from app.db import Database
from app.llm import FakeProvider, LLMRouter
from app.logging_setup import setup_logging
from app.tasks import TaskManager, registry


@dataclass
class Services:
    settings: Settings
    db: Database
    tasks: TaskManager
    llm: LLMRouter
    telegram: "TelegramClient"  # noqa: F821
    started_at: float = field(default_factory=time.time)
    version: str = __version__

    def status(self) -> dict:
        last_fail = self.db.one("SELECT id, name, error, updated_at FROM tasks WHERE status='failed' "
                                "ORDER BY id DESC LIMIT 1")
        return {
            "version": self.version,
            "env": self.settings.app_env.value,
            "uptime_sec": int(time.time() - self.started_at),
            "db_ok": self.db.ok(),
            "tasks": self.tasks.counts(),
            "pending_approvals": len(self.tasks.pending_approvals()),
            "last_failure": dict(last_fail) if last_fail else None,
            "llm": self.llm.usage(),
            "telegram_mode": "dry-run" if self.settings.telegram_dry_run else "live",
        }


def build_services(settings: Settings | None = None, *, http_transport=None) -> Services:
    from app.telegram.client import TelegramClient

    settings = settings or get_settings()
    setup_logging(settings)
    db = Database(settings.db_path)
    db.init()
    # Step 5 will add real providers here. Until then only an offline fake is available,
    # and it is used only when LLM_ENABLED=true (default false).
    llm = LLMRouter(db, [FakeProvider()], enabled=settings.llm_enabled,
                    daily_call_limit=settings.llm_daily_call_limit,
                    monthly_budget_krw=settings.llm_monthly_budget_krw, cache=settings.llm_cache_enabled)
    tg = TelegramClient(settings, db, transport=http_transport)
    svc = Services(settings, db, None, llm, tg)  # type: ignore[arg-type]
    svc.tasks = TaskManager(db, registry, svc, settings.approval_ttl_hours)
    return svc
