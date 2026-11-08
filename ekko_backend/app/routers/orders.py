"""Smart KYC verification, orders (re-validated and re-priced on the server) and live tracking."""
import secrets
import uuid
from dataclasses import asdict
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..domain.engine import GstStatus, LineItem
from ..domain.identity import Doc, gstin_mask, gstin_normalise, verdict_of
from ..models import KycReport, Order, User
from ..schemas import KycIn, KycOut, OrderIn, SlotIn
from ..security import current_user, limiter, require_role
from ..services import audit, services, to_profile

router = APIRouter(prefix="/v1", tags=["kyc & orders"])
STAGES = ["placed", "kyc", "scheduled", "install", "active"]
_GST_STATUS = {"Active": GstStatus.active, "Cancelled": GstStatus.cancelled, "Suspended": GstStatus.suspended}


@router.post("/kyc/verify", response_model=KycOut, summary="Re-check OCR-extracted document fields on the server")
def verify_kyc(body: KycIn, request: Request, user: User = Depends(require_role("owner")), db: Session = Depends(get_db)):
    limiter.check(request)
    docs = {t: Doc(d.fields, d.readability, d.rotation) for t, d in body.documents.items()}
    checks, gst, _ = services().kyc.validate(docs, gst_required=body.gstRequired)
    verdict = verdict_of(checks)
    report = KycReport(id=str(uuid.uuid4()), user_id=user.id, verdict=verdict,
                       gstin_masked=gstin_mask(gst.gstin) if gst else None,
                       business_name=gst.tradeName if gst else None, checks=[asdict(c) for c in checks])
    db.add(report)
    audit(db, request, user.id, "kyc_verified", verdict)
    db.commit()
    return KycOut(reportId=report.id, verdict=verdict, businessName=report.business_name,
                  gstinMasked=report.gstin_masked, checks=[asdict(c) for c in checks])


def _stage(order: Order) -> str:
    """Stage derived from elapsed time (no background worker needed); a booked slot means scheduled."""
    created = order.created_at if order.created_at.tzinfo else order.created_at.replace(tzinfo=timezone.utc)
    elapsed = (datetime.now(timezone.utc) - created).total_seconds()
    # KYC is verified before ordering, so a new order is already at "kyc"; later stages follow elapsed time.
    reached = 2 + sum(1 for s in settings.stage_seconds if elapsed >= s)
    if order.slot:
        reached = max(reached, 3)
    return STAGES[min(reached, len(STAGES)) - 1]


def _order_out(o: Order) -> dict:
    return {"id": o.id, "status": _stage(o), "stages": STAGES, "businessName": o.business_name,
            "gstinMasked": o.gstin_masked, "items": o.items, "monthly": o.monthly, "setup": o.setup,
            "contractMonths": o.contract_months, "installDays": o.install_days, "slot": o.slot,
            "partnerCode": o.partner_code, "createdAt": o.created_at.isoformat()}


@router.post("/orders", status_code=201, summary="Place an order — every rule and price is enforced server-side")
def place_order(body: OrderIn, request: Request, user: User = Depends(require_role("owner")), db: Session = Depends(get_db)):
    limiter.check(request)
    s = services()
    report = db.get(KycReport, body.kycReportId)
    if report is None or report.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "KYC report not found")
    if report.verdict != "approved":
        raise HTTPException(status.HTTP_409_CONFLICT, f"KYC is {report.verdict}; fix the documents first")

    profile = to_profile(body.profile)
    # Never trust the client's GST status: re-derive it from the registry when a GSTIN is given.
    if body.profile.gstin:
        rec = s.registry.gstin(gstin_normalise(body.profile.gstin))
        profile.gstStatus = _GST_STATUS.get(rec.status, GstStatus.none) if rec else GstStatus.none
    unknown = [i.productId for i in body.items if i.productId not in s.catalogue]
    if unknown:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, f"unknown products: {unknown}")
    items = [LineItem(i.productId, i.qty) for i in body.items]
    violations = s.rules.validate([i.productId for i in items], profile)
    if violations:
        audit(db, request, user.id, "order_rejected_rules", ",".join(f"{v.productId}:{v.block}" for v in violations))
        db.commit()
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                            {"message": "bundle breaks catalogue rules", "violations": [asdict(v) for v in violations]})
    q = s.pricing.quote(items, body.contractMonths)
    if body.expectedMonthly is not None and body.expectedMonthly != q.monthly:
        raise HTTPException(status.HTTP_409_CONFLICT,
                            {"message": "price changed; review the new quote", "serverMonthly": q.monthly})

    order = Order(id=f"EK{secrets.randbelow(900000) + 100000}", user_id=user.id, kyc_report_id=report.id,
                  profile=body.profile.model_dump(exclude={"gstin"}), items=[asdict(l) for l in q.lines],
                  monthly=q.monthly, setup=q.setup, contract_months=q.contractMonths, install_days=q.installDays,
                  business_name=report.business_name or body.profile.businessType, gstin_masked=report.gstin_masked,
                  partner_code=body.partnerCode, signed_name=body.signedName.strip())
    db.add(order)
    audit(db, request, user.id, "order_placed", order.id)
    db.commit()
    return _order_out(order)


@router.get("/orders", summary="My orders with live status")
def my_orders(user: User = Depends(current_user), db: Session = Depends(get_db)):
    return [_order_out(o) for o in db.query(Order).filter_by(user_id=user.id).order_by(Order.created_at.desc())]


def _own(order_id: str, user: User, db: Session) -> Order:
    o = db.get(Order, order_id)
    if o is None or o.user_id != user.id:  # 404 (not 403) so order IDs can't be probed
        raise HTTPException(status.HTTP_404_NOT_FOUND, "order not found")
    return o


@router.get("/orders/{order_id}", summary="Track one order")
def get_order(order_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    return _order_out(_own(order_id, user, db))


@router.post("/orders/{order_id}/slot", summary="Book the installation slot")
def book_slot(order_id: str, body: SlotIn, request: Request, user: User = Depends(require_role("owner")),
              db: Session = Depends(get_db)):
    o = _own(order_id, user, db)
    if _stage(o) in ("install", "active"):
        raise HTTPException(status.HTTP_409_CONFLICT, "installation already under way")
    o.slot = body.slot.strip()
    audit(db, request, user.id, "slot_booked", o.id)
    db.commit()
    return _order_out(o)
