"""API behaviour: auth, roles, server-side enforcement, KYC, orders, partner, DPDP rights."""
from .conftest import login_owner
from .specimens import documents

DENTAL = {"businessType": "Dental clinic", "segment": "prof", "employees": 14, "cityTier": 1,
          "gstStatus": "active", "gstin": "27XUIXG0767D1ZP", "needs": ["cloudEmail", "deviceSecurity", "backup"]}


def kyc_report(client, owner, k="K03"):
    r = client.post("/v1/kyc/verify", json={"documents": documents(k)}, headers=owner)
    assert r.status_code == 200, r.text
    return r.json()


def plan_items(client, profile):
    r = client.post("/v1/plans/recommend", json=profile).json()
    return [{"productId": l["productId"], "qty": l["qty"]} for l in r["quote"]["lines"]], r["quote"]["monthly"]


# ---- ops & hardening
def test_health_ready_and_security_headers(client):
    r = client.get("/health")
    assert r.json()["ok"] and r.headers["X-Content-Type-Options"] == "nosniff" and r.headers["X-Request-ID"]
    ready = client.get("/ready").json()
    assert ready["products"] == 25 and ready["gstinRecords"] == 3534 and ready["ai"] == "rules-only"
    assert client.get("/openapi.json").status_code == 200


def test_unknown_fields_and_bad_input_rejected(client):
    assert client.post("/v1/plans/recommend", json={"employees": -5}).status_code == 422
    assert client.post("/v1/plans/recommend", json={"isAdmin": True}).status_code == 422
    assert client.post("/v1/advisor/understand", json={"step": "drop table", "text": "x"}).status_code == 422


# ---- auth
def test_otp_login_and_lockout(client):
    phone = "9876500001"
    otp = client.post("/v1/auth/otp/request", json={"phone": phone}).json()["demoOtp"]
    wrong = "000000" if otp != "000000" else "111111"
    for _ in range(4):
        assert client.post("/v1/auth/otp/verify", json={"phone": phone, "otp": wrong}).status_code == 401
    assert client.post("/v1/auth/otp/verify", json={"phone": phone, "otp": wrong}).status_code == 401
    # Locked: even the right OTP is refused now.
    assert client.post("/v1/auth/otp/verify", json={"phone": phone, "otp": otp}).status_code == 429
    assert client.post("/v1/auth/otp/request", json={"phone": phone}).status_code == 429


def test_invalid_phone_and_token(client):
    assert client.post("/v1/auth/otp/request", json={"phone": "1234567890"}).status_code == 422
    assert client.get("/v1/orders", headers={"Authorization": "Bearer forged.token.here"}).status_code == 401
    assert client.get("/v1/orders").status_code == 401


def test_roles_are_enforced(client, owner, partner):
    assert client.get("/v1/partner/leads", headers=owner).status_code == 403
    assert client.post("/v1/kyc/verify", json={"documents": documents("K03")}, headers=partner).status_code == 403
    assert client.post("/v1/auth/partner", json={"partnerId": "PTR-1001", "pin": "000000"}).status_code == 401


# ---- plans
def test_registry_lookups(client, owner):
    r = client.get("/v1/registry/gstin/27XUIXG0767D1ZP", headers=owner).json()
    assert r["tradeName"] == "Ganesh Woodcraft" and "•" in r["gstinMasked"]
    assert client.get("/v1/registry/gstin/08YKZXS8189L1Z0", headers=owner).status_code == 422  # tampered check digit
    assert client.get("/v1/registry/udyam/UDYAM-MH-00-9516696", headers=owner).json()["enterpriseName"] == "Ganesh Woodcraft"


def test_advisor_understands_without_ai(client):
    r = client.post("/v1/advisor/understand", json={"step": "employees", "text": "hum teen log hain", "language": "hi"}).json()
    assert r == {"fields": {"employees": 3}, "source": "rules"}


def test_quote_flags_ineligible_bundle(client):
    body = {"profile": {"employees": 3, "cityTier": 2}, "items": [{"productId": "P03", "qty": 1}, {"productId": "P10", "qty": 1}]}
    r = client.post("/v1/plans/quote", json=body).json()
    assert not r["valid"] and {"tier", "gstin", "employees", "sites"} <= {v["block"] for v in r["violations"]}
    lone = client.post("/v1/plans/quote", json={"profile": {}, "items": [{"productId": "P23", "qty": 1}]}).json()
    assert [v["block"] for v in lone["violations"]] == ["dependency"]  # CCTV needs an internet line


