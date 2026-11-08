"""Catalogue, business profile, eligibility rules, recommender and pricing.

Port of ekko_app/lib/engine/{catalogue,profile,eligibility,recommender,pricing}.dart.
"""
from __future__ import annotations

import json
import math
from dataclasses import asdict, dataclass, field
from enum import Enum
from pathlib import Path


# ---------------------------------------------------------------- catalogue
@dataclass(frozen=True)
class Product:
    id: str
    category: str
    name: str
    description: str
    unit: str
    priceMin: int
    priceMax: int
    setup: int
    minContract: int
    tiers: tuple
    minEmployees: int
    minSites: int
    requiresGstin: bool
    requiresOneOf: tuple
    installDays: int
    segments: tuple

    @property
    def list_price(self) -> int:
        """12-month (or minimum term) price: midpoint of the catalogue range."""
        return round((self.priceMin + self.priceMax) / 2)

    @property
    def long_term_price(self) -> int:
        """24-month price: a quarter of the way up from the minimum."""
        return round(self.priceMin + (self.priceMax - self.priceMin) * 0.25)


class Catalogue:
    def __init__(self, products: list[Product]):
        self.by_id = {p.id: p for p in products}

    @classmethod
    def load(cls, path: Path) -> "Catalogue":
        raw = json.loads(path.read_text(encoding="utf-8"))
        return cls([Product(**{**r, "tiers": tuple(r["tiers"]), "requiresOneOf": tuple(r["requiresOneOf"]),
                                  "segments": tuple(r["segments"])}) for r in raw])

    def __getitem__(self, pid: str) -> Product:
        return self.by_id[pid]

    def __contains__(self, pid: str) -> bool:
        return pid in self.by_id

    @property
    def all(self):
        return self.by_id.values()


# ---------------------------------------------------------------- profile
class Segment(str, Enum):
    micro = "micro"
    prof = "prof"
    multi = "multi"
    mfg = "mfg"


class GstStatus(str, Enum):
    none = "none"
    active = "active"
    cancelled = "cancelled"
    suspended = "suspended"


NEEDS = ("upiPos", "cctv", "whatsapp", "guestWifi", "cloudEmail", "backup", "deviceSecurity", "firewall", "failover",
         "multiSiteMgmt", "staticIp", "telephony", "tollFree", "sms", "website", "dedicatedLine", "machineIot", "fleet")


@dataclass
class Profile:
    businessType: str = ""
    segment: Segment = Segment.micro
    employees: int = 1
    sites: int = 1
    cityTier: int = 1
    city: str = ""
    gstStatus: GstStatus = GstStatus.none
    hasUdyam: bool = False
    currentInternet: str = ""
    currentMonthlySpend: int = 0
    needs: set = field(default_factory=set)
    fibreFeasible: bool = True
    mobileOnly: bool = False
    budget: int | None = None
    vehicles: int = 3
    machines: int = 8

    @property
    def has_active_gstin(self) -> bool:
        return self.gstStatus == GstStatus.active


def segment_for(business_type: str, employees: int, sites: int) -> Segment:
    t = business_type.lower()
    if any(w in t for w in ("manufactur", "unit", "factory", "workshop", "press", "moulding", "processing", "textile")):
        return Segment.mfg
    if sites >= 3 or "chain" in t or "group" in t:
        return Segment.multi
    prof = ("clinic", "ca ", "ca firm", "chartered", "coaching", "law", "legal", "dental", "diagnostic", "lab",
            "architect", "insurance", "real estate", "travel", "agency", "studio", "consult", "office", "physio")
    if any(w in t for w in prof) or t == "ca":
        return Segment.prof
    return Segment.micro


# ---------------------------------------------------------------- eligibility
@dataclass(frozen=True)
class Violation:
    productId: str
    block: str  # tier | gstin | employees | sites | dependency | feasibility
    needsOneOf: tuple = ()


class Eligibility:
    def __init__(self, catalogue: Catalogue):
        self.c = catalogue

    def business_violations(self, pid: str, p: Profile) -> list[Violation]:
        prod, out = self.c[pid], []
        if p.cityTier not in prod.tiers:
            out.append(Violation(pid, "tier"))
        if prod.requiresGstin and not p.has_active_gstin:
            out.append(Violation(pid, "gstin"))
        if p.employees < prod.minEmployees:
            out.append(Violation(pid, "employees"))
        if p.sites < prod.minSites:
            out.append(Violation(pid, "sites"))
        if not p.fibreFeasible and pid in ("P01", "P02", "P03"):
            out.append(Violation(pid, "feasibility"))
        return out

    def is_eligible(self, pid: str, p: Profile) -> bool:
        return not self.business_violations(pid, p)

    def validate(self, pids, p: Profile) -> list[Violation]:
        ids, out = set(pids), []
        for pid in sorted(ids):
            out += self.business_violations(pid, p)
            dep = self.c[pid].requiresOneOf
            if dep and not ids.intersection(dep):
                out.append(Violation(pid, "dependency", dep))
        return out


