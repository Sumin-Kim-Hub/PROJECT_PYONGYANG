"""Settings from environment variables / .env files.

Load order (later wins): .env, .env.<APP_ENV>, real environment variables.
Secrets are SecretStr so they never show up in repr() or logs.
"""
from __future__ import annotations

import os
from enum import Enum
from functools import lru_cache
from pathlib import Path

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict
from typing import Annotated

from app.errors import ConfigError

PROJECT_ROOT = Path(__file__).resolve().parent.parent


class Env(str, Enum):
    dev = "dev"
    test = "test"
    prod = "prod"


def _env_files() -> tuple[Path, ...]:
    env = os.environ.get("APP_ENV", "dev")
    return (PROJECT_ROOT / ".env", PROJECT_ROOT / f".env.{env}")


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file_encoding="utf-8", extra="ignore")

    app_env: Env = Env.dev
    timezone: str = "Asia/Seoul"
    data_dir: Path = PROJECT_ROOT / "data"
    log_dir: Path = PROJECT_ROOT / "logs"
    log_level: str = "INFO"

    telegram_bot_token: SecretStr | None = None
    telegram_allowed_user_ids: Annotated[list[int], NoDecode] = Field(default_factory=list)
    telegram_dry_run: bool = True
    telegram_api_base: str = "https://api.telegram.org"

    api_token: SecretStr | None = None
    api_host: str = "127.0.0.1"
    api_port: int = 8000

    llm_enabled: bool = False
    llm_daily_call_limit: int = 50
    llm_monthly_budget_krw: int = 0
    llm_cache_enabled: bool = True

    approval_ttl_hours: int = 24

    @field_validator("telegram_allowed_user_ids", mode="before")
    @classmethod
    def _parse_ids(cls, v):
        if v is None or v == "":
            return []
        if isinstance(v, str):
            return [int(x) for x in v.replace(" ", "").split(",") if x]
        if isinstance(v, int):
            return [v]
        return v

    @field_validator("telegram_bot_token", "api_token", mode="before")
    @classmethod
    def _blank_is_none(cls, v):
        return None if v in ("", None) else v

    @property
    def db_path(self) -> Path:
        # Separate database per environment so tests/dev never touch real data.
        return self.data_dir / f"{self.app_env.value}.db"

    @property
    def is_prod(self) -> bool:
        return self.app_env is Env.prod

    def secret_values(self) -> list[str]:
        return [s.get_secret_value() for s in (self.telegram_bot_token, self.api_token) if s]

    def validate_for(self, component: str) -> None:
        """Fail closed: refuse to start a component with unsafe/missing settings."""
        problems: list[str] = []
        if component == "telegram":
            if not self.telegram_allowed_user_ids:
                problems.append("TELEGRAM_ALLOWED_USER_IDS is empty (nobody could be authorized)")
            if not self.telegram_dry_run and not self.telegram_bot_token:
                problems.append("TELEGRAM_BOT_TOKEN is missing")
        if component == "api" and self.is_prod and not self.api_token:
            problems.append("API_TOKEN is required in prod")
        if component == "api" and self.is_prod and self.api_host not in ("127.0.0.1", "localhost") \
                and not self.api_host.startswith("100."):
            problems.append("API_HOST must be localhost or a Tailscale (100.x) address in prod")
        if problems:
            raise ConfigError(f"[{component}] " + "; ".join(problems))


def load_settings(**overrides) -> Settings:
    return Settings(_env_file=_env_files(), **overrides)


@lru_cache
def get_settings() -> Settings:
    return load_settings()
