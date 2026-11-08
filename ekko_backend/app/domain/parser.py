"""Deterministic understanding of advisor answers (English, Hindi, Hinglish, Tamil, Marathi).

Runs on the server with no AI key. Claude is only consulted when this returns nothing.
"""
from __future__ import annotations

import re

from .engine import NEEDS

CITIES = {
    "ahmedabad": (1, "Ahmedabad"), "bengaluru": (1, "Bengaluru"), "bangalore": (1, "Bengaluru"), "bhopal": (2, "Bhopal"),
    "chennai": (1, "Chennai"), "coimbatore": (2, "Coimbatore"), "delhi": (1, "Delhi"), "hyderabad": (1, "Hyderabad"),
    "indore": (2, "Indore"), "jaipur": (2, "Jaipur"), "kochi": (2, "Kochi"), "kolkata": (1, "Kolkata"),
    "lucknow": (2, "Lucknow"), "ludhiana": (2, "Ludhiana"), "mumbai": (1, "Mumbai"), "mysuru": (2, "Mysuru"),
    "nagpur": (2, "Nagpur"), "nashik": (2, "Nashik"), "patna": (2, "Patna"), "pune": (1, "Pune"), "surat": (2, "Surat"),
    "vadodara": (2, "Vadodara"), "visakhapatnam": (2, "Visakhapatnam"),
    "मुंबई": (1, "Mumbai"), "मुम्बई": (1, "Mumbai"), "दिल्ली": (1, "Delhi"), "पुणे": (1, "Pune"), "जयपुर": (2, "Jaipur"),
    "लखनऊ": (2, "Lucknow"), "पटना": (2, "Patna"), "इंदौर": (2, "Indore"), "भोपाल": (2, "Bhopal"), "नागपुर": (2, "Nagpur"),
    "बेंगलुरु": (1, "Bengaluru"), "चेन्नई": (1, "Chennai"), "कोलकाता": (1, "Kolkata"), "हैदराबाद": (1, "Hyderabad"),
    "சென்னை": (1, "Chennai"), "கோயம்புத்தூர்": (2, "Coimbatore"),
}
BUSINESS_WORDS = {
    "किराना": "Kirana store", "kirana": "Kirana store", "दुकान": "Kirana store", "dukaan": "Kirana store",
    "salon": "Salon", "सैलून": "Salon", "parlour": "Salon", "पार्लर": "Salon",
    "dental": "Dental clinic", "dentist": "Dental clinic", "clinic": "Dental clinic", "क्लिनिक": "Dental clinic",
    "pharmacy": "Pharmacy", "chemist": "Pharmacy", "medical": "Pharmacy", "दवा": "Pharmacy",
    "factory": "Auto-parts unit", "फैक्ट्री": "Auto-parts unit", "manufactur": "Auto-parts unit",
    "restaurant": "Restaurant chain", "रेस्टोरेंट": "Restaurant chain", "cafe": "Restaurant chain",
    "hotel": "Budget hotel group", "होटल": "Budget hotel group", "coaching": "Coaching centre", "tuition": "Coaching centre",
    "कोचिंग": "Coaching centre", "lawyer": "Law office", "वकील": "Law office", "ca firm": "CA firm", "accountant": "CA firm",
    "gym": "Gym chain", "bakery": "Bakery", "बेकरी": "Bakery", "boutique": "Boutique", "hardware": "Hardware store",
}
NUMBER_WORDS = {
    "ek": 1, "one": 1, "एक": 1, "do": 2, "two": 2, "दो": 2, "teen": 3, "three": 3, "तीन": 3, "char": 4, "chaar": 4,
    "four": 4, "चार": 4, "paanch": 5, "panch": 5, "five": 5, "पांच": 5, "पाँच": 5, "chhe": 6, "six": 6, "छह": 6,
    "saat": 7, "seven": 7, "सात": 7, "aath": 8, "eight": 8, "आठ": 8, "nau": 9, "nine": 9, "नौ": 9, "das": 10, "ten": 10,
    "दस": 10, "bees": 20, "twenty": 20, "बीस": 20, "pachas": 50, "fifty": 50, "पचास": 50,
}
MULTIPLIERS = {"k": 1000, "hazaar": 1000, "hazar": 1000, "thousand": 1000, "हज़ार": 1000, "हजार": 1000,
               "lakh": 100000, "लाख": 100000}
