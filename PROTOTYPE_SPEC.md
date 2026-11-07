# Udyam Digital — Prototype Build Spec (Team Code Sync)

Companion to [RESEARCH_Udyam_Digital.md](RESEARCH_Udyam_Digital.md). Everything here comes from the case PDF, the README, and row-level analysis of all 5 data files.

---

## 0. The "one thing" the prototype must prove

> **An owner finishes discovery → bundle → price → KYC → order on their phone, in their language, in ~10 minutes, and the system can never sell them something they're not eligible for.**

The prototype shows two layers:
1. **The customer journey:** advisor → quote → Smart KYC → tracker.
2. **The results from the given data:** an insights page + partner cockpit built directly on `smb_leads.csv`, which proves our business case with their own numbers.

---

## 1. Rules reverse-engineered from the data (the quote engine must match these)

| Rule | What the data shows | What we implement |
|---|---|---|
| **One-time setup fee** | `one_time_setup_inr` = Σ(catalogue setup × qty) for **100%** of the 368 activated bundles | Setup = sum of setup × qty, exactly |
| **Contract length** | Bundle contract = the **max of `min_contract_months`** across its products, for 368/368 | Contract = max(min_contract_months). The UI shows which product forces it (e.g. "24 months because of Managed Firewall") |
| **Monthly price** | Always within the catalogue min–max range. The position in the range looks random (mean 0.48), unrelated to tier, segment or contract | Our own policy: **list price = midpoint**, rounded to ₹9. Picking 24 months moves the price toward the minimum. Show the range transparently |
| **Per-site products** (P01, P02, P09, P10, P19, P22) | qty = `num_sites` in 90–100% of cases | Default qty = number of sites |
| **P03 Fibre 1G, P11 Static IP** | qty is always 1 | qty 1 (HQ only) |
| **Mobile lines P07/P08** | 1–2 per site for micro, up to 6 for larger businesses, never more than employees | Default: micro 2, others ≈ employees/10 (min 1). The owner can edit |
| **P16 email users, P20 devices** | Never more than employees | Default = employees (up to 25), editable |
| **P23 CCTV** | ~1–2 cameras per site | Default 2 per site (1 for micro) |
| **Install ETA** | Bundle install = max `typical_install_days` of its products. Today the KYC→activation gap is ~4.8 days on top | Tracker ETA = order date + max(typical_install_days) |

---

## 2. Eligibility engine (the guardrail beneath the AI)

**Design pattern:** the LLM *proposes* products, then deterministic Python *validates* them and returns violations plus alternatives. The LLM only *explains* the validated result. This is the "neuro-symbolic / hard-rule override" guardrail pattern. Every rule decision is logged so it can be audited.

### The rules
1. **City tier:** P03 Fibre 1G is tier-1 only. All other products are available in tiers 1 and 2.
2. **GSTIN required:** P03, P05, P06, P10, P12, P13, P14, P15, P21, P24 need an **Active** GSTIN. Cancelled or Suspended counts as no GSTIN.
3. **Minimum employees:** P03 ≥ 5, P05 ≥ 10, P06 ≥ 25, P10 ≥ 10, P12 ≥ 3, P21 ≥ 10, P24 ≥ 10.
4. **Minimum sites:** P10 SD-WAN needs ≥ 3 sites.
5. **Dependencies:** each of these needs at least one of the listed products in the same bundle:

| Product | Needs one of | Watch out |
|---|---|---|
| P09 Failover, P10 SD-WAN, P21 Firewall | P01, P02, P03, P05, P06 | **AirFiber (P04) does not count** |
| P11 Static IP | P01, P02, P03 | **Leased line and AirFiber do not count** |
| P22 Secure Wi-Fi | P01, P02, P03, P04 | **Leased line does not count** |
| P12 Cloud Telephony, P23 CCTV | Any connectivity product, P01–P06 | — |

6. **Feasibility (our addition):** if fibre isn't feasible at the pincode, substitute P04 AirFiber. That also removes P09, P11 and P21, because they need fibre, and the advisor explains why.

### Substitution map (what the advisor offers instead of just saying "no")

| Blocked product | Why | Offer instead |
|---|---|---|
| P03 Fibre 1G in tier 2 | Tier | P02 Fibre 300 |
| P05/P06 leased line, < 10 or < 25 employees or no GSTIN | Size or GST | P02/P03 + P09 Failover |
| P06 with 10–24 employees | Size | P05 Leased Line 20 |
| P10 SD-WAN with < 3 sites or < 10 employees | Size | P09 Failover per site |
| P12 Cloud telephony with < 3 employees or no GSTIN | Size or GST | P07/P08 mobile lines |
| P21 Firewall with < 10 employees or no GSTIN | Size or GST | P22 Secure Wi-Fi + P20 Endpoint Security |
| P15 WhatsApp API, P14 SMS or P13 Toll-free without GSTIN | GST | P18 Website with a catalogue now, plus "register GST free → unlock WhatsApp API". Mark as an *upgrade path* |
| P24 IoT with < 10 employees or no GSTIN | Size or GST | Not available. Say so plainly |

