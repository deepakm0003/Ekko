"""Generate Ekko's architecture diagrams as SVG (rendered to PNG by render.js).

Usage: python make_diagrams.py <out_dir>
"""
import os
import sys
from xml.sax.saxutils import escape

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
FONT = "Segoe UI, Arial, sans-serif"
RED, RED_D, RED_S = "#E40000", "#A30000", "#FFEEEE"
INK, INK2, MUTED, LINE = "#111318", "#4A4F57", "#8A9099", "#DCDFE4"
CANVAS, WHITE = "#F5F6F8", "#FFFFFF"
GREEN, GREEN_S, AMBER, AMBER_S, BLUE, BLUE_S = "#14804A", "#E6F6ED", "#A35F00", "#FFF3DF", "#2456D8", "#EAF0FF"


class Svg:
    def __init__(self, w, h):
        self.w, self.h, self.parts = w, h, []

    def add(self, s):
        self.parts.append(s)

    def rect(self, x, y, w, h, fill=WHITE, stroke=LINE, r=14, sw=1.5, dash=None, shadow=False):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        f = ' filter="url(#sh)"' if shadow else ""
        self.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}{f}/>')

    def text(self, x, y, s, size=16, weight=500, color=INK, anchor="start", italic=False):
        st = ' font-style="italic"' if italic else ""
        self.add(f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" '
                 f'fill="{color}" text-anchor="{anchor}"{st}>{escape(s)}</text>')

    def lines(self, x, y, rows, size=14, color=INK2, lh=1.35, weight=500):
        for i, r in enumerate(rows):
            self.text(x, y + i * size * lh, r, size, weight, color)

    def arrow(self, x1, y1, x2, y2, color=INK2, sw=2.2, dash=None, both=False, label=None, lx=None, ly=None):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        mk = f' marker-end="url(#ah{color[1:]})"' + (f' marker-start="url(#as{color[1:]})"' if both else "")
        self.add(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{sw}"{d}{mk}/>')
        if label:
            self.text(lx if lx is not None else (x1 + x2) / 2, ly if ly is not None else (y1 + y2) / 2 - 8,
                      label, 13, 600, color, "middle")

    def path(self, d, color=INK2, sw=2.2, dash=None):
        ds = f' stroke-dasharray="{dash}"' if dash else ""
        self.add(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{sw}"{ds} marker-end="url(#ah{color[1:]})"/>')

    def chip(self, x, y, label, fill=WHITE, color=INK, stroke=LINE, w=None, size=14, weight=600):
        w = w or (len(label) * size * 0.58 + 26)
        self.rect(x, y, w, size + 18, fill, stroke, r=(size + 18) / 2, sw=1.2)
        self.text(x + w / 2, y + size + 4, label, size, weight, color, "middle")
        return w

    def save(self, name):
        markers = ""
        for c in {RED, INK2, GREEN, AMBER, BLUE, MUTED}:
            k = c[1:]
            markers += (f'<marker id="ah{k}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto">'
                        f'<path d="M0,0 L10,5 L0,10 z" fill="{c}"/></marker>'
                        f'<marker id="as{k}" viewBox="0 0 10 10" refX="1" refY="5" markerWidth="7" markerHeight="7" orient="auto">'
                        f'<path d="M10,0 L0,5 L10,10 z" fill="{c}"/></marker>')
        head = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}">'
                f'<defs>{markers}<filter id="sh" x="-5%" y="-5%" width="110%" height="120%">'
                f'<feDropShadow dx="0" dy="4" stdDeviation="6" flood-color="#0F1115" flood-opacity="0.10"/></filter></defs>'
                f'<rect width="100%" height="100%" fill="{WHITE}"/>')
        with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
            f.write(head + "".join(self.parts) + "</svg>")
        print("wrote", name)


# ---------------------------------------------------------------- 1. System architecture
def architecture():
    s = Svg(2000, 1000)
    s.text(40, 52, "Ekko — system architecture", 30, 800)
    s.text(40, 84, "Offline-first Android app · deterministic rules engine · AI only for language · privacy by design", 17, 500, INK2)

    # Left: build-time data pipeline
    s.rect(30, 120, 330, 820, CANVAS, LINE, 20)
    s.text(52, 156, "BUILD-TIME DATA PIPELINE", 14, 800, RED)
    s.rect(52, 178, 286, 210, WHITE, LINE, 14, shadow=True)
    s.text(70, 208, "Case data pack", 17, 700)
    s.lines(70, 234, ["product_catalogue.csv · 25", "smb_leads.csv · 5,000", "mock GSTIN registry · 3,534",
                      "mock Udyam registry · 2,723", "KYC specimens · 47 images"], 14)
    s.arrow(195, 392, 195, 438, INK2)
    s.rect(52, 442, 286, 150, WHITE, LINE, 14, shadow=True)
    s.text(70, 472, "tool/build_assets.py", 17, 700)
    s.lines(70, 498, ["pandas · scikit-learn", "trains propensity model", "(logistic regression, AUC 0.72)", "precomputes insights"], 14)
    s.arrow(195, 596, 195, 642, INK2)
    s.rect(52, 646, 286, 200, WHITE, RED, 14, shadow=True)
    s.text(70, 676, "Bundled app assets", 17, 700, RED_D)
    s.lines(70, 702, ["catalogue.json", "gstin / udyam registries", "propensity_model.json", "insights.json · cockpit leads",
                      "specimen KYC images", "→ loaded at app start"], 14)
    s.arrow(340, 745, 398, 745, RED)
    s.text(52, 900, "Re-run when the catalogue", 13, 500, MUTED)
    s.text(52, 920, "or registries change.", 13, 500, MUTED)

    # Centre: the app
    X, W = 400, 1080
    s.rect(X, 120, W, 820, WHITE, RED, 22, 2.2, shadow=True)
    s.text(X + 24, 158, "EKKO ANDROID APP  ·  Flutter 3.35 · Dart · runs fully offline", 15, 800, RED)

    def layer(y, h, title, tag, chips, fill=CANVAS, stroke=LINE, chip_fill=WHITE, chip_color=INK, chip_stroke=LINE):
        s.rect(X + 20, y, W - 40, h, fill, stroke, 16)
        s.text(X + 40, y + 30, title, 16, 800)
        s.text(X + W - 40, y + 30, tag, 13, 600, MUTED, "end")
        cx, cy = X + 40, y + 46
        for c in chips:
            w = len(c) * 14 * 0.58 + 26
            if cx + w > X + W - 40:
                cx, cy = X + 40, cy + 42
            s.chip(cx, cy, c, chip_fill, chip_color, chip_stroke, w)
            cx += w + 10

    layer(178, 132, "Presentation", "white/red design system · 4 languages",
          ["Onboarding", "Advisor chat + voice", "Plan & quote", "DPDP consent", "Smart KYC", "Sign & pay",
           "Live tracker", "Partner cockpit", "Insights", "Privacy centre", "Rules self-test"])
    s.arrow(X + W / 2, 312, X + W / 2, 330, MUTED, 1.6)
    layer(332, 84, "App state", "Provider · ChangeNotifier",
          ["AppState: session · language · journey (profile → bundle → quote → KYC)"])
    s.arrow(X + W / 2, 418, X + W / 2, 436, MUTED, 1.6)
    layer(438, 176, "Domain engines — pure Dart, deterministic, unit-tested (46 tests)", "the AI never decides these",
          ["Recommender", "Eligibility rules", "Pricing", "Digital Health Score", "KYC validator (12 checks)",
           "Doc parser: de-skew · watermark filter", "GSTIN check digit + OCR repair", "Propensity scorer", "Self-test runner",
           "Bundle repair loop: substitute · auto-add · block", "Quote: setup = Σ setup×qty · contract = max term"],
          fill=RED_S, stroke="#F5B5B5", chip_stroke="#F2B0B0")
    s.arrow(X + W / 2, 616, X + W / 2, 634, MUTED, 1.6)
    layer(636, 132, "Services", "fail-soft · audited",
          ["Auth: OTP · lock-out · salted phone hash", "Repository (orders · leads · consents)", "ML Kit OCR (on-device)",
           "AI client (12 s timeout → offline)", "Secure window (no screenshots)", "Audit log"])
    s.arrow(X + W / 2, 770, X + W / 2, 788, MUTED, 1.6)
    layer(790, 132, "Storage & device security", "nothing leaves the phone by default",
          ["SQLCipher DB · AES-256", "Key in Android Keystore", "Photos deleted after reading", "Masked IDs",
           "No cloud backup", "HTTPS-only", "Biometric app lock", "Skia renderer"],
          fill=GREEN_S, stroke="#BFE5CF", chip_stroke="#BFE5CF", chip_color=GREEN)

    # Right: cloud & integrations
    RX = 1530
    s.rect(RX, 120, 440, 820, CANVAS, LINE, 20)
    s.text(RX + 22, 156, "CLOUD & INTEGRATIONS", 14, 800, RED)
    s.rect(RX + 22, 178, 396, 316, WHITE, BLUE, 14, 2, shadow=True)
    s.text(RX + 42, 210, "Ekko API (backend)", 18, 800, BLUE)
    s.text(RX + 42, 234, "FastAPI · SQLAlchemy · JWT · Docker", 14, 600, INK2)
    s.lines(RX + 42, 262, ["26 endpoints · OpenAPI docs · 54 tests",
                           "auth: OTP (hashed, lock-out) · partner role",
                           "re-runs rules & re-prices every order",
                           "server-side KYC re-check (12 checks)",
                           "orders · live tracking · slot booking",
                           "partner leads (ranked) · earnings",
                           "DPDP: consent · export · erase · audit",
                           "advisor: rule parser, Groq LLM fallback",
                           "rate limits · security headers · masked logs"], 14, lh=1.42)
    s.arrow(RX + 140, 498, RX + 140, 528, BLUE)
    s.arrow(RX + 300, 498, RX + 300, 528, BLUE)
    s.rect(RX + 22, 532, 190, 74, WHITE, BLUE, 12, 1.6, shadow=True)
    s.text(RX + 36, 560, "Postgres / SQLite", 15, 800, BLUE)
    s.text(RX + 36, 584, "users · orders · audit", 12.5, 500, INK2)
    s.rect(RX + 228, 532, 190, 74, WHITE, BLUE, 12, 1.6, dash="6 4")
    s.text(RX + 242, 560, "Groq LLM (optional)", 15, 800, BLUE)
    s.text(RX + 242, 584, "language only, fail-soft", 12.5, 500, INK2)

    s.text(RX + 22, 636, "Production integrations", 15, 800, INK)
    for i, (t, sub) in enumerate([("GSTN / Udyam via GSP", "replaces mock registries"),
                                  ("DigiLocker / Entity Locker", "consent-based document fetch"),
                                  ("SMS gateway (DLT)", "real OTP + order updates"),
                                  ("Razorpay UPI", "real setup-fee payment")]):
        y = 652 + i * 68
        s.rect(RX + 22, y, 396, 58, WHITE, AMBER, 12, 1.6, dash="7 5")
        s.text(RX + 42, y + 25, t, 15, 700, INK)
        s.text(RX + 42, y + 46, sub, 13, 500, MUTED)

    # app <-> cloud arrows
    s.arrow(X + W + 2, 300, RX + 18, 300, BLUE, both=True)
    s.arrow(X + W + 2, 730, RX + 18, 730, AMBER, dash="7 5", both=True)

    # legend
    s.rect(400, 952, 1570, 36, WHITE, WHITE, 8)
    s.add(f'<line x1="410" y1="970" x2="450" y2="970" stroke="{BLUE}" stroke-width="2.4"/>')
    s.text(460, 975, "built & working", 14, 600, INK2)
    s.add(f'<line x1="620" y1="970" x2="660" y2="970" stroke="{AMBER}" stroke-width="2.4" stroke-dasharray="7 5"/>')
    s.text(670, 975, "production integration (simulated in prototype)", 14, 600, INK2)
    s.rect(1050, 960, 22, 20, RED_S, "#F5B5B5", 5)
    s.text(1080, 975, "deterministic rules (never the AI)", 14, 600, INK2)
    s.rect(1360, 960, 22, 20, GREEN_S, "#BFE5CF", 5)
    s.text(1390, 975, "privacy & security controls", 14, 600, INK2)
    s.save("architecture.svg")


# ---------------------------------------------------------------- 2. Advisor request flow (guardrail)
def advisor_flow():
    s = Svg(2000, 760)
    s.text(40, 52, "Advisor request flow — AI understands, rules decide", 30, 800)
    s.text(40, 84, "A plan can never contain an ineligible product or an invented price", 17, 500, INK2)
    cols = [("Owner", 170), ("Advisor UI", 470), ("On-device parser", 770), ("Backend → Groq LLM", 1080),
            ("Rules engine", 1390), ("Pricing & Health", 1720)]
    for name, x in cols:
        s.rect(x - 120, 112, 240, 52, INK if name == "Owner" else (BLUE if "Groq" in name else (RED if "Rules" in name else WHITE)),
               INK if name == "Owner" else LINE, 12)
        dark = name in ("Owner",) or "Groq" in name or "Rules" in name
        s.text(x, 145, name, 17, 800, WHITE if dark else INK, "middle")
        s.add(f'<line x1="{x}" y1="166" x2="{x}" y2="720" stroke="{LINE}" stroke-width="2" stroke-dasharray="4 6"/>')

    def msg(y, a, b, label, color=INK2, dash=None):
        xa, xb = dict(cols)[a], dict(cols)[b]
        s.arrow(xa + (8 if xb > xa else -8), y, xb - (8 if xb > xa else -8), y, color, 2.2, dash, label=label, lx=(xa + xb) / 2, ly=y - 10)

    msg(212, "Owner", "Advisor UI", "taps a chip, types or speaks (Hindi / Tamil / Marathi / English)")
    msg(262, "Advisor UI", "On-device parser", "understand answer")
    s.rect(610, 282, 320, 60, GREEN_S, "#BFE5CF", 10)
    s.text(770, 306, "numbers, cities, business types,", 13, 600, GREEN, "middle")
    s.text(770, 326, "GSTIN regex, Devanagari digits", 13, 600, GREEN, "middle")
    msg(372, "On-device parser", "Backend → Groq LLM", "not understood → free text", BLUE)
    msg(412, "Backend → Groq LLM", "On-device parser", "profile fields as strict JSON (or null → offline chips)", BLUE, "6 5")
    msg(462, "Advisor UI", "Rules engine", "BusinessProfile: segment, size, sites, tier, GST status, needs, pincode", RED)
    s.rect(1240, 482, 300, 108, RED_S, "#F5B5B5", 10)
    s.lines(1260, 506, ["tier · active GSTIN · min staff", "min sites · dependencies", "fibre feasibility · budget",
                        "→ substitute, auto-add or block"], 13, RED_D, weight=600)
    msg(612, "Rules engine", "Pricing & Health", "validated bundle", RED)
    s.rect(1760, 590, 230, 68, WHITE, LINE, 10)
    s.lines(1774, 614, ["setup = Σ setup × qty", "contract = longest minimum term"], 13, INK2, weight=600)
    msg(690, "Pricing & Health", "Advisor UI", "one monthly price · health score · reasons · notices")
    s.text(40, 744, "Optional: the validated plan goes back to the AI only to be explained in the owner's language — it cannot change items or prices.",
           14, 600, MUTED)
    s.save("advisor_flow.svg")


# ---------------------------------------------------------------- 3. Smart KYC pipeline
def kyc_pipeline():
    s = Svg(2000, 640)
    s.text(40, 52, "Smart KYC pipeline — on-device, verifiable, privacy-first", 30, 800)
    s.text(40, 84, "Photos are read on the phone and deleted; only masked, verified results are stored", 17, 500, INK2)
    steps = [
        ("1  Capture", ["camera / gallery /", "DigiLocker (mock) /", "specimen K01–K12"], WHITE, LINE, INK),
        ("2  On-device OCR", ["Google ML Kit", "text lines + corner", "points, no upload"], WHITE, LINE, INK),
        ("3  Parse", ["de-skew by label angle", "drop watermark lines", "recover clipped labels"], WHITE, LINE, INK),
        ("4  Repair IDs", ["GSTIN letter/digit", "positions, check digit,", "registry-confirmed only"], WHITE, LINE, INK),
        ("5  Validate", ["12 checks vs GSTN &", "Udyam registries,", "dates, names, roles"], RED_S, "#F5B5B5", RED_D),
        ("6  Verdict", ["Verified / Action /", "Rejected + fix steps", "for the owner"], WHITE, LINE, INK),
    ]
    x0, w, gap = 40, 272, 54
    for i, (t, rows, fill, stroke, color) in enumerate(steps):
        x = x0 + i * (w + gap)
        s.rect(x, 130, w, 190, fill, stroke, 16, 1.8, shadow=True)
        s.text(x + 20, 168, t, 19, 800, color)
        s.lines(x + 20, 204, rows, 15, INK2, 1.5)
        if i < len(steps) - 1:
            s.arrow(x + w + 4, 225, x + w + gap - 6, 225, RED)
    s.arrow(x0 + 2 * (w + gap) - gap / 2 - 10, 330, x0 + 2 * (w + gap) - gap / 2 - 10, 372, GREEN)
    s.rect(300, 376, 620, 54, GREEN_S, "#BFE5CF", 12)
    s.text(610, 410, "photo file deleted immediately after OCR · screenshots blocked", 15, 700, GREEN, "middle")

    s.text(40, 478, "What the checks catch on the case specimens", 18, 800)
    cases = [("K01", "GSTIN cancelled · Udyam blank", RED_D, RED_S), ("K02", "tilted 7°, 0/O fixed → verified", GREEN, GREEN_S),
             ("K04", "blurred → re-upload", AMBER, AMBER_S), ("K06", "check digit fails → tampered", RED_D, RED_S),
             ("K07", "legal name ≠ registry", RED_D, RED_S), ("K08/K09", "office admin can't sign", AMBER, AMBER_S),
             ("K11", "bill older than 90 days", AMBER, AMBER_S), ("K03/K12", "clean → verified", GREEN, GREEN_S)]
    for i, (k, t, c, bg) in enumerate(cases):
        col, row = i % 4, i // 4
        x, y = 40 + col * 485, 500 + row * 62
        s.rect(x, y, 470, 50, bg, bg, 12)
        s.text(x + 18, y + 32, k, 16, 800, c)
        s.text(x + 110, y + 32, t, 15, 600, INK)
    s.save("kyc_pipeline.svg")


architecture()
advisor_flow()
kyc_pipeline()
