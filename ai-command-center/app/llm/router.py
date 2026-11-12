"""AI model router with safety limits.

All AI calls must go through LLMRouter.ask(). It enforces:
  1. kill switch (LLM_ENABLED)
  2. data sensitivity routing: SECRET data may only go to local providers
  3. daily call limit + monthly budget (KRW), checked BEFORE calling
  4. response cache (no duplicate paid calls)
  5. usage logging for /status and cost reports

Real providers (Gemini, Claude, Ollama) are added in ROADMAP step 5.
Only FakeProvider exists now (for tests / dry runs).
"""
from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum
from typing import Protocol

from app.db import Database, utcnow
from app.errors import BudgetExceeded, PolicyViolation
from app.logging_setup import get_logger

log = get_logger("llm")


class Sensitivity(str, Enum):
    public = "public"      # news, trends: any provider
    personal = "personal"  # my notes: local or trusted paid API (no free tier that trains on data)
    secret = "secret"      # finance/health: local only


@dataclass
class LLMResponse:
    text: str
    provider: str
    model: str
    input_tokens: int
    output_tokens: int
    cost_krw: float
    cached: bool = False


class Provider(Protocol):
    name: str
    model: str
    is_local: bool
    trains_on_input: bool          # e.g. some free tiers may use inputs to improve products
    price_in_krw_per_1k: float
    price_out_krw_per_1k: float

    def complete(self, prompt: str, max_tokens: int) -> tuple[str, int, int]: ...


class FakeProvider:
    """Deterministic provider for tests. Never touches the network."""

    def __init__(self, name="fake", model="fake-1", is_local=True, trains_on_input=False,
                 price_in=0.0, price_out=0.0):
        self.name, self.model, self.is_local, self.trains_on_input = name, model, is_local, trains_on_input
        self.price_in_krw_per_1k, self.price_out_krw_per_1k = price_in, price_out
        self.calls = 0

    def complete(self, prompt: str, max_tokens: int) -> tuple[str, int, int]:
        self.calls += 1
        return f"[{self.name}] {prompt[:40]}", max(1, len(prompt) // 4), 10


def _allowed(p: Provider, s: Sensitivity) -> bool:
    if s is Sensitivity.secret:
        return p.is_local
    if s is Sensitivity.personal:
        return p.is_local or not p.trains_on_input
    return True


class LLMRouter:
    def __init__(self, db: Database, providers: list[Provider], *, enabled: bool,
                 daily_call_limit: int, monthly_budget_krw: float, cache: bool = True):
        self.db, self.providers = db, providers  # order = preference (cheapest first)
        self.enabled, self.daily_call_limit = enabled, daily_call_limit
        self.monthly_budget_krw, self.cache = monthly_budget_krw, cache

    def usage(self) -> dict:
        now = datetime.now(timezone.utc)
        day, month = now.strftime("%Y-%m-%d"), now.strftime("%Y-%m")
        d = self.db.one("SELECT COUNT(*) n FROM llm_usage WHERE cached=0 AND substr(at,1,10)=?", (day,))
        m = self.db.one("SELECT COALESCE(SUM(cost_krw),0) c FROM llm_usage WHERE substr(at,1,7)=?", (month,))
        return {"calls_today": d["n"], "daily_call_limit": self.daily_call_limit,
                "cost_month_krw": round(m["c"], 2), "monthly_budget_krw": self.monthly_budget_krw,
                "enabled": self.enabled}

    def ask(self, prompt: str, *, sensitivity: Sensitivity = Sensitivity.public,
            max_tokens: int = 800) -> LLMResponse:
        if not self.enabled:
            raise BudgetExceeded("AI is disabled (LLM_ENABLED=false)")
        candidates = [p for p in self.providers if _allowed(p, sensitivity)]
        if not candidates:
            raise PolicyViolation(f"no provider allowed for {sensitivity.value} data")
        p = candidates[0]
        key = hashlib.sha256(f"{p.name}|{p.model}|{max_tokens}|{prompt}".encode()).hexdigest()
        if self.cache:
            hit = self.db.one("SELECT response FROM llm_cache WHERE key=?", (key,))
            if hit:
                self._record(p, sensitivity, 0, 0, 0.0, cached=True)
                return LLMResponse(hit["response"], p.name, p.model, 0, 0, 0.0, cached=True)
        u = self.usage()
        if u["calls_today"] >= self.daily_call_limit:
            raise BudgetExceeded(f"daily AI call limit reached ({self.daily_call_limit})")
        est = self._cost(p, len(prompt) // 4 + 1, max_tokens)
        if est > 0 and u["cost_month_krw"] + est > self.monthly_budget_krw:
            raise BudgetExceeded(f"monthly AI budget would be exceeded ({self.monthly_budget_krw} KRW)")
        text, tin, tout = p.complete(prompt, max_tokens)
        cost = self._cost(p, tin, tout)
        self._record(p, sensitivity, tin, tout, cost)
        if self.cache:
            self.db.execute("INSERT OR REPLACE INTO llm_cache(key, response, created_at) VALUES (?,?,?)",
                            (key, text, utcnow()))
        log.info("llm call provider=%s model=%s tokens=%s/%s cost=%.2fKRW", p.name, p.model, tin, tout, cost)
        return LLMResponse(text, p.name, p.model, tin, tout, cost)

    @staticmethod
    def _cost(p: Provider, tin: int, tout: int) -> float:
        return tin / 1000 * p.price_in_krw_per_1k + tout / 1000 * p.price_out_krw_per_1k

    def _record(self, p: Provider, s: Sensitivity, tin: int, tout: int, cost: float, cached=False):
        self.db.execute(
            "INSERT INTO llm_usage(at, provider, model, sensitivity, input_tokens, output_tokens, cost_krw, cached)"
            " VALUES (?,?,?,?,?,?,?,?)", (utcnow(), p.name, p.model, s.value, tin, tout, cost, int(cached)))
