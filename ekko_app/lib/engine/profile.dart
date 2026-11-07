/// What the advisor has learned about the business.
enum Segment { micro, prof, multi, mfg }

enum GstStatus { none, active, cancelled, suspended }

/// Business needs the advisor can ask about. Each maps to catalogue products.
enum Need {
  upiPos,
  cctv,
  whatsapp,
  guestWifi,
  cloudEmail,
  backup,
  deviceSecurity,
  firewall,
  failover,
  multiSiteMgmt,
  staticIp,
  telephony,
  tollFree,
  sms,
  website,
  dedicatedLine,
  machineIot,
  fleet,
}

class BusinessProfile {
  String businessType;
  Segment segment;
  int employees;
  int sites;
  int cityTier;
  String city;
  String state;
  GstStatus gstStatus;
  String? gstin;
  bool hasUdyam;
  String currentInternet;
  int currentMonthlySpend;
  Set<Need> needs;
  bool fibreFeasible;
  bool mobileOnly;
  int? budget;
  int vehicles;
  int machines;
  String language;

  BusinessProfile({
    this.businessType = '',
    this.segment = Segment.micro,
    this.employees = 1,
    this.sites = 1,
    this.cityTier = 1,
    this.city = '',
    this.state = '',
    this.gstStatus = GstStatus.none,
    this.gstin,
    this.hasUdyam = false,
    this.currentInternet = '',
    this.currentMonthlySpend = 0,
    Set<Need>? needs,
    this.fibreFeasible = true,
    this.mobileOnly = false,
    this.budget,
    this.vehicles = 3,
    this.machines = 8,
    this.language = 'en',
  }) : needs = needs ?? <Need>{};

  bool get hasActiveGstin => gstStatus == GstStatus.active;

  Map<String, dynamic> toJson() => {
        'businessType': businessType,
        'segment': segment.name,
        'employees': employees,
        'sites': sites,
        'cityTier': cityTier,
        'city': city,
        'state': state,
        'gstStatus': gstStatus.name,
        'gstin': gstin,
        'hasUdyam': hasUdyam,
        'currentInternet': currentInternet,
        'currentMonthlySpend': currentMonthlySpend,
        'needs': needs.map((n) => n.name).toList(),
        'fibreFeasible': fibreFeasible,
        'mobileOnly': mobileOnly,
        'budget': budget,
        'vehicles': vehicles,
        'machines': machines,
        'language': language,
      };

  factory BusinessProfile.fromJson(Map<String, dynamic> j) => BusinessProfile(
        businessType: j['businessType'] ?? '',
        segment: Segment.values.byName(j['segment'] ?? 'micro'),
        employees: j['employees'] ?? 1,
        sites: j['sites'] ?? 1,
        cityTier: j['cityTier'] ?? 1,
        city: j['city'] ?? '',
        state: j['state'] ?? '',
        gstStatus: GstStatus.values.byName(j['gstStatus'] ?? 'none'),
        gstin: j['gstin'],
        hasUdyam: j['hasUdyam'] ?? false,
        currentInternet: j['currentInternet'] ?? '',
        currentMonthlySpend: j['currentMonthlySpend'] ?? 0,
        needs: {for (final n in (j['needs'] as List? ?? const [])) Need.values.byName(n)},
        fibreFeasible: j['fibreFeasible'] ?? true,
        mobileOnly: j['mobileOnly'] ?? false,
        budget: j['budget'],
        vehicles: j['vehicles'] ?? 3,
        machines: j['machines'] ?? 8,
        language: j['language'] ?? 'en',
      );
}

/// Segment from business type and size, mirroring the four case segments.
Segment segmentFor(String businessType, int employees, int sites) {
  final t = businessType.toLowerCase();
  const mfgWords = ['manufactur', 'unit', 'factory', 'workshop', 'press', 'moulding', 'processing', 'textile'];
  if (mfgWords.any(t.contains)) return Segment.mfg;
  if (sites >= 3 || t.contains('chain') || t.contains('group')) return Segment.multi;
  const profWords = [
    'clinic', 'ca ', 'ca firm', 'chartered', 'coaching', 'law', 'legal', 'dental', 'diagnostic', 'lab',
    'architect', 'insurance', 'real estate', 'travel', 'agency', 'studio', 'consult', 'office', 'physio',
  ];
  if (profWords.any(t.contains) || t == 'ca') return Segment.prof;
  return Segment.micro;
}
