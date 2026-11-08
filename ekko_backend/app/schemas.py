"""Validated API contracts. Strict bounds keep bad or hostile input out of the engines."""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from .domain.engine import NEEDS

Need = Literal[NEEDS]  # type: ignore[valid-type]


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


# ---- auth
class OtpRequest(Strict):
    phone: str = Field(min_length=10, max_length=16, examples=["9811122233"])


class OtpRequested(BaseModel):
    expiresInSeconds: int
    demoOtp: str | None = Field(None, description="Only in demo mode; production sends an SMS.")


class OtpVerify(Strict):
    phone: str = Field(min_length=10, max_length=16)
    otp: str = Field(pattern=r"^\d{6}$")


class PartnerLogin(Strict):
    partnerId: str = Field(max_length=16)
    pin: str = Field(pattern=r"^\d{4,8}$")


class Token(BaseModel):
    accessToken: str
    tokenType: str = "bearer"
    role: str
    label: str


# ---- profile & plans
class ProfileIn(Strict):
    businessType: str = Field("", max_length=60)
    segment: Literal["micro", "prof", "multi", "mfg"] = "micro"
    employees: int = Field(1, ge=1, le=5000)
    sites: int = Field(1, ge=1, le=500)
    cityTier: Literal[1, 2] = 1
    city: str = Field("", max_length=40)
    gstStatus: Literal["none", "active", "cancelled", "suspended"] = "none"
    gstin: str | None = Field(None, max_length=20)
    hasUdyam: bool = False
    currentInternet: str = Field("", max_length=40)
    currentMonthlySpend: int = Field(0, ge=0, le=10_000_000)
    needs: list[Need] = Field(default_factory=list, max_length=len(NEEDS))
    fibreFeasible: bool = True
    mobileOnly: bool = False
    budget: int | None = Field(None, ge=0, le=10_000_000)
    vehicles: int = Field(3, ge=1, le=500)
    machines: int = Field(8, ge=1, le=500)


class ItemIn(Strict):
    productId: str = Field(pattern=r"^P\d{2}$")
    qty: int = Field(ge=1, le=500)


class QuoteRequest(Strict):
    profile: ProfileIn
    items: list[ItemIn] = Field(min_length=1, max_length=25)
    contractMonths: int | None = Field(None, ge=1, le=36)

    @field_validator("items")
    @classmethod
    def unique(cls, v):
        if len({i.productId for i in v}) != len(v):
            raise ValueError("duplicate productId")
        return v


# ---- advisor
AdvisorStep = Literal["type", "employees", "sites", "city", "internet", "spend", "needs", "gstin", "pincode", "budget"]


class UnderstandIn(Strict):
    step: AdvisorStep
    text: str = Field(min_length=1, max_length=400)
    language: str = Field("en", max_length=5)


class UnderstandOut(BaseModel):
    fields: dict
    source: Literal["rules", "ai", "none"]


# ---- KYC
DocType = Literal["gstCertificate", "udyamCertificate", "signatoryId", "addressProof"]


class DocIn(Strict):
    fields: dict[str, str] = Field(max_length=20)
    readability: float = Field(1.0, ge=0, le=1)
    rotation: float = Field(0.0, ge=-90, le=90)

    @field_validator("fields")
    @classmethod
    def short_values(cls, v):
        if any(len(x) > 200 or len(k) > 40 for k, x in v.items()):
            raise ValueError("field too long")
        return v


class KycIn(Strict):
    documents: dict[DocType, DocIn]
    gstRequired: bool = True


class CheckOut(BaseModel):
    id: str
    severity: str
    message: str
    fix: str | None = None


class KycOut(BaseModel):
    reportId: str
    verdict: Literal["approved", "actionNeeded", "rejected"]
    businessName: str | None
    gstinMasked: str | None
    checks: list[CheckOut]


# ---- orders
class OrderIn(Strict):
    profile: ProfileIn
    items: list[ItemIn] = Field(min_length=1, max_length=25)
    contractMonths: int | None = Field(None, ge=1, le=36)
    kycReportId: str = Field(max_length=36)
    signedName: str = Field(min_length=3, max_length=80)
    acceptTerms: Literal[True]
    partnerCode: str | None = Field(None, pattern=r"^PTR-\d{4}$")
    expectedMonthly: int | None = Field(None, ge=0, description="Price the app showed; rejected if it differs.")


class SlotIn(Strict):
    slot: str = Field(min_length=5, max_length=64)


class ConsentIn(Strict):
    purpose: Literal["kyc_verification", "marketing"]
    granted: bool