# ---------------------------------------------------------------- bundle & pricing
@dataclass
class LineItem:
    productId: str
    qty: int
    origin: str = "core"  # core | need | dependency | substitute | user
    need: str | None = None
    replaces: str | None = None
    optional: bool = True
    enabled: bool = True


@dataclass
class Notice:
    kind: str  # blocked | substituted | autoAdded | upgradePath | trimmed
    productId: str
    block: str | None = None
    alternatives: tuple = ()


@dataclass
class Bundle:
    items: list[LineItem]
    notices: list[Notice]

    @property
    def active(self):
        return [i for i in self.items if i.enabled and i.qty > 0]

    @property
    def active_ids(self) -> set:
        return {i.productId for i in self.active}

    def has(self, pid: str) -> bool:
        return any(i.productId == pid for i in self.items)

    def item(self, pid: str):
        return next((i for i in self.items if i.productId == pid), None)

    def to_dict(self) -> dict:
        return {"items": [asdict(i) for i in self.items], "notices": [asdict(n) for n in self.notices]}


GST_RATE = 0.18


@dataclass
class QuoteLine:
    productId: str
    name: str
    qty: int
    unitPrice: int
    monthly: int
    setup: int


@dataclass
class Quote:
    lines: list[QuoteLine]
    contractMonths: int
    contractDrivenBy: str | None
    installDays: int

    @property
    def monthly(self) -> int:
        return sum(l.monthly for l in self.lines)

    @property
    def setup(self) -> int:
        return sum(l.setup for l in self.lines)

    def to_dict(self) -> dict:
        return {"lines": [asdict(l) for l in self.lines], "monthly": self.monthly,
                "monthlyWithGst": round(self.monthly * (1 + GST_RATE)), "setup": self.setup,
                "setupWithGst": round(self.setup * (1 + GST_RATE)), "contractMonths": self.contractMonths,
                "contractDrivenBy": self.contractDrivenBy, "installDays": self.installDays,
                "noLockIn": self.contractMonths <= 1}


class Pricing:
    """setup = Σ setup×qty and contract = longest minimum term (true for all 368 activated bundles).
    Monthly price is policy: catalogue midpoint, or the long-term price on a 24-month term."""

    def __init__(self, catalogue: Catalogue):
        self.c = catalogue

    def minimum_contract(self, items) -> int:
        return max([1] + [self.c[i.productId].minContract for i in items])

    def quote(self, items, contract_months: int | None = None) -> Quote:
        items = [i for i in items if i.qty > 0]
        min_c = self.minimum_contract(items)
        term = max(contract_months or min_c, min_c)
        long_term = term >= 24
        driver, install, lines = None, 0, []
        for i in items:
            p = self.c[i.productId]
            if p.minContract == min_c and min_c > 1 and driver is None:
                driver = p.id
            install = max(install, p.installDays)
            unit = p.long_term_price if long_term else p.list_price
            lines.append(QuoteLine(p.id, p.name, i.qty, unit, unit * i.qty, p.setup * i.qty))
        return Quote(lines, term, driver, install)


# ---------------------------------------------------------------- recommender
GST_GATED = {"P03", "P05", "P06", "P10", "P12", "P13", "P14", "P15", "P21", "P24"}
SUBSTITUTES = {"P03": [["P02"]], "P06": [["P05"], ["P02", "P09"]], "P05": [["P02", "P09"]], "P01": [["P04"]],
               "P02": [["P04"]], "P10": [["P09"]], "P21": [["P22", "P20"]], "P15": [["P18"]]}
DEFAULT_NEEDS = {Segment.micro: ["upiPos"], Segment.prof: ["cloudEmail", "deviceSecurity", "backup"],
                 Segment.multi: ["upiPos", "cctv", "failover"], Segment.mfg: ["dedicatedLine", "cloudEmail", "deviceSecurity"]}
NEED_PRODUCT = {"upiPos": "P19", "cctv": "P23", "whatsapp": "P15", "guestWifi": "P22", "cloudEmail": "P16",
                "backup": "P17", "deviceSecurity": "P20", "firewall": "P21", "failover": "P09", "multiSiteMgmt": "P10",
                "staticIp": "P11", "telephony": "P12", "tollFree": "P13", "sms": "P14", "website": "P18",
                "machineIot": "P24", "fleet": "P25"}
