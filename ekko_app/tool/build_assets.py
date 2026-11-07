"""Builds the JSON assets Ekko ships with, from the hackathon CSVs.

Usage: python -I tool/build_assets.py <data_dir> <out_dir>
"""
import json
import os
import re
import sys

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import cross_val_score

data_dir, out_dir = sys.argv[1], sys.argv[2]


def rd(name):
    return pd.read_csv(os.path.join(data_dir, name))


def dump(name, obj):
    path = os.path.join(out_dir, name)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(obj, fh, ensure_ascii=False, separators=(",", ":"))
    print(f"{name}: {os.path.getsize(path) / 1024:.0f} KB")


# ---- Catalogue -------------------------------------------------------------
cat = rd("product_catalogue.csv")
products = []
for r in cat.itertuples():
    products.append(dict(
        id=r.product_id, category=r.category, name=r.product_name, description=r.description,
        unit=r.unit, priceMin=int(r.price_min_inr_per_month), priceMax=int(r.price_max_inr_per_month),
        setup=int(r.one_time_setup_inr), minContract=int(r.min_contract_months),
        tiers=[int(t) for t in str(r.available_city_tiers).split(";")],
        minEmployees=int(r.min_employees), minSites=int(r.min_sites),
        requiresGstin=r.requires_gstin == "Y",
        requiresOneOf=str(r.requires_one_of).split("|") if isinstance(r.requires_one_of, str) else [],
        installDays=int(r.typical_install_days), segments=str(r.target_segments).split(";")))
dump("catalogue.json", products)

# ---- Registries (compact column arrays) ------------------------------------
g = rd("mock_gstin_registry.csv")
dump("gstin_registry.json", {"fields": list(g.columns), "rows": g.values.tolist()})
u = rd("mock_udyam_registry.csv")
dump("udyam_registry.json", {"fields": list(u.columns), "rows": u.values.tolist()})

# ---- Leads -------------------------------------------------------------------
l = rd("smb_leads.csv")
l["act"] = (l.outcome == "Activated").astype(int)
l["gst_status"] = l.gstin.map(g.set_index("gstin").status).fillna("none")
SEG_KEY = {"Micro retail & services": "micro", "Professional offices": "prof",
           "Small multi-site businesses": "multi", "Small manufacturers": "mfg"}

# Propensity model: pre-contact features only, so the app can score a brand-new lead.
CATS = ["lead_source", "segment", "city_tier", "preferred_language", "annual_turnover_band",
        "current_internet", "current_provider", "gst_status", "has_udyam"]
X = pd.get_dummies(l[CATS].astype(str))
X["log_employees"] = np.log1p(l.employee_count)
X["log_sites"] = np.log1p(l.num_sites)
X["log_spend"] = np.log1p(l.monthly_telecom_spend_inr)
model = LogisticRegression(max_iter=3000, C=0.5)
auc = cross_val_score(model, X, l.act, cv=5, scoring="roc_auc").mean()
model.fit(X, l.act)
l["score"] = model.predict_proba(X)[:, 1]
dump("propensity_model.json", {
    "intercept": float(model.intercept_[0]),
    "weights": {k: round(float(v), 5) for k, v in zip(X.columns, model.coef_[0])},
    "cvAuc": round(float(auc), 3), "categorical": CATS,
    "numeric": ["log_employees", "log_sites", "log_spend"]})
print("propensity AUC", round(auc, 3))


def why(row):
    out = []
    if row.gst_status == "Active":
        out.append("Active GSTIN")
    if row.lead_source in ("Referral", "Inbound call"):
        out.append(f"{row.lead_source} lead")
    if row.segment in ("Small multi-site businesses", "Small manufacturers"):
        out.append("High-value segment")
    if row.current_provider == "Accel (mobile only)":
        out.append("Existing Accel mobile customer")
    if row.current_internet in ("Leased line", "Mixed per site"):
        out.append("Already on business-grade internet")
    if row.monthly_telecom_spend_inr >= 4300:
        out.append("High current spend")
    return out[:3]


d = l[l.act == 0].copy()
d["tag"] = d.apply(why, axis=1)
cockpit = [dict(
    id=r.lead_id, name=r.business_name, type=r.business_type, segment=SEG_KEY[r.segment], city=r.city,
    tier=int(r.city_tier), lang=r.preferred_language, employees=int(r.employee_count), sites=int(r.num_sites),
    source=r.lead_source, stage=r.stage_reached, drop=r.drop_reason, spend=int(r.monthly_telecom_spend_inr),
    gst=r.gst_status, udyam=r.has_udyam == "Y",
    internet=r.current_internet if isinstance(r.current_internet, str) else "",
    interest=r.products_of_interest.split(";"), contact=r.contact_name, role=r.contact_role,
    score=round(float(r.score), 4), why=r.tag) for r in d.sort_values("score", ascending=False).itertuples()]
dump("cockpit_leads.json", cockpit)

