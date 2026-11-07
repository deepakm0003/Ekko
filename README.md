# Ekko — *Ek app. Poora business connected.*

**Team Code Sync · Airtel Sync 2026 (Digital Track) · Case: Project Udyam Digital**

Ekko is an Android app that lets a small-business owner discover the right connectivity bundle, see one clear monthly price, finish KYC from their phone and track activation — in their own language, in one sitting, with no salesperson needed.

> The case uses a fictional operator (Accel Telecom / Accel Business) and synthetic data. Ekko uses its own brand and logo.

---

## Why (what the case data told us)

From `smb_leads.csv` (5,000 leads, Apr–Jun 2026):

| Finding | Number | What Ekko does |
|---|---|---|
| Only 7.4% of leads activate; the steepest drop is quote acceptance | 44% of assessed leads accept the quote | Instant single monthly price with plain-language reasons |
| Customers bought none of what they asked for | 198 of 368 (54%) | Recommends from stated needs |
| Bundles sold that break catalogue rules | 56 (incl. 18 on a **cancelled** GSTIN) | Deterministic eligibility engine under the AI |
| Status chasing drives churn | 1 call → 6% churn, 5 calls → 28% | Live tracker with proactive updates |
| ~39% of drops are visit/contact logistics | "Unreachable", "no time for a visit", … | Self-serve advisor, 24×7 |
| Micro retail pays back in 8.1 months at today's CAC (offices: 1.6) | — | Digital-only for micro; partners for high-value |
| A simple propensity model works | AUC 0.72; top 30% of leads = 65% of activations | Partner cockpit ranks leads to call |

Full analysis: [`RESEARCH_Udyam_Digital.md`](RESEARCH_Udyam_Digital.md) · build spec: [`PROTOTYPE_SPEC.md`](PROTOTYPE_SPEC.md)

---

## Features

| Case requirement | In Ekko |
|---|---|
| **Advisor** (GenAI, regional languages) | Chat + voice (English, Hindi, Tamil, Marathi). Works offline with tap-to-answer chips; when the AI backend is online, free text in any Indian language is understood (Claude). The AI only fills the profile and explains — **prices and eligibility always come from code**. |
| **Quote & checkout** | One monthly price, add-on toggles, quantity steppers, 12/24-month choice with savings, setup fee, GST shown, "vs what you pay today", e-sign + mock UPI. Pricing rules match the data (setup = Σ setup × qty, contract = longest minimum term — true for all 368 activated bundles). |
| **Smart KYC** | Mock GSTIN and Udyam lookup APIs backed by the given registries; **on-device OCR** (ML Kit) with page de-skew, watermark filtering and GSTIN look-alike repair; mock DigiLocker fetch; 12 validation checks (checksum, status, names, address, 90-day bill, signatory role vs constitution, …); DPDP consent screen. |
| **Tracker** | Timeline with ETA from `typical_install_days`, proactive WhatsApp/SMS-style updates, callback request. |
| Stretch: voice | Speech-to-text in the advisor. |
| Stretch: back-office for unclosed leads | Partner cockpit: 4,632 dataset leads + leads the app couldn't close, ranked by propensity with "why call" and a suggested bundle. |
| Stretch: propensity score | Logistic regression trained on the leads, run on-device. |
| Results from the data | Insights screen: funnel, drop reasons, segment economics, churn vs status calls, channels, language gap, propensity deciles, targets. |

### What makes Ekko different

| Feature | Why it matters |
|---|---|
| **Digital Health Score** | Shows the owner how ready their business is today vs with the plan (internet, always-online, payments, customer reach, security, work & data) — value, not just price. |
| **Live rules self-test** | 13 catalogue edge cases plus 1,792 generated profiles run on the phone in seconds, with 0 rule violations. Judges can watch the engine refuse ineligible products. |
| **Pick-your-slot installation** | The owner books the engineer visit in the tracker — scheduling was the #1 reason for status calls. |
| **Share plan on WhatsApp** | Owners decide with family or partners; the plan goes out as plain text in one tap. |
| **Partner code + earnings** | An owner can credit the partner who helped; the partner cockpit shows assisted orders and commission, so digital adds to the field force instead of competing with it. |
| **"Replaces N vendors"** | Makes the one-bill, one-support-number promise concrete for every plan. |

