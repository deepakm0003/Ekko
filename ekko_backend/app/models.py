"""Database tables. Identifiers are stored masked; phone numbers only as salted hashes."""
from datetime import datetime, timezone

from sqlalchemy import JSON, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    role: Mapped[str] = mapped_column(String(16))  # owner | partner
    phone_hash: Mapped[str | None] = mapped_column(String(64), unique=True)
    label: Mapped[str] = mapped_column(String(64))  # masked phone or partner ID
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    orders: Mapped[list["Order"]] = relationship(back_populates="user", cascade="all, delete-orphan")


class OtpChallenge(Base):
    __tablename__ = "otp_challenges"
    phone_hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    otp_hash: Mapped[str] = mapped_column(String(64))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    locked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Consent(Base):
    __tablename__ = "consents"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    purpose: Mapped[str] = mapped_column(String(32))
    granted: Mapped[bool]
    notice_version: Mapped[str] = mapped_column(String(8))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class KycReport(Base):
    __tablename__ = "kyc_reports"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    verdict: Mapped[str] = mapped_column(String(16))
    gstin_masked: Mapped[str | None] = mapped_column(String(20))
    business_name: Mapped[str | None] = mapped_column(String(128))
    checks: Mapped[list] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Order(Base):
    __tablename__ = "orders"
    id: Mapped[str] = mapped_column(String(12), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    kyc_report_id: Mapped[str | None] = mapped_column(ForeignKey("kyc_reports.id"))
    profile: Mapped[dict] = mapped_column(JSON)
    items: Mapped[list] = mapped_column(JSON)
    monthly: Mapped[int]
    setup: Mapped[int]
    contract_months: Mapped[int]
    install_days: Mapped[int]
    business_name: Mapped[str | None] = mapped_column(String(128))
    gstin_masked: Mapped[str | None] = mapped_column(String(20))
    partner_code: Mapped[str | None] = mapped_column(String(16), index=True)
    slot: Mapped[str | None] = mapped_column(String(64))
    signed_name: Mapped[str] = mapped_column(String(80))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    user: Mapped[User] = relationship(back_populates="orders")


class Lead(Base):
    __tablename__ = "leads"
    id: Mapped[str] = mapped_column(String(16), primary_key=True)
    user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    profile: Mapped[dict] = mapped_column(JSON)
    score: Mapped[float] = mapped_column(Float)
    stage: Mapped[str] = mapped_column(String(32))
    reason: Mapped[str] = mapped_column(String(32))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class AuditLog(Base):
    """Append-only security trail. Details are masked by the caller."""
    __tablename__ = "audit_log"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    actor: Mapped[str] = mapped_column(String(48), index=True)
    action: Mapped[str] = mapped_column(String(40))
    detail: Mapped[str | None] = mapped_column(Text)
    request_id: Mapped[str | None] = mapped_column(String(32))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