# ---- orders: the server is the source of truth
def test_full_order_flow_with_slot_and_partner_credit(client, owner, partner):
    report = kyc_report(client, owner)
    assert report["verdict"] == "approved" and report["businessName"] == "Ganesh Woodcraft"
    items, monthly = plan_items(client, DENTAL)
    r = client.post("/v1/orders", headers=owner, json={
        "profile": DENTAL, "items": items, "kycReportId": report["reportId"], "signedName": "Joseph Singh",
        "acceptTerms": True, "partnerCode": "PTR-1001", "expectedMonthly": monthly})
    assert r.status_code == 201, r.text
    order = r.json()
    assert order["monthly"] == monthly and order["status"] == "kyc" and order["gstinMasked"]
    booked = client.post(f"/v1/orders/{order['id']}/slot", json={"slot": "Mon 9 Nov, 9 – 12"}, headers=owner).json()
    assert booked["status"] == "scheduled"
    earnings = client.get("/v1/partner/earnings", headers=partner).json()
    assert earnings["assistedOrders"] >= 1 and earnings["commission"] > 0


def test_tampered_bundle_is_rejected(client, owner):
    report = kyc_report(client, owner)
    small = {"businessType": "Kirana store", "employees": 2, "cityTier": 2}
    r = client.post("/v1/orders", headers=owner, json={
        "profile": small, "items": [{"productId": "P06", "qty": 1}, {"productId": "P15", "qty": 1}],
        "kycReportId": report["reportId"], "signedName": "Joseph Singh", "acceptTerms": True})
    assert r.status_code == 422 and r.json()["detail"]["violations"]


def test_client_cannot_fake_gst_status(client, owner):
    report = kyc_report(client, owner)
    cancelled = {"businessType": "Travel agency", "segment": "prof", "employees": 12, "gstStatus": "active",
                 "gstin": "37IHKXV5167L1ZS"}  # K01's GSTIN is Cancelled in the registry
    r = client.post("/v1/orders", headers=owner, json={
        "profile": cancelled, "items": [{"productId": "P02", "qty": 1}, {"productId": "P12", "qty": 2}],
        "kycReportId": report["reportId"], "signedName": "Joseph Singh", "acceptTerms": True})
    assert r.status_code == 422 and any(v["block"] == "gstin" for v in r.json()["detail"]["violations"])


def test_price_tampering_is_caught(client, owner):
    report = kyc_report(client, owner)
    items, monthly = plan_items(client, DENTAL)
    r = client.post("/v1/orders", headers=owner, json={
        "profile": DENTAL, "items": items, "kycReportId": report["reportId"], "signedName": "Joseph Singh",
        "acceptTerms": True, "expectedMonthly": monthly - 500})
    assert r.status_code == 409 and r.json()["detail"]["serverMonthly"] == monthly


def test_order_needs_approved_kyc_and_is_private(client, owner):
    rejected = kyc_report(client, owner, "K06")
    assert rejected["verdict"] == "rejected"
    items, _ = plan_items(client, DENTAL)
    body = {"profile": DENTAL, "items": items, "kycReportId": rejected["reportId"], "signedName": "Pooja Shah", "acceptTerms": True}
    assert client.post("/v1/orders", headers=owner, json=body).status_code == 409
    ok = kyc_report(client, owner)
    order = client.post("/v1/orders", headers=owner, json=body | {"kycReportId": ok["reportId"]}).json()
    stranger = login_owner(client)
    assert client.get(f"/v1/orders/{order['id']}", headers=stranger).status_code == 404
    assert client.post("/v1/orders", headers=stranger, json=body | {"kycReportId": ok["reportId"]}).status_code == 404


# ---- partner & DPDP
def test_partner_leads_ranked_and_filtered(client, owner, partner):
    client.post("/v1/leads?reason=callback", json=DENTAL, headers=owner)
    r = client.get("/v1/partner/leads?segment=prof&limit=20", headers=partner).json()
    scores = [l["score"] for l in r["leads"]]
    assert r["total"] > 1000 and scores == sorted(scores, reverse=True)
    assert all(l["segment"] == "prof" for l in r["leads"]) and all("contact" not in l for l in r["leads"])


def test_consent_export_and_erasure(client):
    me = login_owner(client)
    client.post("/v1/me/consents", json={"purpose": "kyc_verification", "granted": True}, headers=me)
    state = client.post("/v1/me/consents", json={"purpose": "marketing", "granted": False}, headers=me).json()
    assert state["kyc_verification"]["granted"] and not state["marketing"]["granted"]
    kyc_report(client, me)
    data = client.get("/v1/me/export", headers=me).json()
    assert data["kycReports"] and "phone" not in str(data["user"]).lower()
    assert any(a["action"] == "data_exported" for a in client.get("/v1/me/audit", headers=me).json())
    assert client.delete("/v1/me", headers=me).json() == {"erased": True}
    assert client.get("/v1/me/export", headers=me).status_code == 401


def test_app_compatible_advisor_endpoints(client):
    r = client.post("/v1/advisor/ask", json={"question": "static IP kya hota hai?", "language": "hi"}).json()
    assert r["source"] == "catalogue" and "Static IP" in r["text"]
    assert client.post("/v1/advisor/explain", json={"items": [], "monthly": 999}).json() == {"text": None}
