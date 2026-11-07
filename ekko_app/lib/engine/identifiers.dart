/// GSTIN / Udyam format checks and masking.
class Gstin {
  static const _chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static final _pattern = RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

  static const stateCodes = {
    '01': 'Jammu and Kashmir', '02': 'Himachal Pradesh', '03': 'Punjab', '04': 'Chandigarh',
    '05': 'Uttarakhand', '06': 'Haryana', '07': 'Delhi', '08': 'Rajasthan', '09': 'Uttar Pradesh',
    '10': 'Bihar', '11': 'Sikkim', '12': 'Arunachal Pradesh', '13': 'Nagaland', '14': 'Manipur',
    '15': 'Mizoram', '16': 'Tripura', '17': 'Meghalaya', '18': 'Assam', '19': 'West Bengal',
    '20': 'Jharkhand', '21': 'Odisha', '22': 'Chhattisgarh', '23': 'Madhya Pradesh', '24': 'Gujarat',
    '26': 'Dadra and Nagar Haveli and Daman and Diu', '27': 'Maharashtra', '29': 'Karnataka', '30': 'Goa',
    '32': 'Kerala', '33': 'Tamil Nadu', '34': 'Puducherry', '36': 'Telangana', '37': 'Andhra Pradesh',
  };

  static String normalise(String raw) => raw.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');

  /// Structure check. The 4th PAN character ("X" in the mock data) is accepted.
  static bool hasValidFormat(String g) => _pattern.hasMatch(g);

  /// GSTN mod-36 check digit.
  static String? checkDigit(String first14) {
    if (first14.length != 14) return null;
    var sum = 0;
    for (var i = 0; i < 14; i++) {
      final v = _chars.indexOf(first14[i]);
      if (v < 0) return null;
      final prod = v * (i.isOdd ? 2 : 1);
      sum += prod ~/ 36 + prod % 36;
    }
    return _chars[(36 - sum % 36) % 36];
  }

  static bool hasValidChecksum(String g) => g.length == 15 && checkDigit(g.substring(0, 14)) == g[14];

  static bool isValid(String g) => hasValidFormat(g) && hasValidChecksum(g);

  static const _letterPos = {2, 3, 4, 5, 6, 11};
  static const _digitPos = {0, 1, 7, 8, 9, 10};
  static const _toLetter = {'0': 'O', '1': 'I', '2': 'Z', '5': 'S', '8': 'B', '6': 'G'};
  static const _toDigit = {'O': '0', 'D': '0', 'Q': '0', 'I': '1', 'L': '1', 'Z': '2', 'S': '5', 'B': '8', 'G': '6'};
  static const _lookalikes = {
    'O': ['U', 'D', 'Q', '0'], '0': ['O', 'U', 'D'], 'U': ['O', '0'], 'D': ['O', '0'],
    '1': ['I', 'L'], 'I': ['1', 'L'], 'L': ['1', 'I'], '5': ['S'], 'S': ['5'], '8': ['B'], 'B': ['8'],
  };

  /// Fix OCR look-alike confusions using the GSTIN's fixed letter/digit
  /// positions. If that still fails the check digit, try up to two look-alike
  /// swaps, accepting a result only if exactly one candidate is both valid and
  /// [exists] (registry match) — so genuine tampering is never "repaired".
  static String ocrRepair(String raw, {required bool Function(String) exists}) {
    final g = normalise(raw);
    if (g.length != 15) return g;
    final c = g.split('');
    for (var i = 0; i < 15; i++) {
      if (_letterPos.contains(i)) c[i] = _toLetter[c[i]] ?? c[i];
      if (_digitPos.contains(i)) c[i] = _toDigit[c[i]] ?? c[i];
    }
    if (c[13] == '2') c[13] = 'Z';
    final fixed = c.join();
    if (isValid(fixed)) return fixed;
    final found = <String>{};
    void tryFrom(List<String> s, int start, int depth) {
      for (var i = start; i < 15; i++) {
        for (final alt in _lookalikes[s[i]] ?? const <String>[]) {
          if (_letterPos.contains(i) && RegExp(r'\d').hasMatch(alt)) continue;
          if (_digitPos.contains(i) && !RegExp(r'\d').hasMatch(alt)) continue;
          final n = [...s]..[i] = alt;
          final cand = n.join();
          if (isValid(cand) && exists(cand)) found.add(cand);
          if (depth < 2) tryFrom(n, i + 1, depth + 1);
        }
      }
    }

    tryFrom(c, 0, 1);
    return found.length == 1 ? found.first : fixed;
  }

  static String? stateOf(String g) => g.length >= 2 ? stateCodes[g.substring(0, 2)] : null;

  /// 37IHKXV5167L1ZS -> 37IHK••••••L1ZS (state + PAN prefix and last 4 kept)
  static String mask(String g) => g.length < 15 ? '•••' : '${g.substring(0, 5)}••••••${g.substring(11)}';
}

class Udyam {
  static final _pattern = RegExp(r'^UDYAM-[A-Z]{2}-\d{2}-\d{7}$');
  static String normalise(String raw) {
    final s = raw.toUpperCase().replaceAll(RegExp(r'\s'), '');
    // OCR often drops or mangles the "UDYAM" prefix (watermark overlap): rebuild from the tail.
    final m = RegExp(r'([A-Z]{2})-?([0O]{2}|\d{2})-?(\d{7})$').firstMatch(s);
    if (m != null && !s.startsWith('UDYAM-')) return 'UDYAM-${m[1]}-${m[2]!.replaceAll('O', '0')}-${m[3]}';
    return s;
  }

  static bool isValidFormat(String u) => _pattern.hasMatch(u);

  /// UDYAM-KL-00-3078801 -> UDYAM-KL-••-•••8801
  static String mask(String u) => u.length < 19 ? '•••' : '${u.substring(0, 9)}••-•••${u.substring(15)}';
}

/// Mask any ID-like token, keeping the last 4 characters.
String maskTail(String v, {int keep = 4}) =>
    v.length <= keep ? '•' * v.length : '${'•' * (v.length - keep)}${v.substring(v.length - keep)}';