NEED_WORDS = {
    "upiPos": ["upi", "billing", "pos", "payment", "बिल"], "cctv": ["cctv", "camera", "कैमरा"],
    "whatsapp": ["whatsapp", "व्हाट्सएप"], "guestWifi": ["wifi", "wi-fi", "वाईफाई"], "cloudEmail": ["email", "ईमेल"],
    "backup": ["backup", "बैकअप"], "deviceSecurity": ["antivirus", "virus", "security"], "firewall": ["firewall"],
    "failover": ["never goes down", "backup internet", "failover", "बंद न"], "multiSiteMgmt": ["sd-wan", "branches", "centrally"],
    "staticIp": ["static ip", "fixed ip"], "telephony": ["ivr", "phone line", "landline"], "tollFree": ["toll", "1800"],
    "sms": ["sms", "एसएमएस"], "website": ["website", "वेबसाइट"], "dedicatedLine": ["leased", "dedicated"],
    "machineIot": ["machine", "iot", "मशीन"], "fleet": ["vehicle", "fleet", "truck", "गाड़ी"],
}
INTERNET = [("Mobile hotspot", ["hotspot", "mobile data", "phone", "फ़ोन", "फोन"]), ("Leased line", ["leased"]),
            ("Business broadband", ["business broadband", "business"]),
            ("Home broadband", ["home", "broadband", "wifi", "wi-fi"]), ("", ["nothing", "none", "कुछ नहीं"])]
_DEVANAGARI = str.maketrans("०१२३४५६७८९", "0123456789")


def _number(text: str) -> int | None:
    t = text.translate(_DEVANAGARI).lower()
    m = re.search(r"(\d[\d,]*(?:\.\d+)?)\s*(k|hazaar|hazar|thousand|हज़ार|हजार|lakh|लाख)?", t)
    if m:
        n = float(m[1].replace(",", ""))
        return int(n * MULTIPLIERS.get(m[2] or "", 1))
    words = re.findall(r"[\wऀ-ॿ]+", t)
    for i, w in enumerate(words):
        if w in NUMBER_WORDS:
            n = NUMBER_WORDS[w]
            if i + 1 < len(words) and words[i + 1] in MULTIPLIERS:
                n *= MULTIPLIERS[words[i + 1]]
            return n
    return None


def understand(step: str, text: str) -> dict:
    """Return the profile fields an answer states for the given advisor step (empty if unsure)."""
    t = text.translate(_DEVANAGARI).lower().strip()
    if step == "type":
        for k, v in BUSINESS_WORDS.items():
            if k in t:
                return {"businessType": v}
        return {"businessType": text.strip().title()} if len(t) >= 3 else {}
    if step in ("employees", "sites"):
        n = _number(t)
        return {step: n} if n else {}
    if step == "spend":
        n = _number(t)
        return {"currentMonthlySpend": n} if n is not None else {}
    if step == "budget":
        if any(w in t for w in ("no limit", "no budget", "nahi", "नहीं")):
            return {"noBudget": True}
        n = _number(t)
        return {"budget": n} if n else {}
    if step == "city":
        for k, (tier, name) in CITIES.items():
            if k in t:
                return {"city": name, "cityTier": tier}
        return {}
    if step == "internet":
        for value, words in INTERNET:
            if any(w in t for w in words):
                return {"currentInternet": value}
        return {}
    if step == "gstin":
        g = re.sub(r"[^0-9A-Z]", "", text.upper())
        m = re.search(r"\d{2}[A-Z0-9]{13}", g)
        if m:
            return {"gstin": m[0]}
        return {"noGstin": True} if any(w in t for w in ("no", "nahi", "नहीं", "illa")) else {}
    if step == "pincode":
        m = re.search(r"\b[1-9]\d{5}\b", t)
        return {"pincode": m[0]} if m else {}
    if step == "needs":
        found = [n for n in NEEDS if any(w in t for w in NEED_WORDS.get(n, []))]
        return {"needs": found} if found else {}
    return {}
