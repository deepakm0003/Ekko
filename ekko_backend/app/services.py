"""Loaded-once reference data and engines, plus small shared helpers."""
from __future__ import annotations

import json
from functools import lru_cache

from fastapi import Request
from sqlalchemy.orm import Session

from .config import settings
from .domain.engine import Catalogue, Eligibility, GstStatus, Pricing, Profile, Recommender, Segment
from .domain.identity import KycValidator, Registry
from .domain.scoring import Propensity
from .models import AuditLog
from .schemas import ProfileIn


class Services:
    def __init__(self):
        d = settings.data_dir
        self.catalogue = Catalogue.load(d / "catalogue.json")
        self.registry = Registry.load(d)
        self.propensity = Propensity.load(d / "propensity_model.json")
        self.recommender = Recommender(self.catalogue)
        self.rules = Eligibility(self.catalogue)
        self.pricing = Pricing(self.catalogue)
        self.kyc = KycValidator(self.registry)
        self.cockpit_leads = json.loads((d / "cockpit_leads.json").read_text(encoding="utf-8"))


@lru_cache
def services() -> Services:
    return Services()


def to_profile(p: ProfileIn) -> Profile:
    return Profile(businessType=p.businessType, segment=Segment(p.segment), employees=p.employees, sites=p.sites,
                   cityTier=p.cityTier, city=p.city, gstStatus=GstStatus(p.gstStatus), hasUdyam=p.hasUdyam,
                   currentInternet=p.currentInternet, currentMonthlySpend=p.currentMonthlySpend, needs=set(p.needs),
                   fibreFeasible=p.fibreFeasible, mobileOnly=p.mobileOnly, budget=p.budget, vehicles=p.vehicles,
                   machines=p.machines)


def audit(db: Session, request: Request | None, actor: str, action: str, detail: str | None = None) -> None:
    rid = getattr(request.state, "request_id", None) if request is not None else None
    db.add(AuditLog(actor=actor, action=action, detail=detail, request_id=rid))
