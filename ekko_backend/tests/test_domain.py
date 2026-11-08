"""Engine parity with the app: advisor edge cases, rule sweep, pricing, KYC specimens, parser."""
import pytest

from app.domain.engine import GstStatus, LineItem, Profile, Segment
from app.domain.identity import Doc, gstin_ocr_repair, gstin_valid, udyam_normalise, verdict_of
from app.domain.parser import understand
from app.services import services

from .specimens import EXPECTED, documents

S = services()


def rec(**kw):
    p = Profile(**kw)
    b = S.recommender.recommend(p)
    assert not S.rules.validate(b.active_ids, p), "bundle must satisfy every catalogue rule"
    return b, p


def test_kirana_tier2_no_gstin():
    b, _ = rec(businessType="Kirana store", employees=2, cityTier=2)
    assert {"P01", "P07", "P19"} <= b.active_ids and b.item("P07").qty == 2
    assert S.pricing.quote(b.active).contractMonths == 12


def test_whatsapp_without_gstin_offers_website_and_upgrade_path():
    b, _ = rec(businessType="Boutique", employees=3, needs={"whatsapp"})
    assert "P15" not in b.active_ids and "P18" in b.active_ids
    assert any(n.kind == "upgradePath" for n in b.notices)


def test_tier2_gigabit_request_is_replaced():
    p = Profile(businessType="CA firm", segment=Segment.prof, employees=30, cityTier=2, gstStatus=GstStatus.active)
    b = S.recommender.recommend(p)
    b.items = [i for i in b.items if i.productId != "P02"] + [LineItem("P03", 1, "user")]
    S.recommender.repair(b, p)
    assert "P03" not in b.active_ids and "P02" in b.active_ids


@pytest.mark.parametrize("kw,expect,forbid", [
    (dict(segment=Segment.prof, employees=8, gstStatus=GstStatus.active, needs={"dedicatedLine"}), {"P02", "P09"}, {"P05"}),
    (dict(segment=Segment.multi, employees=20, sites=2, gstStatus=GstStatus.active, needs={"multiSiteMgmt"}), {"P09"}, {"P10"}),
    (dict(segment=Segment.prof, employees=12, gstStatus=GstStatus.cancelled, needs={"telephony", "sms", "firewall"}), set(),
     {"P12", "P14", "P21", "P03", "P05", "P06"}),
    (dict(segment=Segment.prof, employees=6, fibreFeasible=False, needs={"failover", "staticIp"}), {"P04"}, {"P01", "P02", "P09", "P11"}),
    (dict(employees=3, needs={"cctv"}), {"P23", "P01"}, set()),
])
def test_rule_edge_cases(kw, expect, forbid):
    b, _ = rec(**kw)
    assert expect <= b.active_ids and not (forbid & b.active_ids)


def test_manufacturer_static_ip_pulls_in_fibre():
    b, _ = rec(segment=Segment.mfg, employees=85, gstStatus=GstStatus.active,
               needs={"dedicatedLine", "firewall", "machineIot", "staticIp"})
    assert {"P06", "P21", "P24", "P11"} <= b.active_ids and b.active_ids & {"P01", "P02", "P03"}


def test_multisite_chain_gets_sdwan_and_24_months():
    b, _ = rec(segment=Segment.multi, employees=60, sites=6, gstStatus=GstStatus.active,
               needs={"upiPos", "cctv", "failover", "multiSiteMgmt", "tollFree", "whatsapp"})
    q = S.pricing.quote(b.active)
    assert b.item("P10").qty == 6 and q.contractMonths == 24 and q.contractDrivenBy == "P10"


def test_budget_cap_trims_addons():
    b, _ = rec(businessType="Bakery", employees=4, budget=2000, needs={"upiPos", "cctv", "guestWifi", "website"})
    assert S.pricing.quote(b.active).monthly <= 2000 and {"P01", "P07"} <= b.active_ids


def test_sweep_never_violates_rules():
    from app.domain.engine import NEEDS
    n = 0
    for seg in Segment:
        for emp in (1, 3, 9, 10, 24, 25, 60):
            for sites in (1, 2, 3, 8):
                for tier in (1, 2):
                    for gst in GstStatus:
                        for feasible in (True, False):
                            rec(segment=seg, employees=emp, sites=sites, cityTier=tier, gstStatus=gst,
                                fibreFeasible=feasible, needs=set(NEEDS))
                            n += 1
    assert n == 1792


def test_pricing_matches_case_data_rules():
    q = S.pricing.quote([LineItem("P01", 2), LineItem("P23", 3), LineItem("P19", 1)])
    assert q.setup == 3 * 1800 + 2500 and q.contractMonths == 12 and q.monthly == 2 * 1099 + 3 * 249 + 749


@pytest.mark.parametrize("k", sorted(EXPECTED))
def test_kyc_specimens(k):
    docs = {t: Doc(d["fields"], d.get("readability", 1.0), d.get("rotation", 0.0)) for t, d in documents(k).items()}
    checks, _, _ = S.kyc.validate(docs)
    verdict, flags = EXPECTED[k]
    assert verdict_of(checks) == verdict, [(c.severity, c.id) for c in checks]
    assert set(flags) <= {c.id for c in checks if c.severity != "pass"}


def test_gstin_ocr_repair_never_hides_tampering():
    exists = lambda g: S.registry.gstin(g) is not None  # noqa: E731
    assert gstin_ocr_repair("19E0GXH4115Y1ZL", exists) == "19EOGXH4115Y1ZL"
    assert gstin_ocr_repair("32TZAXB548 101Z1", exists) == "32TZAXB5481U1Z1"
    tampered = gstin_ocr_repair("08YKZXS8189L1Zo", exists)
    assert not (gstin_valid(tampered) and exists(tampered))
    assert udyam_normalise("-MH-00-9516696") == "UDYAM-MH-00-9516696"


@pytest.mark.parametrize("step,text,expect", [
    ("employees", "hum teen log hain", {"employees": 3}),
    ("spend", "पाँच हज़ार", {"currentMonthlySpend": 5000}),
    ("spend", "around 2.5k per month", {"currentMonthlySpend": 2500}),
    ("city", "मेरी दुकान पुणे में है", {"city": "Pune", "cityTier": 1}),
    ("type", "meri kirana ki dukaan hai", {"businessType": "Kirana store"}),
    ("internet", "abhi phone ka hotspot", {"currentInternet": "Mobile hotspot"}),
    ("gstin", "my gstin is 27xuixg0767d1zp", {"gstin": "27XUIXG0767D1ZP"}),
    ("pincode", "pin code 411001", {"pincode": "411001"}),
])
def test_multilingual_parser(step, text, expect):
    assert understand(step, text) == expect