**Why this matters:** 769 leads (15%) asked for at least one product they weren't eligible for (673 of them GST-related), and 56 activated customers were *sold* ineligible bundles.

---

## 3. Likely judge test scenarios (we must pass all of these live)

The judges have 15 secret scenarios. These are the edge cases the catalogue implies, so we build and rehearse all of them:

| # | Scenario | Expected advisor behaviour |
|---|---|---|
| 1 | Kirana in tier-2 city, 2 staff, hotspot user, no GSTIN, speaks Hindi | Hindi conversation. AirFiber or Fibre 100 + 2 × Postpaid 299 + POS. No WhatsApp API (explain GST, offer website/catalogue). Roughly ₹1.6–2.5k/month |
| 2 | Same kirana, but asks for a WhatsApp catalogue | Explain the GST requirement simply and offer the upgrade path. Don't sell P15 |
| 3 | Dental clinic, 14 staff, tier 1, active GSTIN | Fibre 300 or 1G + Postpaid + Cloud Email × users + Endpoint + Backup + optional Failover / Static IP |
| 4 | CA firm in a tier-2 city asks for 1 Gbps | P03 isn't sold in tier 2. Offer Fibre 300 |
| 5 | 8-employee office asks for a leased line | Below the 10-employee minimum. Offer Fibre 300 + Failover |
| 6 | Restaurant chain with 2 sites asks for SD-WAN | Needs ≥ 3 sites. Offer Failover per site |
| 7 | Retail chain with 6 sites, 60 staff, GSTIN | Per-site Fibre + Failover + POS + CCTV, plus SD-WAN + Toll-free + WhatsApp API. ~₹28k+ |
| 8 | Auto-parts unit, 85 staff, GSTIN | Leased Line 100 + Firewall + IoT machine monitoring + Postpaid 599 + Email + Static IP (needs fibre, not the leased line) |
| 9 | Asks for Static IP with only a leased line | P11 needs P01–P03. Add fibre or drop it |
| 10 | Asks for CCTV only, no internet | Auto-adds a connectivity product and explains why |
| 11 | GSTIN entered is **Cancelled** or **Suspended** | Treat as no GSTIN. Remove GST-gated products, flag it, suggest fixing GST registration |
| 12 | GSTIN with a bad checksum or typo | Rejected instantly with a "check the number" prompt |
| 13 | Fibre not feasible at the site | Switch to AirFiber. Failover, Static IP and Firewall become unavailable, with the reason |
| 14 | "Only want a mobile plan" | Sell just the Postpaid line (no forced bundle) and note the broadband upgrade for later |
| 15 | Budget cap ("max ₹2,000/month") | Trim optional add-ons to fit, keeping the essentials |
| 16 | Tamil, Marathi or other non-Hindi language | Full conversation in that language |
| 17 | Out-of-catalogue request (DTH TV) or "give me a 50% discount" | Polite refusal. Prices come only from the catalogue |

---

## 4. Segment bundles (templates the advisor starts from)

Built from what activated customers actually bought, adjusted for churn:

| Segment | Bundle name idea | Core | Optional add-ons | Typical price (data) | Contract |
|---|---|---|---|---|---|
| Micro retail & services | **Dukaan Digital** | P01 Fibre 100 (or P04 AirFiber if hotspot or not fibre-feasible) + P07 × 1–2 | P19 POS, P22 Secure Wi-Fi, P23 CCTV × 1–2, P18 Website, P15 WhatsApp (GST only) | median ₹2,470 (p75 ₹2,995) | 12 mo (6 with AirFiber only) |
| Professional offices | **Office Pro** | P02 Fibre 300 (P03 if tier 1, ≥ 5 staff, GST) + P16 × users + P08/P07 lines + P20 × devices | P17 Backup, P09 Failover, P11 Static IP, P12 Cloud telephony, P14 SMS | median ₹6,575 | 12 mo |
| Small multi-site | **Chain Connect** | per site: P01/P02 + P09 + P19 + P23. HQ: P08 lines | P10 SD-WAN (≥ 3 sites), P13 Toll-free, P15 WhatsApp, P22 | median ₹28,080 | 24 mo with SD-WAN |
| Small manufacturers | **Factory Line** | P05/P06 leased line + P08 + P16 + P20 + P21 Firewall | P24 IoT, P11 + P03 (static IP needs fibre), P23, P25 Fleet | median ₹15,910 | 24 mo |

