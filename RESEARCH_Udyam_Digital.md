# Project Udyam Digital — Research Notes (Team Code Sync)

Prepared 7 Nov 2026. Round 1 deadline: **8 Nov 2026, 11:59 PM IST**.
Sources: the case PDF, README, all 5 data files (every row analysed with pandas), all 47 KYC images, and public web research.

---

## 1. What the judges are actually scoring

- They assess **technical depth and business judgement together**, so the prototype and the business case carry equal weight.
- Judges hold a secret pack containing:
  - **15 advisor test scenarios**, which they will run *live* in the demo. The advisor must obey every catalogue rule.
  - The **KYC answer key**. Our Smart KYC must catch the planted document problems.
  - The **signals planted in the leads data**. Our business case should "discover" them (section 2).
- The case uses the fictional names **Accel Telecom / Accel Business**, and all our material should use them too, not "Airtel".
- They ask for five answers: segment priority + bundles, salesperson-free discovery, near-instant DPDP-compliant KYC, the role of field force and partners, and 3–5 metrics with targets.

---

## 2. Hidden signals in the data (our "discoveries")

| # | Finding | Evidence | What it means for our solution |
|---|---|---|---|
| 1 | **Most of the funnel loss is human logistics, not lack of interest** | Top drops: Unreachable after 3 attempts (805), Owner had no time for a visit (531), Wrong number (319), Visit not scheduled by sales (296), so ~39% of all drops are scheduling/contact failures | A self-serve advisor that works 24×7 on the owner's phone removes the visit entirely |
| 2 | **Sales sells what's on target, not what the customer asked for** | **198 of 368 (54%)** activated customers bought *none* of the products they asked about | The advisor recommends from the customer's stated needs and explains why |
| 3 | **Ineligible bundles are being sold, a compliance leak** | **56 activated leads (15%)** got bundles that break catalogue rules (24 tier, 22 GSTIN, 9 dependency, 8 employee-size). **18 activations had a *Cancelled* GSTIN, 4 Suspended** | A rules engine sits under the LLM, so the GenAI can never recommend an ineligible product |
| 4 | **The quote is the biggest leak** | Needs assessed → Quote accepted is only 44%. Price too high (414), Competitor cheaper (207), **Quote too complex (206)**, Quote too slow (179) | Show an instant single monthly price with toggles and plain-language lines instead of product codes |
| 5 | **Status chasing predicts churn** | Churn by follow-up calls: 1 call **6%** → 3 calls 12% → 5 calls **28%**. NPS falls 7.5 → 6.0 | The tracker drives retention as well as cutting support cost |
| 6 | **GSTIN is the biggest conversion lever** | GST+Udyam 10.7%, GST only 7.9%, Udyam only 2.8%, neither **1.4%**. 47% of micro leads have no GSTIN, and **41% of no-GSTIN leads asked for a GSTIN-only product** (WhatsApp API, SMS) | Build a no-GSTIN path: a starter bundle without GST-gated products + help to register GST, unlocking the upgrade later |
| 7 | **The micro segment loses money today** | Micro: CAC ₹20,007 vs ARPU ₹2,470, so **8.1-month payback** with 22.7% churn in 6 months. Professional offices: 1.6 months, manufacturers: 1.0, multi-site: 0.6 | Micro must be fully digital (CAC ~₹4–6k), and humans are reserved for high-value segments |
| 8 | **Field sales is the most expensive channel** | CAC by source: Field ₹24,335, Partner ₹20,851, Website ₹6,352, Inbound ₹5,113, WhatsApp ₹4,026, Referral ₹4,099 | Move micro and professional offices to digital, and point field sales at multi-site/manufacturers |
| 9 | **Digital channels exist but don't close** | Website form 4.3%, WhatsApp campaign **2.8%** activation. 449 of 995 website leads and 210 of 358 WhatsApp leads were never even contacted | The problem is that no one follows up. An advisor that closes in-session fixes this |
| 10 | **Language gap** | Activation: Hindi 7.9%, English 8.0%, but Tamil 4.3%, Punjabi 4.2%, Kannada 5.1%, Gujarati 6.0%. Hindi + English = only 66% of leads | Run the vernacular advisor in at least Hindi, Tamil, Marathi, Kannada |
| 11 | **Hotspot users are underserved by the wrong product** | 1,799 leads use a mobile hotspot (4.5% activation), but only **9 bundles** ever included P04 5G AirFiber (2-day install, no fibre needed). 41 drops were "Site not feasible for fibre" | Make AirFiber the hero product for micro, with an automatic fallback when fibre isn't feasible |
| 12 | **There is a warm base already** | 1,505 leads (30%) are "Accel (mobile only)" customers, at 9.2% activation vs Local ISP 5.4% | Start a pre-filled journey from the existing Accel app/SIM |
| 13 | **280 drops "Only wanted a mobile plan"** | — | Land-and-expand: sell the mobile line now, then the advisor nudges toward broadband later |
| 14 | **A propensity score works** | A simple logistic regression gives **AUC 0.71**. The top 3 deciles activate at 12–19% vs 1–3% for the bottom half, so calling the top 30% captures ~64% of activations | Feed this into the partner/back-office "who to call" list |
| 15 | **Referral converts best but churns most** | Referral: 14.8% activation, ₹4.1k CAC, but **24.6% churn** | A referral programme needs a fit check (the advisor) to keep churn down |
| 16 | **Install delays hurt manufacturers** | "Installation delayed beyond 21 days" is 5.2% of manufacturer drops (leased lines take 21–30 days) | The tracker shows an honest ETA from `typical_install_days` and gives temporary AirFiber while the leased line is built |

