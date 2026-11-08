"""Tokens, hashing, masking and request-level protections."""
from __future__ import annotations

import hashlib
import hmac
import re
import secrets
import time
from collections import defaultdict, deque
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .config import settings
from .db import get_db
from .models import User

_bearer = HTTPBearer(auto_error=False)
_PHONE_SALT = hashlib.sha256(("ekko-phone:" + settings.jwt_secret).encode()).hexdigest()[:16]


def hash_phone(phone: str) -> str:
    return hashlib.sha256(f"{_PHONE_SALT}:{phone}".encode()).hexdigest()


def hash_secret(value: str, salt: str) -> str:
    """PBKDF2-SHA256 for OTPs and PINs (never stored in clear)."""
    return hashlib.pbkdf2_hmac("sha256", value.encode(), salt.encode(), 120_000).hex()


def same(a: str, b: str) -> bool:
    return hmac.compare_digest(a, b)


def new_otp() -> str:
    return f"{secrets.randbelow(900000) + 100000}"


def mask_phone(phone: str) -> str:
    return f"+91 ••••••{phone[-4:]}"


_GSTIN = re.compile(r"\b\d{2}[A-Z]{5}\d{4}[A-Z][0-9A-Z]Z[0-9A-Z]\b")


def mask_text(text: str) -> str:
    """Strip identifiers and long numbers before anything is logged."""
    return re.sub(r"\d{6,}", "[NUM]", _GSTIN.sub("[GSTIN]", text.upper()))


def issue_token(user: User) -> str:
    now = datetime.now(timezone.utc)
    claims = {"sub": user.id, "role": user.role, "iat": now, "exp": now + timedelta(minutes=settings.jwt_ttl_minutes),
              "iss": "ekko"}
    return jwt.encode(claims, settings.jwt_secret, algorithm="HS256")


def current_user(creds: HTTPAuthorizationCredentials | None = Depends(_bearer), db: Session = Depends(get_db)) -> User:
    if creds is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "missing bearer token")
    try:
        claims = jwt.decode(creds.credentials, settings.jwt_secret, algorithms=["HS256"], issuer="ekko")
    except jwt.PyJWTError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid or expired token")
    user = db.get(User, claims["sub"])
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "account no longer exists")
    return user


def require_role(role: str):
    def dep(user: User = Depends(current_user)) -> User:
        if user.role != role:
            raise HTTPException(status.HTTP_403_FORBIDDEN, f"{role} role required")
        return user
    return dep


class RateLimiter:
    """Sliding-window limit per client IP (per process; use Redis when scaled out)."""

    def __init__(self, per_minute: int):
        self.per_minute = per_minute
        self.hits: dict[str, deque] = defaultdict(deque)

    def check(self, request: Request) -> None:
        key = request.client.host if request.client else "?"
        now, q = time.monotonic(), self.hits[key]
        while q and now - q[0] > 60:
            q.popleft()
        if len(q) >= self.per_minute:
            raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "rate limit exceeded", headers={"Retry-After": "60"})
        q.append(now)


limiter = RateLimiter(settings.rate_per_min)