**Churn signals for the business case:**
- In micro, bundles containing P18 Website (38%), P04 AirFiber (33%) and P15 WhatsApp (32%) churn above the 23% base. These need onboarding help ("set up your catalogue with us").
- Low-churn products: P03 Fibre 1G (7%), P21 Firewall (7%), P24 IoT (0%), P20 Endpoint (0% in manufacturers).

---

## 5. Smart KYC spec

### Checks (each returns pass / warn / fail + a plain-language message)

| # | Check | Severity if failed |
|---|---|---|
| 1 | GSTIN format: regex `^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$`, with **mod-36 checksum**. Accept `X` as the 4th PAN character. All 3,534 registry entries pass | Fail |
| 2 | GSTIN registry lookup: exists + status Active (registry has 3,266 Active, 167 Cancelled, 101 Suspended) | Fail if Cancelled or Suspended |
| 3 | GSTIN state code = state of address (true for 100% of the registry) | Fail |
| 4 | Udyam format `UDYAM-XX-00-NNNNNNN` + registry lookup. Note the registry uses `KR` for Karnataka and `TS` for Telangana | Warn if missing (Udyam is optional for some products), fail if invalid |
| 5 | Name match across GST trade name, Udyam enterprise name, electricity bill "billed to" and ID "for business" (fuzzy match) | Fail |
| 6 | Address match between GST principal place of business and the bill's supply address | Fail |
| 7 | Address proof date ≤ 90 days before 2026-07-15 | Fail |
| 8 | Signatory role fits the constitution: Proprietorship → proprietor/owner, LLP → partner, Pvt Ltd → director. "Office admin" can't sign | Warn → request authorisation letter |
| 9 | ID valid-till date ≥ today | Fail |
| 10 | Image quality: blur or rotation detected. Auto-deskew, ask to re-upload if blurred | Warn |
| 11 | Required document missing | Fail |
| 12 | Udyam major activity vs registry | Warn (uncertain whether this is planted) |

### Expected results on the 12 specimen applicants (our self-made answer key)