TRIM_ORDER = ["website", "backup", "sms", "tollFree", "guestWifi", "fleet", "cctv", "telephony", "staticIp", "failover",
              "machineIot", "deviceSecurity", "firewall", "multiSiteMgmt", "whatsapp", "cloudEmail", "upiPos"]


class Recommender:
    def __init__(self, catalogue: Catalogue):
        self.c = catalogue
        self.rules = Eligibility(catalogue)
        self.pricing = Pricing(catalogue)

    def recommend(self, p: Profile) -> Bundle:
        needs = [] if p.mobileOnly else ([n for n in NEEDS if n in p.needs] if p.needs else DEFAULT_NEEDS[p.segment])
        items: list[LineItem] = []
        if not p.mobileOnly:
            base = self._base(p, needs)
            items.append(LineItem(base, self._qty(base, p), "core", optional=False))
        line = "P07" if p.segment == Segment.micro else "P08"
        items.append(LineItem(line, self._line_qty(p), "core", optional=not p.mobileOnly))
        for n in needs:
            pid = NEED_PRODUCT.get(n)
            if pid and not any(i.productId == pid for i in items):
                items.append(LineItem(pid, self._qty(pid, p), "need", need=n))
        b = Bundle(items, [])
        self.repair(b, p)
        if p.budget is not None:
            self._fit_budget(b, p.budget)
        return b

    def _base(self, p: Profile, needs) -> str:
        if "dedicatedLine" in needs or p.segment == Segment.mfg:
            return "P06" if p.employees >= 25 else "P05"
        if p.segment == Segment.micro:
            return "P01"
        if p.segment == Segment.prof:
            return "P03" if (p.cityTier == 1 and p.employees >= 20 and p.has_active_gstin) else "P02"
        return "P02" if p.employees / max(p.sites, 1) >= 10 else "P01"

    def _line_qty(self, p: Profile) -> int:
        if p.segment == Segment.micro:
            return 2 if p.employees >= 2 else 1
        return min(max(math.ceil(p.employees / 10), 1), 6)

    def _qty(self, pid: str, p: Profile) -> int:
        sites = max(p.sites, 1)
        if pid in ("P03", "P05", "P06", "P11", "P13", "P14", "P15", "P17", "P18"):
            return 1
        if pid in ("P07", "P08"):
            return self._line_qty(p)
        return {
            "P16": min(max(p.employees, 1), 20),
            "P20": min(max(p.employees, 1), 12),
            "P23": min(sites * (1 if p.segment == Segment.micro else 2), 24),
            "P21": sites if p.segment == Segment.multi else 1,
            "P12": min(max(math.ceil(p.employees / 6), 2), 4),
            "P24": max(p.machines, 1),
            "P25": max(p.vehicles, 1),
        }.get(pid, sites)

    def repair(self, b: Bundle, p: Profile) -> None:
        for _ in range(6):
            changed = False
            for item in list(b.items):
                v = self.rules.business_violations(item.productId, p)
                if not v:
                    continue
                b.items.remove(item)
                changed = True
                block = v[0].block
                alt = next((o for o in SUBSTITUTES.get(item.productId, []) if all(self.rules.is_eligible(s, p) for s in o)), None)
                if alt:
                    for pid in alt:
                        if not b.has(pid):
                            b.items.append(LineItem(pid, self._qty(pid, p), "substitute", need=item.need,
                                                    replaces=item.productId, optional=item.optional))
                    b.notices.append(Notice("substituted", item.productId, block, tuple(alt)))
                else:
                    b.notices.append(Notice("blocked", item.productId, block))
                if block == "gstin" and item.productId in GST_GATED:
                    b.notices.append(Notice("upgradePath", item.productId, "gstin"))
            for v in self.rules.validate([i.productId for i in b.items], p):
                if v.block != "dependency":
                    continue
                add = next((pid for pid in v.needsOneOf if pid in ("P01", "P02", "P04") and self.rules.is_eligible(pid, p)), "")
                if not add:
                    b.items = [i for i in b.items if i.productId != v.productId]
                    b.notices.append(Notice("blocked", v.productId, "dependency"))
                else:
                    qty = 1 if v.productId == "P11" else self._qty(add, p)
                    b.items.append(LineItem(add, qty, "dependency", optional=False))
                    b.notices.append(Notice("autoAdded", add, alternatives=(v.productId,)))
                changed = True
                break
            if not changed:
                return

    def _fit_budget(self, b: Bundle, budget: int) -> None:
        for need in TRIM_ORDER:
            if self.pricing.quote(b.active).monthly <= budget:
                return
            for item in b.items:
                if item.need == need and item.optional and item.enabled:
                    item.enabled = False
                    b.notices.append(Notice("trimmed", item.productId))
