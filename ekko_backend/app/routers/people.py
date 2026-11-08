"""Partner cockpit (company side), lead capture, and DPDP rights (consent, export, erase)."""
import secrets
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import AuditLog, Consent, KycReport, Lead, Order, User
from ..schemas import ConsentIn, ProfileIn
from ..security import current_user, require_role
from ..services import audit, services, to_profile

router = APIRouter(prefix="/v1", tags=["partner & privacy"])
NOTICE_VERSION = "1.0"
COMMISSION_RATE, COMMISSION_MONTHS = 0.08, 12


# ---------------------------------------------------------------- leads
@router.post("/leads", status_code=201, summary="Hand a business the app couldn't close to partners")
def create_lead(profile: ProfileIn, request: Request, reason: str = Query("callback", max_length=32),
                stage: str = Query("plan", max_length=32), user: User = Depends(require_role("owner")),
                db: Session = Depends(get_db)):
    p = to_profile(profile)
    lead = Lead(id=f"APP-{secrets.randbelow(90000) + 10000}", user_id=user.id,
                profile=profile.model_dump(exclude={"gstin"}), score=services().propensity.score_profile(p),
                stage=stage, reason=reason)
    db.add(lead)
    audit(db, request, user.id, "lead_created", f"{lead.id}:{reason}")
    db.commit()
    return {"id": lead.id, "score": round(lead.score, 4)}


@router.get("/partner/leads", summary="Leads to call, ranked by the propensity model")
def partner_leads(segment: str | None = Query(None, pattern="^(micro|prof|multi|mfg)$"),
                  limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0),
                  user: User = Depends(require_role("partner")), db: Session = Depends(get_db)):
    s = services()
    app_leads = [{"id": l.id, "name": l.profile.get("businessType") or "New business", "type": l.profile.get("businessType"),
                  "segment": l.profile.get("segment"), "city": l.profile.get("city"), "employees": l.profile.get("employees"),
                  "source": "Ekko app", "stage": l.stage, "drop": l.reason, "score": round(l.score, 4),
                  "why": ["Started in Ekko app", f"Asked: {l.reason}"]} for l in db.query(Lead).all()]
    rows = sorted(app_leads + s.cockpit_leads, key=lambda r: -r["score"])
    if segment:
        rows = [r for r in rows if r.get("segment") == segment]
    page = rows[offset: offset + limit]
    for r in page:
        r.pop("contact", None)  # contact names stay off the wire until a partner opens the lead
    return {"total": len(rows), "modelAuc": s.propensity.auc, "leads": page}


@router.get("/partner/earnings", summary="Orders this partner helped close, and commission")
def partner_earnings(user: User = Depends(require_role("partner")), db: Session = Depends(get_db)):
    orders = db.query(Order).filter_by(partner_code=user.label).all()
    monthly = sum(o.monthly for o in orders)
    return {"partner": user.label, "assistedOrders": len(orders), "assistedMonthlyRevenue": monthly,
            "commission": round(monthly * COMMISSION_RATE * COMMISSION_MONTHS),
            "rule": f"{int(COMMISSION_RATE * 100)}% of the monthly bill for {COMMISSION_MONTHS} months",
            "orders": [{"id": o.id, "business": o.business_name, "monthly": o.monthly} for o in orders]}


# ---------------------------------------------------------------- DPDP rights
@router.post("/me/consents", status_code=201, summary="Grant or withdraw consent (logged with notice version)")
def set_consent(body: ConsentIn, request: Request, user: User = Depends(current_user), db: Session = Depends(get_db)):
    db.add(Consent(user_id=user.id, purpose=body.purpose, granted=body.granted, notice_version=NOTICE_VERSION))
    audit(db, request, user.id, "consent_granted" if body.granted else "consent_withdrawn", body.purpose)
    db.commit()
    return my_consents(user, db)


@router.get("/me/consents", summary="Current consent state per purpose")
def my_consents(user: User = Depends(current_user), db: Session = Depends(get_db)):
    latest: dict = {}
    for c in db.query(Consent).filter_by(user_id=user.id).order_by(Consent.id):
        latest[c.purpose] = {"granted": c.granted, "noticeVersion": c.notice_version, "at": c.created_at.isoformat()}
    return latest


@router.get("/me/export", summary="Download everything stored about me (right to access)")
def export(request: Request, user: User = Depends(current_user), db: Session = Depends(get_db)):
    audit(db, request, user.id, "data_exported")
    db.commit()
    q = lambda m: db.query(m).filter_by(user_id=user.id).all()  # noqa: E731
    return {
        "user": {"id": user.id, "role": user.role, "label": user.label, "createdAt": user.created_at.isoformat()},
        "consents": [{"purpose": c.purpose, "granted": c.granted, "at": c.created_at.isoformat()} for c in q(Consent)],
        "kycReports": [{"id": r.id, "verdict": r.verdict, "gstinMasked": r.gstin_masked, "checks": r.checks} for r in q(KycReport)],
        "orders": [{"id": o.id, "items": o.items, "monthly": o.monthly, "slot": o.slot} for o in q(Order)],
        "leads": [{"id": l.id, "stage": l.stage, "reason": l.reason} for l in q(Lead)],
        "exportedAt": datetime.now(timezone.utc).isoformat(),
    }


@router.delete("/me", summary="Erase my account and data (right to erasure)")
def erase(request: Request, user: User = Depends(current_user), db: Session = Depends(get_db)):
    uid = user.id
    for model in (Consent, KycReport, Lead):
        db.query(model).filter_by(user_id=uid).delete()
    db.delete(user)  # orders cascade
    audit(db, request, "erased-user", "account_erased")  # no personal identifier kept
    db.commit()
    return {"erased": True}


@router.get("/me/audit", summary="My security log")
def my_audit(user: User = Depends(current_user), db: Session = Depends(get_db)):
    rows = db.query(AuditLog).filter_by(actor=user.id).order_by(AuditLog.id.desc()).limit(100)
    return [{"action": r.action, "detail": r.detail, "at": r.created_at.isoformat()} for r in rows]
