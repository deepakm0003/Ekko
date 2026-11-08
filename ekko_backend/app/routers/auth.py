"""Phone + OTP login for owners, ID + PIN for partners. JWT access tokens."""
import re
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..models import OtpChallenge, User
from ..schemas import OtpRequest, OtpRequested, OtpVerify, PartnerLogin, Token
from ..security import hash_phone, hash_secret, issue_token, limiter, mask_phone, new_otp, same
from ..services import audit

router = APIRouter(prefix="/v1/auth", tags=["auth"])
_PIN_SALT = "ekko-partner-v1"
_PIN_HASH = hash_secret(settings.partner_pin, _PIN_SALT)


def _phone(raw: str) -> str:
    d = re.sub(r"\D", "", raw)
    if len(d) == 12 and d.startswith("91"):
        d = d[2:]
    if not re.fullmatch(r"[6-9]\d{9}", d):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "enter a valid 10-digit Indian mobile number")
    return d


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _aware(t: datetime | None) -> datetime | None:
    return t if t is None or t.tzinfo else t.replace(tzinfo=timezone.utc)


@router.post("/otp/request", response_model=OtpRequested, summary="Send a one-time password")
def request_otp(body: OtpRequest, request: Request, db: Session = Depends(get_db)):
    limiter.check(request)
    phone = _phone(body.phone)
    ph = hash_phone(phone)
    ch = db.get(OtpChallenge, ph)
    if ch and ch.locked_until and _aware(ch.locked_until) > _now():
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "too many attempts, try again later")
    otp = new_otp()
    if ch is None:
        ch = OtpChallenge(phone_hash=ph)
        db.add(ch)
    ch.otp_hash, ch.attempts, ch.locked_until = hash_secret(otp, ph), 0, None
    ch.expires_at = _now() + timedelta(seconds=settings.otp_ttl_seconds)
    audit(db, request, "anon", "otp_sent", mask_phone(phone))
    db.commit()
    # Production: hand `otp` to the SMS gateway (DLT template) here and never return it.
    return OtpRequested(expiresInSeconds=settings.otp_ttl_seconds, demoOtp=otp if settings.demo_otp else None)


@router.post("/otp/verify", response_model=Token, summary="Verify the OTP and get an access token")
def verify_otp(body: OtpVerify, request: Request, db: Session = Depends(get_db)):
    limiter.check(request)
    phone = _phone(body.phone)
    ph = hash_phone(phone)
    ch = db.get(OtpChallenge, ph)
    if ch is None or _aware(ch.expires_at) < _now():
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "OTP expired, request a new one")
    if ch.locked_until and _aware(ch.locked_until) > _now():
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "too many attempts, try again later")
    if not same(hash_secret(body.otp, ph), ch.otp_hash):
        ch.attempts += 1
        if ch.attempts >= settings.otp_max_attempts:
            ch.locked_until = _now() + timedelta(seconds=settings.lockout_seconds)
        audit(db, request, "anon", "otp_failed", mask_phone(phone))
        db.commit()
        left = max(settings.otp_max_attempts - ch.attempts, 0)
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, f"wrong OTP, {left} attempts left")
    db.delete(ch)
    user = db.query(User).filter_by(phone_hash=ph).one_or_none()
    if user is None:
        user = User(id=str(uuid.uuid4()), role="owner", phone_hash=ph, label=mask_phone(phone))
        db.add(user)
    audit(db, request, user.id, "login", "owner")
    db.commit()
    return Token(accessToken=issue_token(user), role=user.role, label=user.label)


@router.post("/partner", response_model=Token, summary="Partner / field-force login")
def partner_login(body: PartnerLogin, request: Request, db: Session = Depends(get_db)):
    limiter.check(request)
    pid = body.partnerId.strip().upper()
    if not (same(pid, settings.partner_id) and same(hash_secret(body.pin, _PIN_SALT), _PIN_HASH)):
        audit(db, request, "anon", "partner_login_failed")
        db.commit()
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "partner ID or PIN is wrong")
    uid = f"partner:{pid}"
    user = db.get(User, uid)
    if user is None:
        user = User(id=uid, role="partner", label=pid)
        db.add(user)
    audit(db, request, uid, "login", "partner")
    db.commit()
    return Token(accessToken=issue_token(user), role=user.role, label=user.label)