# ---- Insights ------------------------------------------------------------------
a = l[l.act == 1].copy()
a["churn"] = (a.churned_within_6_months == "Y").astype(int)
STAGES = ["Lead", "Contacted", "Needs assessed", "Quote accepted", "KYC complete", "Activated"]
order = {s: i for i, s in enumerate(STAGES)}
reach = [int((l.stage_reached.map(order) >= i).sum()) for i in range(len(STAGES))]

seg_rows = []
for s, grp in l.groupby("segment"):
    ga = grp[grp.act == 1]
    cac = grp.acquisition_cost_inr.sum() / max(len(ga), 1)
    arpu = ga.monthly_bundle_value_inr.median()
    seg_rows.append(dict(segment=s, key=SEG_KEY[s], leads=len(grp), activation=round(grp.act.mean() * 100, 1),
                         arpu=int(arpu), churn=round((ga.churned_within_6_months == "Y").mean() * 100, 1),
                         cac=int(cac), payback=round(cac / arpu, 1)))

GROUPS = {
    "Couldn't reach / no visit": ["Unreachable after 3 attempts", "Owner had no time for a visit",
                                  "Wrong or invalid number", "Visit not scheduled by sales"],
    "Not interested / locked in": ["Not interested on first call", "Locked in with current provider",
                                   "Only wanted a mobile plan", "Decided to wait"],
    "Price & quote": ["Price too high", "Competitor offered cheaper plan", "Quote too complex to understand",
                      "Quote took too long to arrive"],
    "Paperwork & KYC": ["Missing GST or Udyam document", "Found paperwork too long",
                        "Authorised signatory not available", "Document details did not match"],
    "Install & payment": ["Installation delayed beyond 21 days", "Customer cancelled before install",
                          "Site not feasible for fibre", "First payment failed"],
}
dropped = l[l.act == 0]
drop_groups = [dict(group=k, count=int(dropped.drop_reason.isin(v).sum()),
                    reasons=[dict(reason=x, count=int((dropped.drop_reason == x).sum())) for x in v])
               for k, v in GROUPS.items()]

calls = a.groupby("customer_follow_up_calls").agg(n=("churn", "size"), churn=("churn", "mean"),
                                                  nps=("nps_score", "mean"))


def pset(s):
    return set(re.sub(r"x\d+", "", s).split(";")) if isinstance(s, str) else set()


sold_not_asked = int(sum(1 for i, b in zip(a.products_of_interest, a.bundle_products) if not (pset(i) & pset(b))))
src = l.groupby("lead_source").agg(leads=("act", "size"), acts=("act", "sum"), cost=("acquisition_cost_inr", "sum"))
lang = l.groupby("preferred_language").act.agg(["size", "mean"]).sort_values("mean", ascending=False)
l["decile"] = pd.qcut(l.score.rank(method="first"), 10, labels=False)
dec = l.groupby("decile").act.agg(["size", "sum", "mean"])
top30 = int(dec.loc[[7, 8, 9], "sum"].sum())
gst = l.assign(k=l.has_gstin + "/" + l.has_udyam).groupby("k").act.mean()

insights = dict(
    period="Apr–Jun 2026", totalLeads=len(l), activated=int(l.act.sum()),
    funnel=[dict(stage=s, count=c) for s, c in zip(STAGES, reach)],
    avgDays=round(a.days_lead_to_activation.mean(), 1), avgChases=round(a.customer_follow_up_calls.mean(), 1),
    blendedCac=int(l.acquisition_cost_inr.sum() / l.act.sum()), medianBundle=int(a.monthly_bundle_value_inr.median()),
    churn6m=round(a.churn.mean() * 100, 1), nps=round(a.nps_score.mean(), 1),
    segments=seg_rows, dropGroups=drop_groups,
    chaseVsChurn=[dict(calls=int(k), n=int(v.n), churn=round(v.churn * 100, 1), nps=round(v.nps, 1))
                  for k, v in calls.iterrows()],
    soldNotAsked=sold_not_asked, ineligibleSold=56,
    cancelledGstinActivated=int(((l.gst_status == "Cancelled") & (l.act == 1)).sum()),
    sources=[dict(source=k, leads=int(v.leads), activation=round(v.acts / v.leads * 100, 1), cac=int(v.cost / v.acts))
             for k, v in src.iterrows()],
    languages=[dict(language=k, leads=int(v["size"]), activation=round(v["mean"] * 100, 1))
               for k, v in lang.iterrows()],
    gstinActivation={k: round(v * 100, 1) for k, v in gst.items()},
    propensity=dict(auc=round(float(auc), 3), deciles=[round(float(x) * 100, 1) for x in dec["mean"]],
                    top30Share=round(top30 / int(l.act.sum()) * 100, 1)),
    targets=[dict(metric="Lead → activation", today="7.4%", target="15%"),
             dict(metric="Days to activate", today="17.6", target="≤ 7"),
             dict(metric="Acquisition cost", today="₹15,053", target="≤ ₹6,000"),
             dict(metric="Status calls / customer", today="3.0", target="< 0.5"),
             dict(metric="6-month churn", today="15.2%", target="≤ 10%")],
)
dump("insights.json", insights)
