"""Catalogue, registry lookups, advisor understanding, recommendations and quotes."""
from dataclasses import asdict

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field

from .. import ai
from ..domain.engine import LineItem
from ..domain.identity import gstin_mask, gstin_normalise, gstin_valid, udyam_mask, udyam_normalise, udyam_valid
from ..domain.parser import understand as rule_understand
from ..models import User
from ..schemas import ProfileIn, QuoteRequest, UnderstandIn, UnderstandOut
from ..security import current_user, limiter, mask_text
from ..services import services, to_profile

router = APIRouter(prefix="/v1", tags=["plans"])


@router.get("/catalogue", summary="All 25 products with prices and eligibility rules")
def catalogue():
    return [asdict(p) | {"listPrice": p.list_price, "longTermPrice": p.long_term_price} for p in services().catalogue.all]


@router.get("/registry/gstin/{gstin}", summary="Mock GSTN lookup (validates the check digit first)")
def gstin_lookup(gstin: str, request: Request, user: User = Depends(current_user)):
    limiter.check(request)
    g = gstin_normalise(gstin)
    if not gstin_valid(g):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "invalid GSTIN format or check digit")
    rec = services().registry.gstin(g)
    if rec is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "GSTIN not found in the GST registry")
    udyam = services().registry.udyam_by_name(rec.tradeName)
    return {"gstinMasked": gstin_mask(g), "tradeName": rec.tradeName, "constitution": rec.constitution,
            "state": rec.state, "status": rec.status, "registrationDate": rec.registrationDate,
            "hasUdyam": bool(udyam)}


@router.get("/registry/udyam/{number}", summary="Mock Udyam lookup")
def udyam_lookup(number: str, request: Request, user: User = Depends(current_user)):
    limiter.check(request)
    n = udyam_normalise(number)
    if not udyam_valid(n):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "invalid Udyam number format")
    rec = services().registry.udyam(n)
    if rec is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Udyam number not found")
    return {"numberMasked": udyam_mask(n), "enterpriseName": rec.enterpriseName, "enterpriseType": rec.enterpriseType,
            "majorActivity": rec.majorActivity, "state": rec.state, "city": rec.city}


@router.post("/advisor/understand", response_model=UnderstandOut,
             summary="Understand a free-text advisor answer (rules first, AI only as fallback)")
def understand(body: UnderstandIn, request: Request):
    limiter.check(request)
    fields = rule_understand(body.step, body.text)
    if fields:
        return UnderstandOut(fields=fields, source="rules")
    ai_fields = ai.understand(body.step, body.text, body.language)
    if ai_fields:
        return UnderstandOut(fields=ai_fields, source="ai")
    request.app.state.log.info("understand miss step=%s text=%s", body.step, mask_text(body.text)[:60])
    return UnderstandOut(fields={}, source="none")


class ExplainIn(BaseModel):
    language: str = Field("en", max_length=5)
    profile: dict = Field(default_factory=dict)
    items: list[dict] = Field(default_factory=list, max_length=40)
    monthly: int = Field(0, ge=0)
    notices: list[str] = Field(default_factory=list, max_length=30)


class AskIn(BaseModel):
    language: str = Field("en", max_length=5)
    question: str = Field(min_length=1, max_length=400)
    context: dict = Field(default_factory=dict)


@router.post("/advisor/explain", summary="Explain an already-validated plan (AI if configured)")
def explain(body: ExplainIn, request: Request):
    limiter.check(request)
    return {"text": ai.explain(body.language, {"items": body.items, "monthly": body.monthly, "notes": body.notices})}


_FAQ_ALIASES = {"static ip": "P11", "fixed ip": "P11", "sd-wan": "P10", "sdwan": "P10", "leased": "P05",
                "airfiber": "P04", "5g": "P04", "failover": "P09", "toll": "P13", "1800": "P13", "sms": "P14",
                "whatsapp": "P15", "email": "P16", "backup": "P17", "website": "P18", "pos": "P19", "billing": "P19",
                "antivirus": "P20", "firewall": "P21", "wi-fi": "P22", "wifi": "P22", "cctv": "P23", "camera": "P23",
                "iot": "P24", "fleet": "P25", "gps": "P25", "ivr": "P12", "telephony": "P12", "fibre": "P01"}


@router.post("/advisor/ask", summary="Product Q&A: catalogue answer offline, AI if configured")
def ask(body: AskIn, request: Request):
    limiter.check(request)
    q = body.question.lower()
    pid = next((p for k, p in _FAQ_ALIASES.items() if k in q), None)
    if pid:
        p = services().catalogue[pid]
        return {"text": f"{p.name}: {p.description}. Exact prices are on your plan screen.", "source": "catalogue"}
    return {"text": None, "source": "none"}


def _bundle_response(bundle, quote, profile) -> dict:
    s = services()
    return {"bundle": bundle.to_dict(), "quote": quote.to_dict(),
            "leadScore": round(s.propensity.score_profile(profile), 4)}


@router.post("/plans/recommend", summary="Recommend an always-eligible bundle for a business profile")
def recommend(body: ProfileIn, request: Request, language: str = "en"):
    limiter.check(request)
    s, p = services(), to_profile(body)
    bundle = s.recommender.recommend(p)
    out = _bundle_response(bundle, s.pricing.quote(bundle.active), p)
    plan = {"business": body.businessType, "items": [l["name"] for l in out["quote"]["lines"]],
            "monthly": out["quote"]["monthly"]}
    # Optional: AI explains the already-validated plan; it cannot change items or prices.
    out["explanation"] = ai.explain(language[:5], plan)
    return out


@router.post("/plans/quote", summary="Validate a bundle against every rule and price it on the server")
def quote(body: QuoteRequest, request: Request):
    limiter.check(request)
    s, p = services(), to_profile(body.profile)
    unknown = [i.productId for i in body.items if i.productId not in s.catalogue]
    if unknown:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, f"unknown products: {unknown}")
    items = [LineItem(i.productId, i.qty) for i in body.items]
    violations = s.rules.validate([i.productId for i in items], p)
    q = s.pricing.quote(items, body.contractMonths)
    return {"valid": not violations, "violations": [asdict(v) for v in violations], "quote": q.to_dict()}