### Smart KYC on the 12 specimen applicants

| Applicant | Ekko's verdict | Why |
|---|---|---|
| K01 | Rejected | GSTIN **cancelled**; Udyam number blank; "Office admin" signatory |
| K02 | Verified | 7° tilted scan straightened; GSTIN 0/O corrected and confirmed |
| K03, K12 | Verified | (K12: activity differs from Udyam — noted) |
| K04 | Re-upload | GST certificate too blurry |
| K05 | Action needed | Udyam missing; "Owner" on an LLP |
| K06 | Rejected | GSTIN fails the GSTN check digit (tampered) |
| K07 | Rejected | Legal name doesn't match GST records |
| K08, K09 | Action needed | "Office admin" is not an authorised signatory |
| K10 | Action needed | "Owner" on an LLP |
| K11 | Action needed | Address proof older than 90 days; "Owner" on a Pvt Ltd |

---

## Prototype scope — what's real and what's simulated

| Real (runs on the phone) | Simulated in this prototype | Production path |
|---|---|---|
| Rules engine & pricing, Smart KYC with on-device OCR, encryption, consent & privacy centre, propensity model, insights | GSTN / Udyam / DigiLocker lookups use the case's mock registries · OTP shown on screen · UPI payment simulated · AI backend built but not deployed (advisor runs offline) | Licensed GSP & DigiLocker APIs, SMS gateway with DLT registration, Razorpay, hosted AI backend (`ekko_backend/`) |

## Security & privacy (DPDP Act 2023)

- **Data minimisation:** document photos are read on the phone and deleted immediately; only verified results are stored; GSTIN/Udyam/ID numbers are masked in UI and logs; the phone number is stored only as a salted hash.
- **Encryption:** SQLCipher database (AES-256); key generated per install and kept in the Android Keystore (`flutter_secure_storage`).
- **Consent:** itemised notice (what / why / how long / rights), separate opt-ins for KYC and marketing, consent log with notice version, withdraw any time.
- **Rights:** Privacy centre to view consents, download all data (JSON) and erase everything (crypto-shred: DB deleted, then its key).
- **App hardening:** screenshots blocked on KYC screens (`FLAG_SECURE`), optional biometric app lock with auto-lock, HTTPS-only network config, no cloud backup, R8 minification, OTP rate limiting and lock-out, append-only audit log.
- **AI safety:** the Anthropic key lives only on the backend; the model never sets prices or eligibility; user text is treated as data (prompt-injection guard); structured outputs; per-IP rate limits.

---

## Repository layout

```
ekko_app/        Flutter app (Android)
  lib/engine/      rules engine, pricing, recommender, KYC validator, OCR parser, propensity model (pure Dart, unit-tested)
  lib/services/    encrypted DB, secure storage, auth, OCR, AI backend client, repository
  lib/screens/     onboarding, login, advisor, plan, consent, KYC, checkout, tracker, partner cockpit, insights, account
  tool/build_assets.py   builds app data (catalogue, registries, model, insights) from the case CSVs
  test/            43 unit tests (advisor scenarios, pricing, all 12 KYC applicants, OCR repair)
ekko_backend/    FastAPI + Claude service (understand / explain / ask)
```

## Run it

**App**
```bash
cd ekko_app
flutter pub get
flutter test
flutter build apk --release --split-per-abi
# optional AI backend:
flutter build apk --release --split-per-abi --dart-define=EKKO_API=https://<your-backend> --dart-define=EKKO_APP_KEY=<key>
```
Install `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` on a phone.

Demo tips: log in with any 10-digit mobile number (the OTP is shown on screen). In KYC, use **Demo: load a specimen applicant** for K01–K12. A pincode ending in **0** shows the "no fibre → 5G AirFiber" path. Partner cockpit credentials are in `lib/config/demo_seed.dart`.

**Backend** (optional — the app works fully offline without it)
```bash
cd ekko_backend
pip install -r requirements.txt
ANTHROPIC_API_KEY=... EKKO_APP_KEY=... uvicorn app:app --port 8000
```
Deploys to Render via `render.yaml`.

**Rebuild data assets** (needs the case data pack, not included in this repo)
```bash
python tool/build_assets.py ../YTL_TrackA_Udyam_Digital_Data assets/data
```
