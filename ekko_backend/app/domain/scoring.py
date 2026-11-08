"""Lead propensity model (logistic regression trained on smb_leads.csv by tool/build_assets.py)."""
from __future__ import annotations

import json
import math
from pathlib import Path

from .engine import GstStatus, Profile, Segment

SEGMENT_LABEL = {Segment.micro: "Micro retail & services", Segment.prof: "Professional offices",
                 Segment.multi: "Small multi-site businesses", Segment.mfg: "Small manufacturers"}
GST_LABEL = {GstStatus.active: "Active", GstStatus.cancelled: "Cancelled", GstStatus.suspended: "Suspended",
             GstStatus.none: "none"}


class Propensity:
    def __init__(self, intercept: float, weights: dict[str, float], auc: float):
        self.intercept, self.weights, self.auc = intercept, weights, auc

    @classmethod
    def load(cls, path: Path) -> "Propensity":
        j = json.loads(path.read_text(encoding="utf-8"))
        return cls(j["intercept"], j["weights"], j["cvAuc"])

    def score_profile(self, p: Profile, source: str = "Website form") -> float:
        cats = {"lead_source": source, "segment": SEGMENT_LABEL[p.segment], "city_tier": str(p.cityTier),
                "gst_status": GST_LABEL[p.gstStatus], "has_udyam": "Y" if p.hasUdyam else "N"}
        if p.currentInternet:
            cats["current_internet"] = p.currentInternet
        z = self.intercept + sum(self.weights.get(f"{k}_{v}", 0.0) for k, v in cats.items())
        z += self.weights.get("log_employees", 0) * math.log1p(p.employees)
        z += self.weights.get("log_sites", 0) * math.log1p(p.sites)
        z += self.weights.get("log_spend", 0) * math.log1p(p.currentMonthlySpend)
        return 1 / (1 + math.exp(-z))
