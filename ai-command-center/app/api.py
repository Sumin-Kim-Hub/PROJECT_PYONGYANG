"""FastAPI app (base for the mobile dashboard in ROADMAP step 4).

/health is public. Everything else needs 'Authorization: Bearer <API_TOKEN>'.
If API_TOKEN is not set (dev only), protected routes are refused rather than left open.
"""
from __future__ import annotations

import hmac

from fastapi import Depends, FastAPI, Header, HTTPException

from app import __version__
from app.errors import AppError


def create_app(services=None) -> FastAPI:
    if services is None:
        from app.core import build_services
        services = build_services()
    services.settings.validate_for("api")
    app = FastAPI(title="AI Command Center", version=__version__, docs_url=None, redoc_url=None)
    app.state.services = services

    def auth(authorization: str = Header(default="")):
        token = services.settings.api_token
        if token is None:
            raise HTTPException(503, "API_TOKEN not configured")
        expected = f"Bearer {token.get_secret_value()}"
        if not hmac.compare_digest(authorization.encode(), expected.encode()):
            raise HTTPException(401, "unauthorized")

    @app.get("/health")
    def health():
        return {"ok": services.db.ok(), "version": __version__}

    @app.get("/api/status", dependencies=[Depends(auth)])
    def status():
        return services.status()

    @app.get("/api/tasks", dependencies=[Depends(auth)])
    def tasks(limit: int = 20):
        return services.tasks.recent(min(max(limit, 1), 100))

    @app.get("/api/approvals", dependencies=[Depends(auth)])
    def approvals():
        return services.tasks.pending_approvals()

    @app.post("/api/approvals/{approval_id}/{decision}", dependencies=[Depends(auth)])
    def decide(approval_id: int, decision: str):
        try:
            if decision == "approve":
                return services.tasks.approve(approval_id, actor="api")
            if decision == "reject":
                return services.tasks.reject(approval_id, actor="api")
        except AppError as e:
            raise HTTPException(409, str(e))
        raise HTTPException(400, "decision must be approve or reject")

    return app
