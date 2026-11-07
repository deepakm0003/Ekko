import 'dart:convert';

/// Mock GSTN record (mock_gstin_registry.csv).
class GstRecord {
  final String gstin;
  final String legalName;
  final String tradeName;
  final String constitution;
  final String address;
  final String state;
  final String registrationDate;
  final String status;
  const GstRecord(this.gstin, this.legalName, this.tradeName, this.constitution, this.address, this.state,
      this.registrationDate, this.status);
  bool get isActive => status == 'Active';
}

/// Mock Udyam record (mock_udyam_registry.csv).
class UdyamRecord {
  final String number;
  final String enterpriseName;
  final String enterpriseType;
  final String majorActivity;
  final String nicDescription;
  final String state;
  final String city;
  final String registrationDate;
  const UdyamRecord(this.number, this.enterpriseName, this.enterpriseType, this.majorActivity,
      this.nicDescription, this.state, this.city, this.registrationDate);
}

/// The two mock lookup APIs, backed by the registries shipped with the app.
class Registry {
  final Map<String, GstRecord> _gst;
  final Map<String, UdyamRecord> _udyam;
  Registry(this._gst, this._udyam);

  factory Registry.fromJson(String gstRaw, String udyamRaw) {
    final g = jsonDecode(gstRaw) as Map<String, dynamic>;
    final u = jsonDecode(udyamRaw) as Map<String, dynamic>;
    return Registry(
      {
        for (final r in g['rows'] as List)
          r[0] as String: GstRecord(r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7]),
      },
      {
        for (final r in u['rows'] as List)
          r[0] as String: UdyamRecord(r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7]),
      },
    );
  }

  GstRecord? gstin(String g) => _gst[g];
  UdyamRecord? udyam(String u) => _udyam[u];

  /// Udyam records for a business name (used to cross-check a GST record).
  List<UdyamRecord> udyamByName(String name) {
    final key = normaliseName(name);
    return _udyam.values.where((r) => normaliseName(r.enterpriseName) == key).toList();
  }

  int get gstCount => _gst.length;
  int get udyamCount => _udyam.length;
}

/// Lower-case, strip punctuation and legal suffixes for name comparison.
String normaliseName(String s) {
  var t = s.toLowerCase().replaceAll('&', ' and ');
  t = t.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  for (final suffix in const [' private limited', ' pvt ltd', ' pvt', ' ltd', ' llp', ' limited']) {
    if (t.trimRight().endsWith(suffix.trim())) {
      t = t.trimRight();
      t = t.substring(0, t.length - suffix.trim().length);
    }
  }
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// "Neha Kaur (Prop. Vindhya Tours & Travels)" -> "Vindhya Tours & Travels"
String? proprietorTradeName(String legalName) {
  final m = RegExp(r'\(\s*Prop\.?\s*([^)]+)\)', caseSensitive: false).firstMatch(legalName);
  return m?.group(1)?.trim();
}

/// "Neha Kaur (Prop. Vindhya Tours & Travels)" -> "Neha Kaur"
String? proprietorPerson(String legalName) {
  final i = legalName.indexOf('(');
  return i > 0 ? legalName.substring(0, i).trim() : null;
}

/// Token-overlap similarity in [0, 1].
double nameSimilarity(String a, String b) {
  final x = normaliseName(a).split(' ').where((t) => t.isNotEmpty).toSet();
  final y = normaliseName(b).split(' ').where((t) => t.isNotEmpty).toSet();
  if (x.isEmpty || y.isEmpty) return 0;
  return x.intersection(y).length / x.union(y).length;
}