**Funnel timing:** contact 2.0 d → assess 3.0 d → quote 4.1 d → KYC 3.7 d → activate 4.8 d (17.6 days total). Our journey collapses the first four steps (~13 days) into one sitting.

**Segment economics (activated customers):**

| Segment | Leads | Activation | Median ARPU | 6-mo churn | CAC | Payback |
|---|---|---|---|---|---|---|
| Micro retail & services | 2,709 | 4.1% | ₹2,470 | 22.7% | ₹20,007 | 8.1 mo |
| Professional offices | 1,247 | 11.1% | ₹6,575 | 13.8% | ₹10,695 | 1.6 mo |
| Small multi-site | 755 | 11.0% | ₹28,080 | 10.8% | ₹15,614 | 0.6 mo |
| Small manufacturers | 289 | 12.8% | ₹15,910 | 8.1% | ₹15,324 | 1.0 mo |

**What actually sells today** (top bundles): Fibre 100 + Postpaid (P01+P07), plus POS (P19), CCTV (P23) or Wi-Fi (P22) for micro; Fibre 300 + Postpaid + Cloud Email + Backup (P02+P07+P16+P17) for offices.
**What people ask for:** Postpaid 838, WhatsApp API 827, Secure Wi-Fi 814, SMS 813, CCTV 787, Website 748, AirFiber 719.

---

## 3. Planted KYC problems (from the 47 images vs the registries)

"Today" = 2026-07-15, and an address proof must be ≤ 90 days old.

| Applicant | Problem our Smart KYC must catch |
|---|---|
| K01 | GSTIN is **Cancelled** in the registry. Udyam number **blank**. Signatory is an "Office admin" |
| K02 | GST certificate is **rotated/skewed**, so the image needs deskewing (data is valid) |
| K03 | Clean ✅ |
| K04 | GST certificate is **blurred**, so prompt a re-upload |
| K05 | **Udyam certificate missing**. "Owner" designation on an LLP |
| K06 | GSTIN **fails the checksum** (`…8189L1Z0` vs registry `…5189L1ZO`) |
| K07 | Legal name says "Prop. **Shri** Physio Clinic", which doesn't match the trade name or registry |
| K08, K09 | Signatory is an "Office admin", not authorised |
| K10 | "Owner" on an LLP (should be a Partner) |
| K11 | Address proof dated **2025-10-31, older than 90 days**. "Owner" on a Pvt Ltd |
| K12 | Clean ✅ |
| (possible) | The Udyam "major activity" says Services but the registry says Trading on K06, K10, K11, K12. Unclear whether this is planted, so flag it as a warning, not a reject |

