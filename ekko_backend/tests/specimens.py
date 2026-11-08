"""Fields as printed on the 12 case specimen applicants (what on-device OCR sends)."""

GST = {
    "K01": ["37IHKXV5167L1ZS", "Neha Kaur (Prop. Vindhya Tours & Travels)", "Vindhya Tours & Travels", "Shop/Unit 1, Tech Park Road, Visakhapatnam, Andhra Pradesh - 118383"],
    "K02": ["19EOGXH4115Y1ZL", "Joseph Shah (Prop. Harmony Dental Care)", "Harmony Dental Care", "Shop/Unit 199, Station Road, Kolkata, West Bengal - 347550"],
    "K03": ["27XUIXG0767D1ZP", "Joseph Singh (Prop. Ganesh Woodcraft)", "Ganesh Woodcraft", "Shop/Unit 80, Civil Lines, Nagpur, Maharashtra - 411231"],
    "K05": ["32TZAXB5481U1Z1", "Balaji Realty LLP", "Balaji Realty LLP", "Shop/Unit 38, Civil Lines, Kochi, Kerala - 752083"],
    "K06": ["08YKZXS8189L1Z0", "Pooja Shah (Prop. Saffron Unisex Salon)", "Saffron Unisex Salon", "Shop/Unit 71, Market Yard, Jaipur, Rajasthan - 194057"],
    "K07": ["07CPCXN0398P1ZT", "Neha Banerjee (Prop. Shri Physio Clinic)", "Neelgiri Physio Clinic", "Shop/Unit 52, Transport Nagar, Delhi, Delhi - 334596"],
    "K08": ["24XORXG9365M1Z3", "Joseph Rao (Prop. Green Leaf Legal Associates)", "Green Leaf Legal Associates", "Shop/Unit 238, Ring Road, Vadodara, Gujarat - 348176"],
    "K09": ["37LDYXK0296F1ZB", "Anita Kulkarni (Prop. Kaveri Insurance Advisors)", "Kaveri Insurance Advisors", "Shop/Unit 217, Civil Lines, Visakhapatnam, Andhra Pradesh - 405337"],
    "K10": ["27QHJXK0658U1ZL", "Kaveri Stays LLP", "Kaveri Stays LLP", "Shop/Unit 21, Sector 14, Mumbai, Maharashtra - 570043"],
    "K11": ["03KGZXT1320R1ZZ", "Trinity Bake House Pvt Ltd", "Trinity Bake House Pvt Ltd", "Shop/Unit 188, Industrial Area Phase 2, Ludhiana, Punjab - 541498"],
    "K12": ["37NBLXS1145E1ZU", "Pooja Agarwal (Prop. Star Electronics)", "Star Electronics", "Shop/Unit 216, Nehru Nagar, Visakhapatnam, Andhra Pradesh - 762071"],
}
UDYAM = {
    "K01": ["", "Vindhya Tours & Travels", "Services"], "K02": ["UDYAM-WB-00-5053330", "Harmony Dental Care", "Services"],
    "K03": ["UDYAM-MH-00-9516696", "Ganesh Woodcraft", "Manufacturing"], "K04": ["UDYAM-MH-00-6131836", "Saffron Dental Care LLP", "Services"],
    "K06": ["UDYAM-RJ-00-6577157", "Saffron Unisex Salon", "Services"], "K07": ["UDYAM-DL-00-9565547", "Neelgiri Physio Clinic", "Services"],
    "K08": ["UDYAM-GJ-00-8477445", "Green Leaf Legal Associates", "Services"], "K09": ["UDYAM-AP-00-9751562", "Kaveri Insurance Advisors", "Services"],
    "K10": ["UDYAM-MH-00-7183141", "Kaveri Stays LLP", "Services"], "K11": ["UDYAM-PB-00-9719478", "Trinity Bake House Pvt Ltd", "Services"],
    "K12": ["UDYAM-AP-00-5186772", "Star Electronics", "Services"],
}
ID = {
    "K01": ["Neha Kaur", "Office admin", "Vindhya Tours & Travels", "2028-03-26"], "K02": ["Joseph Shah", "Manager", "Harmony Dental Care", "2028-09-10"],
    "K03": ["Joseph Singh", "Owner", "Ganesh Woodcraft", "2028-07-04"], "K04": ["Fatima Pillai", "Partner", "Saffron Dental Care LLP", "2028-08-03"],
    "K05": ["Anita Shah", "Owner", "Balaji Realty LLP", "2029-09-11"], "K06": ["Pooja Shah", "Owner", "Saffron Unisex Salon", "2028-09-15"],
    "K07": ["Neha Banerjee", "Manager", "Neelgiri Physio Clinic", "2030-05-05"], "K08": ["Joseph Rao", "Office admin", "Green Leaf Legal Associates", "2027-09-18"],
    "K09": ["Anita Kulkarni", "Office admin", "Kaveri Insurance Advisors", "2027-12-22"], "K10": ["Nisha Arora", "Owner", "Kaveri Stays LLP", "2029-06-01"],
    "K11": ["Vikram Pillai", "Owner", "Trinity Bake House Pvt Ltd", "2028-12-23"], "K12": ["Pooja Agarwal", "Owner", "Star Electronics", "2029-03-03"],
}
BILL = {
    "K01": ["Vindhya Tours & Travels", "2026-06-26"], "K02": ["Harmony Dental Care", "2026-05-22"], "K03": ["Ganesh Woodcraft", "2026-05-30"],
    "K04": ["Saffron Dental Care LLP", "2026-05-28"], "K05": ["Balaji Realty LLP", "2026-06-11"], "K06": ["Saffron Unisex Salon", "2026-06-11"],
    "K07": ["Neelgiri Physio Clinic", "2026-07-05"], "K08": ["Green Leaf Legal Associates", "2026-05-26"], "K09": ["Kaveri Insurance Advisors", "2026-07-10"],
    "K10": ["Kaveri Stays LLP", "2026-06-18"], "K11": ["Trinity Bake House Pvt Ltd", "2025-10-31"], "K12": ["Star Electronics", "2026-07-06"],
}
K04_ADDRESS = "Shop/Unit 75, Lake View Colony, Nagpur, Maharashtra - 137452"

