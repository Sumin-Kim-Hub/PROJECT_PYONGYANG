"""Error types. Every expected failure is an AppError so callers can report it cleanly."""


class AppError(Exception):
    """Base class for expected, user-reportable errors."""


class ConfigError(AppError):
    """Missing or unsafe configuration."""


class TaskError(AppError):
    """Task lookup/state problems."""


class ApprovalError(AppError):
    """Approval missing, expired or already decided."""


class BudgetExceeded(AppError):
    """An AI call was blocked by a safety limit."""


class PolicyViolation(AppError):
    """Data would be sent somewhere it is not allowed to go."""


class TelegramError(AppError):
    """Telegram API call failed."""