**Validation checks to build:** GSTIN format + checksum (accept `X` as the 4th char), registry lookup + status, GST↔Udyam↔bill name match, address match, bill age, signatory role vs constitution, missing documents, blur/rotation quality.

---

## 4. Public projects and competitors — what to borrow

| Who / what | What they do | What we take |
|---|---|---|
| **Airtel Business digital platform** (real) | SMBs pick a plan → check feasibility → order in 3 steps. Airtel claims it cuts ordering/deployment time by up to 70% | Instant **feasibility check** by pincode in our journey. Our edge is bundles, KYC and a tracker, beyond single products |
| **JioBusiness** | Bundled broadband + voice + cloud storage at ₹801 / ₹1,001 a month | The **price anchor** behind the "Competitor cheaper" drops (207). We must show value per rupee and the savings vs current spend |
| **Tata Tele Business Services** | Positions itself as 100% SMB-focused (Smartflo cloud telephony), with a demo-led sales path | Proof that SMB voice/cloud is contested. Their onboarding is still demo-led, which is our gap to exploit |
| **Vodafone V-Hub** (UK/EU) | Free digital-advice hub + human advisers, open to non-customers; reported to have upskilled 1M+ UK SMBs | Make the advisor useful **before** purchase with a "digital health check" of the business, which builds trust |
| **O2 Digital SMB** (UK) | Self-serve SMB sales on CPQ tooling, keeping human "Gurus" for advice | The **hybrid model**: digital first, with a one-tap human handoff (answers Q4) |
| **Razorpay onboarding** | GSTIN verification **auto-fills** business details. "I don't have a GSTIN" checkbox. CKYC lets businesses activate in minutes | **GSTIN-first KYC**: type the GSTIN and everything prefills. Add an explicit no-GSTIN path |
| **DigiLocker / Entity Locker** | Udyam certificates on DigiLocker are legally equal to physical ones. Entity Locker lets businesses share documents with consent | A consent-based **fetch** instead of upload removes OCR errors entirely (mocked in the prototype) |
| **HyperVerge / Signzy KYB APIs** | GSTIN verification, Udyam verification, KYB document OCR | The production path for our mocked APIs. Put it in the architecture slide |
| **TrueBill AI** (hackathon project) | Uses Gemini multimodal for invoice OCR + GSTIN validation. They found local OCR too inaccurate | Use a **multimodal LLM for extraction**, then deterministic validation rules on top |
| **Sarvam AI / Bhashini** | Indic speech-to-text, text-to-speech and translation (22 languages). Voice agents on WhatsApp and phone | The vernacular voice stretch goal. Name it in the architecture |
| **Gupshup on WhatsApp** | Delivery-partner onboarding with KYC + 1-click payment inside WhatsApp | The **WhatsApp front end** stretch goal: owners already live in WhatsApp |
| **DPDP Rules 2025** | Notified 13 Nov 2025. Core obligations phase in over 18 months (~May 2027). Consent records, erasure with 48 h notice, logs ≥ 1 year | Privacy note: a purpose-specific consent screen, masked IDs, documents deleted after verification, retention schedule |
| **Telco self-serve case studies** (vendor-published, treat with caution) | E.g. a US telco reported +161% online conversion with live chat. Etisalat reported 3× with next-best-offer | Supports the conversion-uplift assumptions in the business case |

---

## 5. Candidate "one thing" (our core idea) — to decide together

**Gap in the market:** Every competitor sells **one product online** (Airtel Business, Jio). Nobody offers **advice → bundle → KYC → activation in one sitting, in the owner's language**, and the data shows the losses come from human handoffs, wrong products and status chasing.

**Recommended pitch:** *"A 10-minute digital co-pilot that never sells the wrong bundle."*
1. **Vernacular GenAI advisor** whose recommendations pass through a **deterministic eligibility engine** (tier, size, GSTIN status, dependencies). This passes the judges' 15 live tests and fixes the 15% ineligible-sales leak.
2. **One price, plain language.** A toggleable quote that compares against current telecom spend. Hotspot users → AirFiber hero bundle.
3. **GSTIN-first Smart KYC.** Lookup prefills everything, multimodal OCR cross-checks documents, and the consent screen is DPDP-native. A no-GSTIN path offers a starter bundle + help to register.
4. **Live tracker** with ETAs from `typical_install_days`. This kills status calls, which is our churn lever (6% → 28%).
5. **Partner cockpit.** Leads the advisor couldn't close, ranked by propensity score (AUC 0.71). Partners earn on assisted closes, so digital *feeds* them instead of competing with them.

