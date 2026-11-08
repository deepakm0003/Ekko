"""GSTIN / Udyam identifiers, mock government registries, and the Smart KYC validator.

Port of ekko_app/lib/engine/{identifiers,registry,kyc}.dart. OCR runs on the phone;
the server re-checks the extracted fields so a tampered client can't fake a pass.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass
from datetime import date
from pathlib import Path

_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
_GSTIN = re.compile(r"^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$")
_UDYAM = re.compile(r"^UDYAM-[A-Z]{2}-\d{2}-\d{7}$")
STATE_CODES = {
    "01": "Jammu and Kashmir", "02": "Himachal Pradesh", "03": "Punjab", "04": "Chandigarh", "05": "Uttarakhand",
    "06": "Haryana", "07": "Delhi", "08": "Rajasthan", "09": "Uttar Pradesh", "10": "Bihar", "11": "Sikkim",
    "12": "Arunachal Pradesh", "13": "Nagaland", "14": "Manipur", "15": "Mizoram", "16": "Tripura", "17": "Meghalaya",
    "18": "Assam", "19": "West Bengal", "20": "Jharkhand", "21": "Odisha", "22": "Chhattisgarh",
    "23": "Madhya Pradesh", "24": "Gujarat", "26": "Dadra and Nagar Haveli and Daman and Diu", "27": "Maharashtra",
    "29": "Karnataka", "30": "Goa", "32": "Kerala", "33": "Tamil Nadu", "34": "Puducherry", "36": "Telangana",
    "37": "Andhra Pradesh",
}


# ---------------------------------------------------------------- GSTIN
def gstin_normalise(raw: str) -> str:
    return re.sub(r"[^0-9A-Z]", "", raw.upper())


def gstin_check_digit(first14: str) -> str | None:
    if len(first14) != 14:
        return None
    total = 0
    for i, ch in enumerate(first14):
        v = _CHARS.find(ch)
        if v < 0:
            return None
        prod = v * (2 if i % 2 else 1)
        total += prod // 36 + prod % 36
    return _CHARS[(36 - total % 36) % 36]


def gstin_format_ok(g: str) -> bool:
    return bool(_GSTIN.match(g))


def gstin_checksum_ok(g: str) -> bool:
    return len(g) == 15 and gstin_check_digit(g[:14]) == g[14]


def gstin_valid(g: str) -> bool:
    return gstin_format_ok(g) and gstin_checksum_ok(g)


def gstin_mask(g: str) -> str:
    return "•••" if len(g) < 15 else f"{g[:5]}••••••{g[11:]}"


_LETTER_POS, _DIGIT_POS = {2, 3, 4, 5, 6, 11}, {0, 1, 7, 8, 9, 10}
_TO_LETTER = {"0": "O", "1": "I", "2": "Z", "5": "S", "8": "B", "6": "G"}
_TO_DIGIT = {"O": "0", "D": "0", "Q": "0", "I": "1", "L": "1", "Z": "2", "S": "5", "B": "8", "G": "6"}
_LOOKALIKES = {"O": "UDQ0", "0": "OUD", "U": "O0", "D": "O0", "1": "IL", "I": "1L", "L": "1I", "5": "S", "S": "5",
               "8": "B", "B": "8"}


def gstin_ocr_repair(raw: str, exists) -> str:
    """Fix OCR look-alikes by the GSTIN's fixed letter/digit positions; accept a further
    look-alike swap only if exactly one candidate is valid *and* in the registry, so real
    tampering is never 'repaired'."""
    g = gstin_normalise(raw)
    if len(g) != 15:
        return g
    c = list(g)
    for i in range(15):
        if i in _LETTER_POS:
            c[i] = _TO_LETTER.get(c[i], c[i])
        if i in _DIGIT_POS:
            c[i] = _TO_DIGIT.get(c[i], c[i])
    if c[13] == "2":
        c[13] = "Z"
    fixed = "".join(c)
    if gstin_valid(fixed):
        return fixed
    found: set[str] = set()

    def walk(s: list[str], start: int, depth: int):
        for i in range(start, 15):
            for alt in _LOOKALIKES.get(s[i], ""):
                if i in _LETTER_POS and alt.isdigit():
                    continue
                if i in _DIGIT_POS and not alt.isdigit():
                    continue
                n = s.copy()
                n[i] = alt
                cand = "".join(n)
                if gstin_valid(cand) and exists(cand):
                    found.add(cand)
                if depth < 2:
                    walk(n, i + 1, depth + 1)

    walk(c, 0, 1)
    return next(iter(found)) if len(found) == 1 else fixed


# ---------------------------------------------------------------- Udyam
def udyam_normalise(raw: str) -> str:
    s = re.sub(r"\s", "", raw.upper())
    m = re.search(r"([A-Z]{2})-?([0O]{2}|\d{2})-?(\d{7})$", s)
    if m and not s.startswith("UDYAM-"):
        return f"UDYAM-{m[1]}-{m[2].replace('O', '0')}-{m[3]}"
    return s


def udyam_valid(u: str) -> bool:
    return bool(_UDYAM.match(u))


def udyam_mask(u: str) -> str:
    return "•••" if len(u) < 19 else f"{u[:9]}••-•••{u[15:]}"


# ---------------------------------------------------------------- registry
@dataclass(frozen=True)
class GstRecord:
    gstin: str
    legalName: str
    tradeName: str
    constitution: str
    address: str
    state: str
    registrationDate: str
    status: str

    @property
    def active(self) -> bool:
        return self.status == "Active"


@dataclass(frozen=True)
class UdyamRecord:
    number: str
    enterpriseName: str
    enterpriseType: str
    majorActivity: str
    nicDescription: str
    state: str
    city: str
    registrationDate: str


def normalise_name(s: str) -> str:
    t = re.sub(r"[^a-z0-9 ]", " ", s.lower().replace("&", " and "))
    t = t.strip()
    for suffix in ("private limited", "pvt ltd", "pvt", "ltd", "llp", "limited"):
        if t.endswith(suffix):
            t = t[: -len(suffix)].strip()
    return re.sub(r"\s+", " ", t).strip()


def name_similarity(a: str, b: str) -> float:
    x, y = set(normalise_name(a).split()), set(normalise_name(b).split())
    return len(x & y) / len(x | y) if x and y else 0.0


def proprietor_trade_name(legal: str) -> str | None:
    m = re.search(r"\(\s*Prop\.?\s*([^)]+)\)", legal, re.I)
    return m[1].strip() if m else None


def proprietor_person(legal: str) -> str | None:
    i = legal.find("(")
    return legal[:i].strip() if i > 0 else None


class Registry:
    def __init__(self, gst: dict[str, GstRecord], udyam: dict[str, UdyamRecord]):
        self._gst, self._udyam = gst, udyam
        self._udyam_by_name: dict[str, list[UdyamRecord]] = {}
        for r in udyam.values():
            self._udyam_by_name.setdefault(normalise_name(r.enterpriseName), []).append(r)

    @classmethod
    def load(cls, data_dir: Path) -> "Registry":
        g = json.loads((data_dir / "gstin_registry.json").read_text(encoding="utf-8"))
        u = json.loads((data_dir / "udyam_registry.json").read_text(encoding="utf-8"))
        return cls({r[0]: GstRecord(*r) for r in g["rows"]}, {r[0]: UdyamRecord(*r) for r in u["rows"]})

    def gstin(self, g: str) -> GstRecord | None:
        return self._gst.get(g)

    def udyam(self, n: str) -> UdyamRecord | None:
        return self._udyam.get(n)

    def udyam_by_name(self, name: str) -> list[UdyamRecord]:
        return self._udyam_by_name.get(normalise_name(name), [])

    @property
    def counts(self) -> tuple[int, int]:
        return len(self._gst), len(self._udyam)


# ---------------------------------------------------------------- Smart KYC
SEVERITY = ["pass", "info", "warn", "action", "fail"]
DOC_LABEL = {"gstCertificate": "GST certificate", "udyamCertificate": "Udyam certificate",
             "signatoryId": "Signatory ID", "addressProof": "Address proof"}


@dataclass
class Doc:
    fields: dict
    readability: float = 1.0
    rotation: float = 0.0

    def get(self, k: str) -> str | None:
        v = (self.fields.get(k) or "").strip()
        return v or None


@dataclass
class Check:
    id: str
    severity: str
    message: str
    fix: str | None = None


def verdict_of(checks: list[Check]) -> str:
    if any(c.severity == "fail" for c in checks):
        return "rejected"
    if any(c.severity == "action" for c in checks):
        return "actionNeeded"
    return "approved"


def _same_address(a: str, b: str) -> bool:
    n = lambda s: re.sub(r"[^a-z0-9]", "", s.lower())  # noqa: E731
    return n(a) == n(b)


def _date(s: str | None) -> date | None:
    m = re.search(r"(\d{4})-(\d{2})-(\d{2})", s or "")
    return date(int(m[1]), int(m[2]), int(m[3])) if m else None


class KycValidator:
    MAX_BILL_AGE_DAYS = 90
    MIN_READABILITY = 0.6

    def __init__(self, registry: Registry, today: date = date(2026, 7, 15)):
        self.r, self.today = registry, today  # the case fixes "today" at 2026-07-15

    def validate(self, docs: dict[str, Doc], gst_required: bool = True):
        out: list[Check] = []
        gst_doc, udyam_doc = docs.get("gstCertificate"), docs.get("udyamCertificate")
        id_doc, bill_doc = docs.get("signatoryId"), docs.get("addressProof")
        for t, d in docs.items():
            if d.readability < self.MIN_READABILITY:
                out.append(Check(f"quality_{t}", "action", f"{DOC_LABEL[t]} is too blurry to read.",
                                 "Retake the photo in good light, flat and in focus."))
            elif abs(d.rotation) >= 2:
                out.append(Check(f"rotation_{t}", "info", f"{DOC_LABEL[t]} was tilted {abs(d.rotation):.0f}° — straightened automatically."))
        readable = lambda d: d is not None and d.readability >= self.MIN_READABILITY  # noqa: E731

        gst = None
        if gst_doc is None:
            out.append(Check("gst_missing", "action", "GST certificate not uploaded.",
                             "Upload the GST registration certificate, or continue without GST (some products need it).")
                       if gst_required else Check("gst_missing", "info", "No GST certificate — plan has no GST-only products."))
        elif readable(gst_doc):
            raw = gst_doc.get("gstin")
            g = gstin_ocr_repair(raw, lambda x: self.r.gstin(x) is not None) if raw else None
            if raw and g != gstin_normalise(raw):
                out.append(Check("gst_ocr_fix", "info", "GSTIN look-alike characters corrected from the scan (e.g. 0/O) and confirmed with GSTN."))
            if g is None:
                out.append(Check("gst_number", "action", "GSTIN not found on the certificate.", "Type your 15-character GSTIN."))
            elif not gstin_format_ok(g):
                out.append(Check("gst_format", "fail", f"GSTIN {gstin_mask(g)} is not a valid GSTIN format.", "Check the number on your certificate."))
            elif not gstin_checksum_ok(g):
                out.append(Check("gst_checksum", "fail", f"GSTIN {gstin_mask(g)} fails the GSTN check digit — the number has been altered or mistyped.",
                                 "Re-check every character, especially 0/O, 5/S, 8/B."))
            else:
                out.append(Check("gst_format", "pass", f"GSTIN {gstin_mask(g)} format and check digit valid."))
                gst = self.r.gstin(g)
                if gst is None:
                    out.append(Check("gst_registry", "fail", f"GSTIN {gstin_mask(g)} not found in the GST registry."))
                else:
                    out.append(Check("gst_status", "pass", "GST registration is Active.") if gst.active else
                               Check("gst_status", "fail", f"GST registration is {gst.status} in the GST registry.",
                                     "Restore your GST registration on the GST portal, or continue without GST products."))
                    code_state = STATE_CODES.get(g[:2])
                    if code_state and code_state != gst.state:
                        out.append(Check("gst_state", "fail", f"GSTIN state code ({code_state}) does not match {gst.state}."))
                    legal, trade = gst_doc.get("legalName"), gst_doc.get("tradeName")
                    if legal and name_similarity(legal, gst.legalName) < 0.8:
                        out.append(Check("gst_legal_name", "fail", f'Legal name on certificate ("{legal}") does not match GST records ("{gst.legalName}").',
                                         "Upload the original certificate."))
                    if trade and name_similarity(trade, gst.tradeName) < 0.8:
                        out.append(Check("gst_trade_name", "fail", f'Trade name on certificate does not match GST records ("{gst.tradeName}").'))
                    prop = proprietor_trade_name(legal) if legal else None
                    if prop and trade and name_similarity(prop, trade) < 0.8:
                        out.append(Check("gst_internal_name", "fail", f'Certificate is inconsistent: legal name says "{prop}" but trade name says "{trade}".'))
                    addr = gst_doc.get("address")
                    if addr and not _same_address(addr, gst.address):
                        out.append(Check("gst_address", "warn", "Address on the certificate scan differs slightly from GST records; GST records used."))
                    if not any(c.id.startswith("gst_") and c.severity == "fail" for c in out):
                        out.append(Check("gst_match", "pass", "Certificate details match GST records."))

        udyam = None
        if udyam_doc is None:
            out.append(Check("udyam_missing", "warn" if gst and gst.active else "action", "Udyam certificate not uploaded.",
                             "Upload it, or fetch it from DigiLocker."))
        elif readable(udyam_doc):
            raw = udyam_doc.get("number")
            n = udyam_normalise(raw) if raw else None
            if n is None:
                out.append(Check("udyam_number", "action", "Udyam registration number is blank on the certificate.",
                                 "Upload a complete Udyam certificate or type the number."))
            elif not udyam_valid(n):
                out.append(Check("udyam_format", "fail", f"Udyam number {udyam_mask(n)} is not a valid format."))
            else:
                udyam = self.r.udyam(n)
                if udyam is None:
                    out.append(Check("udyam_registry", "fail", f"Udyam {udyam_mask(n)} not found in the Udyam registry."))
                else:
                    out.append(Check("udyam_registry", "pass", f"Udyam {udyam_mask(n)} found."))
                    name = udyam_doc.get("enterpriseName")
                    if name and name_similarity(name, udyam.enterpriseName) < 0.8:
                        out.append(Check("udyam_name", "fail", "Enterprise name does not match Udyam records."))
                    if gst and name_similarity(udyam.enterpriseName, gst.tradeName) < 0.8:
                        out.append(Check("udyam_vs_gst", "fail", "Udyam registration belongs to a different business than the GSTIN."))
                    if gst and udyam.state != gst.state:
                        out.append(Check("udyam_state", "warn", f"Udyam state ({udyam.state}) differs from GST state ({gst.state})."))
                    act = udyam_doc.get("majorActivity")
                    if act and act.lower() != udyam.majorActivity.lower():
                        out.append(Check("udyam_activity", "warn", f"Activity on certificate ({act}) differs from Udyam records ({udyam.majorActivity})."))

        trade_ref = gst.tradeName if gst else (gst_doc.get("tradeName") if gst_doc else None)
        if id_doc is None:
            out.append(Check("id_missing", "action", "Authorised signatory ID not uploaded."))
        elif readable(id_doc):
            valid_till = _date(id_doc.get("validTill"))
            if valid_till and valid_till < self.today:
                out.append(Check("id_expired", "action", "Signatory ID has expired.", "Upload a valid ID."))
            biz = id_doc.get("forBusiness")
            if biz and trade_ref and name_similarity(biz, trade_ref) < 0.8:
                out.append(Check("id_business", "fail", "Signatory ID is for a different business."))
            out.append(self._signatory(id_doc, gst))

        if bill_doc is None:
            out.append(Check("bill_missing", "action", "Address proof not uploaded."))
        elif readable(bill_doc):
            d = _date(bill_doc.get("billDate"))
            if d is None:
                out.append(Check("bill_date", "action", "Bill date not readable."))
            else:
                age = (self.today - d).days
                out.append(Check("bill_age", "action", f"Address proof is {age} days old (dated {d.isoformat()}); it must be within {self.MAX_BILL_AGE_DAYS} days.",
                                 "Upload your latest electricity, water or phone bill.") if age > self.MAX_BILL_AGE_DAYS
                           else Check("bill_age", "pass", f"Address proof is recent ({age} days old)."))
            billed = bill_doc.get("billedTo")
            if billed and trade_ref and name_similarity(billed, trade_ref) < 0.8:
                out.append(Check("bill_name", "fail", "Bill is in a different name from the business."))
            addr = bill_doc.get("address")
            ref = gst.address if gst else (gst_doc.get("address") if gst_doc else None)
            if addr and ref:
                out.append(Check("bill_address", "pass", "Bill address matches the GST address.") if _same_address(addr, ref)
                           else Check("bill_address", "fail", "Bill address does not match the GST address."))

        out.sort(key=lambda c: -SEVERITY.index(c.severity))
        return out, gst, udyam

    def _signatory(self, id_doc: Doc, gst: GstRecord | None) -> Check:
        designation = id_doc.get("designation") or ""
        role, name = designation.lower(), id_doc.get("name") or ""
        constitution = gst.constitution if gst else ""
        if "admin" in role:
            return Check("id_role", "action", f'"{designation}" is not an authorised signatory role.',
                         "The proprietor/partner/director must sign, or upload a board resolution / authorisation letter.")
        if constitution == "Limited Liability Partnership" and role not in ("partner", "designated partner"):
            return Check("id_role", "action", f'For an LLP the signatory must be a designated partner, not "{designation}".',
                         "Upload a partner's ID or an authorisation letter signed by the partners.")
        if constitution == "Private Limited Company" and role not in ("director", "managing director"):
            return Check("id_role", "action", f'For a private limited company the signatory must be a director, not "{designation}".',
                         "Upload a director's ID or a board resolution.")
        if constitution == "Proprietorship":
            person = proprietor_person(gst.legalName) if gst else None
            if not (person and name_similarity(person, name) >= 0.99):
                return Check("id_role", "action", "Signatory is not the registered proprietor.",
                             "The proprietor must sign, or upload an authorisation letter.")
            if role not in ("owner", "proprietor"):
                return Check("id_role", "warn", f'ID shows role "{designation}", but the name matches the registered proprietor — accepted.')
        return Check("id_role", "pass", "Signatory is authorised for this business.")
