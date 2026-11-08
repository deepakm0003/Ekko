"""Runtime settings, read once from the environment."""
import os
import secrets
from dataclasses import dataclass, field
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent


def _bool(name: str, default: bool) -> bool:
    return os.environ.get(name, str(default)).strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    env: str = os.environ.get("EKKO_ENV", "development")
    database_url: str = os.environ.get("EKKO_DATABASE_URL", f"sqlite:///{BASE_DIR / 'ekko.db'}")
    data_dir: Path = Path(os.environ.get("EKKO_DATA_DIR", BASE_DIR / "data"))
    # JWT signing secret. A random per-process secret is fine for local runs; set it in production.
    jwt_secret: str = os.environ.get("EKKO_JWT_SECRET", secrets.token_urlsafe(48))
    jwt_ttl_minutes: int = int(os.environ.get("EKKO_JWT_TTL_MINUTES", "720"))
    # Demo mode returns the OTP in the API response instead of sending an SMS.
    demo_otp: bool = _bool("EKKO_DEMO_OTP", True)
    otp_ttl_seconds: int = 300
    otp_max_attempts: int = 5
    lockout_seconds: int = 600
    rate_per_min: int = int(os.environ.get("EKKO_RATE_PER_MIN", "120"))
    # Demo partner (matches the app's demo seed). PIN stored only as a salted PBKDF2 hash.
    partner_id: str = os.environ.get("EKKO_PARTNER_ID", "PTR-1001")
    partner_pin: str = os.environ.get("EKKO_PARTNER_PIN", "482916")
    # Optional AI: without a key the advisor uses the on-server rule parser.
    anthropic_model: str = os.environ.get("EKKO_MODEL", "claude-opus-5-5")
    ai_enabled: bool = bool(os.environ.get("ANTHROPIC_API_KEY"))
    # Order tracker: seconds after ordering when it reaches scheduled, install, active (demo speed by default).
    stage_seconds: tuple = field(default_factory=lambda: tuple(
        int(x) for x in os.environ.get("EKKO_STAGE_SECONDS", "60,180,300").split(",")))
    cors_origins: tuple = tuple(o for o in os.environ.get("EKKO_CORS_ORIGINS", "").split(",") if o)


settings = Settings()