**Segment priority:**
- **Wave 1:** Professional offices (best CAC, 1.6-month payback, clear needs).
- **Wave 1 digital-only:** Micro (only economical at digital CAC).
- **Assisted:** Multi-site and manufacturers (highest ARPU; the advisor qualifies them, then field sales closes).

**Draft metric targets (to refine):**

| Metric | Today | Target |
|---|---|---|
| Lead → activation | 7.4% | 15% |
| Lead → activation time | 17.6 days | ≤ 7 days (≤ 2 for AirFiber) |
| Blended CAC | ₹15,000 | ≤ ₹6,000 |
| Status calls per customer | 3 | < 0.5 |
| 6-month churn | 15.2% | ≤ 10% |

---

### Sources
- [Airtel Business digital platform (Inc42)](https://inc42.com/buzz/airtel-business-smbs-internet) · [Voice&Data](https://www.voicendata.com/airtel-business-launches-digital-platform-for-emerging-smes-startups)
- [Jio business broadband + cloud (pc-tablet)](https://pc-tablet.com/?p=72921) · [JioBusiness for MSMEs (Voice&Data)](https://www.voicendata.com/jiobusiness-deal-half-msmes-across-country)
- [TTBS Smartflo launch (UNI)](https://www.uniindia.com/tata-tele-business-services-launches-smartflo/business-economy/news/2295437.html) · [TTBS relaunch for SMEs](https://techobserver.in/2021/05/25/tata-teleservices-relaunched-as-tata-tele-business-services-to-cater-to-smes/)
- [Vodafone V-Hub](https://www.vodafone.co.uk/business/sme-business/about-v-hub) · [O2 Digital SMB (CloudSense)](https://www.cloudsense.com/customer/o2-telefonica)
- [Razorpay KYC docs](https://razorpay.com/docs/partners/technology-partners/kyc/) · [Razorpay sign-up](https://razorpay.com/docs/payments/sign-up)
- [Udyam on DigiLocker](https://blog.digilocker.gov.in/udyam-certificate-introducing-the-new-service-of-digilocker/) · [Entity Locker (NeGD)](https://negd.gov.in/our_projects/entity-locker/)
- [HyperVerge GSTN verification](https://hyperverge.co/in/integrations-marketplace/gstn-verification-api/) · [HyperVerge Udyam verification](https://hyperverge.co/in/integrations-marketplace/udyam-aadhaar-verification-api/)
- [TrueBill AI hackathon project](https://diver202.github.io/trueBillAI.html) · [Telecom upselling system (GitHub)](https://awesome.ecosyste.ms/projects/github.com%2Ffadel-hasan%2Ftelecom-upselling-system)
- [Sarvam AI docs](https://docs.sarvam.ai/api-reference-docs/introduction.md) · [Sarvam voice agents (TechCrunch)](https://techcrunch.com/2024/08/13/why-this-ai-startup-is-betting-on-voice-enabled-bots-to-scale-ai-adoption-in-india)
- [Gupshup WhatsApp onboarding case](https://www.casestudies.com/company/gupshup/case-study/gupshup-helped-a-global-restaurant-aggregator-and-food-delivery-company-improve-its-executive-onboarding-process)
- [DPDP Rules 2025 (EY)](https://www.ey.com/en_in/insights/cybersecurity/transforming-data-privacy-digital-personal-data-protection-rules-2025) · [JSA Prism Nov 2025](https://www.jsalaw.com/?p=55573) · [Rule 8 erasure](https://dpdpa.com/dpdparules/rule8.html)
- [Telco conversion case studies (casestudies.com)](https://www.casestudies.com/company/giosg/case-study/how-a-usa-telecommunications-multinational-increased-their-online-conversion-rate-by-161-and-achieved-4x-higher-roi)
