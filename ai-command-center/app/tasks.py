"""Task manager with an approval gate.

- Register handlers with @registry.task("name", requires_approval=...).
- Tasks that act on the outside world MUST use requires_approval=True: they are parked
  as 'awaiting_approval' and only run after approve(). Approvals expire (default 24h).
- Every state change is recorded in the audit log; handler errors never crash the caller.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Callable

from app.db import Database, utcnow
from app.errors import ApprovalError, TaskError
from app.logging_setup import get_logger, redact

log = get_logger("tasks")
Handler = Callable[[dict, "TaskContext"], Any]


@dataclass
class TaskSpec:
    name: str
    func: Handler
    requires_approval: bool = False
    max_attempts: int = 1
    description: str = ""


@dataclass
class TaskContext:
    task_id: int
    services: Any  # app.core.Services (avoid import cycle)


class TaskRegistry:
    def __init__(self):
        self._specs: dict[str, TaskSpec] = {}

    def task(self, name: str, *, requires_approval: bool = False, max_attempts: int = 1, description: str = ""):
        def deco(func: Handler) -> Handler:
            if name in self._specs:
                raise TaskError(f"task already registered: {name}")
            self._specs[name] = TaskSpec(name, func, requires_approval, max(1, max_attempts), description)
            return func
        return deco

    def get(self, name: str) -> TaskSpec:
        try:
            return self._specs[name]
        except KeyError:
            raise TaskError(f"unknown task: {name}") from None

    def names(self) -> list[str]:
        return sorted(self._specs)


class TaskManager:
    def __init__(self, db: Database, registry: TaskRegistry, services: Any = None, approval_ttl_hours: int = 24):
        self.db, self.registry, self.services = db, registry, services
        self.ttl = timedelta(hours=approval_ttl_hours)

    # --- submit / run ---------------------------------------------------
    def submit(self, name: str, payload: dict | None = None, *, actor: str = "system",
               summary: str | None = None) -> dict:
        spec = self.registry.get(name)
        payload = payload or {}
        now = utcnow()
        with self.db.tx():
            status = "awaiting_approval" if spec.requires_approval else "pending"
            task_id = self.db.execute(
                "INSERT INTO tasks(name, payload, status, created_at, updated_at) VALUES (?,?,?,?,?)",
                (name, json.dumps(payload, ensure_ascii=False), status, now, now))
            self.db.audit(actor, "task.submit", task_id=task_id, name=name)
            if spec.requires_approval:
                expires = (datetime.now(timezone.utc) + self.ttl).isoformat(timespec="seconds")
                aid = self.db.execute(
                    "INSERT INTO approvals(task_id, summary, status, created_at, expires_at) VALUES (?,?,?,?,?)",
                    (task_id, summary or f"{name} 실행", "pending", now, expires))
                self.db.audit(actor, "approval.request", approval_id=aid, task_id=task_id)
        if spec.requires_approval:
            log.info("task %s #%s waiting for approval", name, task_id)
            return self.get(task_id)
        return self._run(task_id)

    def _run(self, task_id: int) -> dict:
        row = self.get(task_id)
        spec = self.registry.get(row["name"])
        payload = json.loads(row["payload"])
        self._set(task_id, status="running")
        last_error = ""
        for attempt in range(1, spec.max_attempts + 1):
            self.db.execute("UPDATE tasks SET attempts=? WHERE id=?", (attempt, task_id))
            try:
                result = spec.func(payload, TaskContext(task_id, self.services))
                self._set(task_id, status="succeeded",
                          result=json.dumps(result, ensure_ascii=False, default=str), error=None)
                self.db.audit("system", "task.succeeded", task_id=task_id, attempt=attempt)
                log.info("task %s #%s succeeded (attempt %s)", spec.name, task_id, attempt)
                return self.get(task_id)
            except Exception as e:  # handler errors are recorded, never propagated
                last_error = redact(f"{type(e).__name__}: {e}")
                log.warning("task %s #%s attempt %s failed: %s", spec.name, task_id, attempt, last_error)
        self._set(task_id, status="failed", error=last_error)
        self.db.audit("system", "task.failed", task_id=task_id, error=last_error)
        return self.get(task_id)

    # --- approvals ------------------------------------------------------
    def approve(self, approval_id: int, *, actor: str) -> dict:
        appr = self._pending_approval(approval_id)
        with self.db.tx():
            self.db.execute("UPDATE approvals SET status='approved', decided_by=?, decided_at=? WHERE id=?",
                            (actor, utcnow(), approval_id))
            self._set(appr["task_id"], status="pending")
            self.db.audit(actor, "approval.approved", approval_id=approval_id)
        return self._run(appr["task_id"])

    def reject(self, approval_id: int, *, actor: str) -> dict:
        appr = self._pending_approval(approval_id)
        with self.db.tx():
            self.db.execute("UPDATE approvals SET status='rejected', decided_by=?, decided_at=? WHERE id=?",
                            (actor, utcnow(), approval_id))
            self._set(appr["task_id"], status="rejected")
            self.db.audit(actor, "approval.rejected", approval_id=approval_id)
        return self.get(appr["task_id"])

    def expire_stale(self) -> int:
        now = utcnow()
        rows = self.db.query("SELECT id, task_id FROM approvals WHERE status='pending' AND expires_at <= ?", (now,))
        for r in rows:
            with self.db.tx():
                self.db.execute("UPDATE approvals SET status='expired', decided_at=? WHERE id=?", (now, r["id"]))
                self._set(r["task_id"], status="expired")
                self.db.audit("system", "approval.expired", approval_id=r["id"])
        return len(rows)

    def _pending_approval(self, approval_id: int):
        self.expire_stale()
        appr = self.db.one("SELECT * FROM approvals WHERE id=?", (approval_id,))
        if appr is None:
            raise ApprovalError(f"approval #{approval_id} not found")
        if appr["status"] != "pending":
            raise ApprovalError(f"approval #{approval_id} is already {appr['status']}")
        return appr

    # --- queries --------------------------------------------------------
    def _set(self, task_id: int, **fields) -> None:
        fields["updated_at"] = utcnow()
        cols = ", ".join(f"{k}=?" for k in fields)
        self.db.execute(f"UPDATE tasks SET {cols} WHERE id=?", (*fields.values(), task_id))

    def get(self, task_id: int) -> dict:
        row = self.db.one("SELECT * FROM tasks WHERE id=?", (task_id,))
        if row is None:
            raise TaskError(f"task #{task_id} not found")
        return dict(row)

    def recent(self, limit: int = 10) -> list[dict]:
        return [dict(r) for r in self.db.query("SELECT * FROM tasks ORDER BY id DESC LIMIT ?", (limit,))]

    def pending_approvals(self) -> list[dict]:
        self.expire_stale()
        return [dict(r) for r in self.db.query(
            "SELECT a.*, t.name AS task_name FROM approvals a JOIN tasks t ON t.id=a.task_id "
            "WHERE a.status='pending' ORDER BY a.id")]

    def counts(self) -> dict[str, int]:
        return {r["status"]: r["n"] for r in self.db.query("SELECT status, COUNT(*) n FROM tasks GROUP BY status")}


registry = TaskRegistry()


@registry.task("ping", description="연결 확인용. 'pong' 반환")
def _ping(payload: dict, ctx: TaskContext):
    return {"reply": "pong", "echo": payload.get("echo")}