EXPECTED = {
    "K01": ("rejected", ["gst_status", "udyam_number", "id_role"]), "K02": ("approved", ["rotation_gstCertificate"]),
    "K03": ("approved", []), "K04": ("actionNeeded", ["quality_gstCertificate"]), "K05": ("actionNeeded", ["udyam_missing", "id_role"]),
    "K06": ("rejected", ["gst_checksum"]), "K07": ("rejected", ["gst_legal_name"]), "K08": ("actionNeeded", ["id_role"]),
    "K09": ("actionNeeded", ["id_role"]), "K10": ("actionNeeded", ["id_role", "udyam_activity"]),
    "K11": ("actionNeeded", ["bill_age", "id_role"]), "K12": ("approved", ["udyam_activity"]),
}


def documents(k: str) -> dict:
    """API payload for one applicant (same shape the app sends)."""
    docs = {}
    g = GST.get(k)
    addr = g[3] if g else K04_ADDRESS
    if g:
        docs["gstCertificate"] = {"fields": {"gstin": g[0], "legalName": g[1], "tradeName": g[2], "address": g[3]},
                                  "rotation": -7 if k == "K02" else 0}
    else:
        docs["gstCertificate"] = {"fields": {}, "readability": 0.1}
    if k in UDYAM:
        u = UDYAM[k]
        docs["udyamCertificate"] = {"fields": {"number": u[0], "enterpriseName": u[1], "majorActivity": u[2]}}
    i = ID[k]
    docs["signatoryId"] = {"fields": {"name": i[0], "designation": i[1], "forBusiness": i[2], "validTill": i[3]}}
    b = BILL[k]
    docs["addressProof"] = {"fields": {"billedTo": b[0], "billDate": b[1], "address": addr}}
    return docs