| App | Expected verdict | Reasons |
|---|---|---|
| K01 | ❌ Reject | GSTIN Cancelled. Udyam number blank (registry has a TS Udyam for this firm, which doesn't match AP). Signatory is an Office admin |
| K02 | ✅ Pass (after deskew) | Rotated scan only |
| K03 | ✅ Pass | — |
| K04 | ⚠️ Re-upload | GST certificate blurred |
| K05 | ⚠️ Incomplete | Udyam missing. "Owner" on an LLP |
| K06 | ❌ Reject | GSTIN checksum fails (`08YKZXS8189L1Z0`, registry `08YKZXS5189L1ZO`) |
| K07 | ❌ Reject | Legal name "Prop. Shri Physio Clinic" doesn't match the trade name or registry ("Neelgiri") |
| K08 | ⚠️ Authorisation needed | Office admin as signatory |
| K09 | ⚠️ Authorisation needed | Office admin as signatory |
| K10 | ⚠️ Warn | "Owner" on an LLP. Activity Services vs registry Trading |
| K11 | ❌ Reject (re-upload bill) | Bill dated 2025-10-31, older than 90 days. "Owner" on a Pvt Ltd |
| K12 | ✅ Pass (activity warn) | Services vs registry Trading |

**Extraction approach:** a vision LLM (Claude) reads each image into strict JSON. Deterministic checks then run on that JSON, with no LLM judgement in pass/fail. Research note: a hackathon team (TrueBill AI) found local OCR too inaccurate on Indian documents and switched to a multimodal LLM. Tesseract stays as an offline fallback.

---

## 6. Screens (mobile-first)

1. **Welcome + language picker:** Hindi, English, Tamil, Marathi, Kannada, … Also "Already an Accel customer? Use your mobile number", which pre-fills the journey.
2. **Advisor chat** (text + mic button). About 5 questions: business type, staff, sites, city, current internet and spend, what you want to do (accept UPI, CCTV, WhatsApp customers…), GSTIN if available.
3. **Recommended bundle card:** each line explained in plain words ("Fibre 100 — so your UPI/POS never drops"). Shows *why*, plus anything blocked and the reason.
4. **Quote:** one big monthly price, toggles for add-ons, a quantity stepper, a 12/24-month contract choice, setup fee, and "vs what you pay today".
5. **Consent screen (DPDP):** what we collect, why, how long we keep it, a withdraw option, and separate opt-in checkboxes for KYC vs marketing.
6. **Smart KYC:** enter GSTIN → instant prefill from the registry → upload or "fetch from DigiLocker" (mocked) → a checklist of results with fixes.
7. **E-sign + pay (mocked) → order placed.**
8. **Tracker:** a timeline (Order placed → KYC verified → Install scheduled → Engineer visit → Active) with the ETA and proactive WhatsApp/SMS-style updates. This answers "where is my order?" before the customer asks.
9. **Back office / partner cockpit:** leads the advisor couldn't close, propensity score + top reasons, "call next" list, assign to partner.
10. **Insights:** results from the given data: funnel, segment economics, drop reasons, churn vs status calls, propensity deciles.

---

## 7. Architecture and stack (recommended)

```
[Phone browser: React (Vite) PWA]
   │  chat / quote / KYC upload / tracker / cockpit
   ▼
[FastAPI backend (Python)]
   ├─ Advisor service ── Claude API (tool calling) ──┐
   │                                                  ▼
   ├─ Eligibility + pricing engine (pure Python, catalogue CSV)
   ├─ Mock GSTIN API / Mock Udyam API (registry CSVs)
   ├─ KYC service ── Claude vision extraction → rule checks
   ├─ Orders + tracker (SQLite)
   ├─ Propensity model (scikit-learn logistic regression, AUC ≈ 0.71)
   └─ Insights (pandas over smb_leads.csv)
Voice: browser Web Speech API (hi-IN etc. in Chrome) → stretch: Sarvam / Bhashini
Privacy: masked IDs in UI and logs, consent log table, doc files deleted after extraction
```

- **Why tool calling:** the LLM calls `get_profile_questions`, `recommend_bundle(profile)`, `validate_bundle(items)` and `price_quote(items)`. Prices and eligibility always come from code, never from the model.
- **Offline fallback:** if the LLM API is down during the live demo, a scripted question flow drives the same engine, so the demo never dies.

---

## 8. "Results from the data" shown inside the prototype (Insights page)

1. Funnel: 5,000 → 3,406 → 1,974 → 861 → 588 → 368, with the 44% quote leak highlighted.
2. Segment economics table: activation, ARPU, churn, CAC, payback (micro 8.1 months vs offices 1.6).
3. Drop reasons grouped into Logistics (39%), Quote/Price, Paperwork, Install.
4. Churn vs status-chase calls (6% → 28%) and NPS (7.5 → 6.0).
5. "Sold vs asked": 54% of customers got none of what they asked for. 56 ineligible bundles were sold.
6. Propensity deciles: top 30% of leads = ~64% of activations.
7. A "what-if" panel: our targets (15% conversion, 7 days, ₹6k CAC, < 0.5 calls, ≤ 10% churn).

---

## 9. Research references
- Guardrail pattern (LLM proposes → rules validate): [Temporal hard-rules cookbook](https://docs.temporal.io/ai/cookbook/guardrails-hard-rules-python) · [Neuro-symbolic guardrails](https://leanpub.com/read/AI-Prolog/llm-logic-guardrails-using-a-neuro-symbolic-pattern) · [LLMs in financial product recommendation](https://letsdatascience.com/news/llms-restructure-financial-product-recommendation-pipelines-f1545c70)
- Document extraction: [TrueBill AI](https://diver202.github.io/trueBillAI.html) · [GST certificate extractor demo (NVIDIA)](https://blackspire-gst-ocr.hf.space/) · [gst-einvoice-mcp](https://pypi.org/project/gst-einvoice-mcp/) · [Arya.ai GST extraction](https://arya.ai/apex-apis/gst-data-extraction-api)
- Indic voice and language: [Sarvam Saarika STT](https://docs.sarvam.ai/api-reference-docs/getting-started/models/saarika) · [IndicTrans2](https://awesome.ecosyste.ms/projects/github.com%2FAI4Bharat%2FIndicTrans2) · [Web Speech API demo (hi-IN)](https://gist.github.com/2braincells2go/2cd1526d6fa9a5ea73e4757f266cc119)
- Tracker UX (timeline, plain-language ETA, proactive exception alerts): [WISMO Labs](https://wismolabs.com/blog/order-tracking-features-list-for-ecommerce-success) · [ShippyPro](https://www.shippypro.com/blog/en/how-to-eliminate-where-is-my-order-emails-in-2026-the-complete-guide-to-automating-80-of-your-support-tickets?hsLang=en)
- Lead scoring (source and status are the top features; validate against closed deals): [Frontiers in AI 2025](https://www.frontiersin.org/journals/artificial-intelligence/articles/10.3389/frai.2025.1554325/full)
