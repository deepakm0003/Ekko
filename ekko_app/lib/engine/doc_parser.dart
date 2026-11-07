import 'dart:math';

import 'kyc.dart';

/// One OCR text line with its four corner points (any OCR engine).
class OcrLine {
  final String text;
  final List<Point<double>> corners; // tl, tr, br, bl
  const OcrLine(this.text, this.corners);

  double get angleDegrees {
    final dx = corners[1].x - corners[0].x;
    final dy = corners[1].y - corners[0].y;
    return atan2(dy, dx) * 180 / pi;
  }
}

class _Box {
  final String text;
  final double left, top, right, bottom;
  _Box(this.text, this.left, this.top, this.right, this.bottom);
  double get cy => (top + bottom) / 2;
  double get h => bottom - top;
}

/// Turns OCR lines into document fields by pairing printed labels with their
/// values, after straightening the page using the label lines' angle.
class DocParser {
  static const _rowLabels = <DocType, Map<String, String>>{
    DocType.gstCertificate: {
      'gstin': 'gstin',
      'legal name': 'legalName',
      'trade name': 'tradeName',
      'constitution': 'constitution',
      'address of principal': 'address',
      'place of business': '_address2',
      'date of liability': 'dateOfLiability',
      'type of registration': 'registrationType',
    },
    DocType.udyamCertificate: {
      'udyam reg': 'number',
      'enterprise name': 'enterpriseName',
      'major activity': 'majorActivity',
      'city': 'city',
      'state': 'state',
      'date of registration': 'registrationDate',
    },
    DocType.addressProof: {
      'consumer no': 'consumerNo',
      'billed to': 'billedTo',
      'supply address': 'address',
      'bill date': 'billDate',
      'units consumed': 'units',
      'amount due': 'amountDue',
    },
  };

  /// ID cards print the label above the value.
  static const _cardLabels = {
    'name': 'name',
    'designation': 'designation',
    'for business': 'forBusiness',
    'id no': 'idNo',
    'valid till': 'validTill',
  };

  static const _expected = <DocType, List<String>>{
    DocType.gstCertificate: ['gstin', 'legalName', 'tradeName', 'constitution', 'address', 'dateOfLiability'],
    DocType.udyamCertificate: ['enterpriseName', 'majorActivity', 'city', 'state', 'registrationDate'],
    DocType.signatoryId: ['name', 'designation', 'forBusiness', 'idNo', 'validTill'],
    DocType.addressProof: ['consumerNo', 'billedTo', 'address', 'billDate'],
  };

  static DocType? detectType(String allText) {
    final t = allText.toLowerCase();
    if (t.contains('gst registration')) return DocType.gstCertificate;
    if (t.contains('udyam registration')) return DocType.udyamCertificate;
    if (t.contains('signatory')) return DocType.signatoryId;
    if (t.contains('bill') || t.contains('consumer no')) return DocType.addressProof;
    return null;
  }

  static bool _isWatermark(String s) {
    final u = s.toUpperCase();
    return u.contains('SPECIMEN') || u.contains('VALID DOC') || u.contains('SYNTHETIC') || u.contains('NOT A VALID');
  }

  /// Matches printed labels even when the watermark clips them ("Trade" for
  /// "Trade name", "onstitution") or OCR swaps a letter ("Valid tilI").
  static String? _labelKey(String text, Map<String, String> labels) {
    final t = text.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return null;
    for (final k in labels.keys) {
      if (t == k || t.startsWith('$k ') || (k.length > 6 && t.startsWith(k))) return k;
    }
    for (final k in labels.keys) {
      if (t.length >= 5 && (k.startsWith(t) || k.endsWith(t))) return k;
      if (k.length >= 5 && _editDistance(t, k) <= 1) return k;
    }
    return null;
  }

  static int _editDistance(String a, String b) {
    if ((a.length - b.length).abs() > 1) return 2;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = [i, ...List<int>.filled(b.length, 0)];
      for (var j = 1; j <= b.length; j++) {
        cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)].reduce(min);
      }
      prev = cur;
    }
    return prev[b.length];
  }

  ExtractedDoc parse(DocType type, List<OcrLine> lines) {
    final labels = type == DocType.signatoryId ? _cardLabels : _rowLabels[type]!;
    final clean = lines.where((l) => l.text.trim().isNotEmpty && !_isWatermark(l.text)).toList();

    // Page rotation = median angle of the printed labels.
    final labelAngles = clean.where((l) => _labelKey(l.text, labels) != null).map((l) => l.angleDegrees).toList()
      ..sort();
    final angle = labelAngles.isEmpty ? 0.0 : labelAngles[labelAngles.length ~/ 2];
    final rad = -angle * pi / 180;
    final boxes = <_Box>[];
    for (final l in clean) {
      // Drop diagonal watermark fragments that didn't contain the keywords.
      if ((l.angleDegrees - angle).abs() > 12) continue;
      final pts = l.corners
          .map((p) => Point(p.x * cos(rad) - p.y * sin(rad), p.x * sin(rad) + p.y * cos(rad)))
          .toList();
      boxes.add(_Box(l.text.trim(), pts.map((p) => p.x).reduce(min), pts.map((p) => p.y).reduce(min),
          pts.map((p) => p.x).reduce(max), pts.map((p) => p.y).reduce(max)));
    }

    final labelBoxes = <String, _Box>{};
    final valueBoxes = <_Box>[];
    for (final b in boxes) {
      final k = _labelKey(b.text, labels);
      if (k != null && !labelBoxes.containsKey(k)) {
        labelBoxes[k] = b;
      } else {
        valueBoxes.add(b);
      }
    }

    // A label hidden completely under the watermark (e.g. "City") is placed
    // between its printed neighbours — the rows are evenly spaced.
    if (type != DocType.signatoryId) {
      final order = labels.keys.toList();
      for (var i = 0; i < order.length; i++) {
        if (labelBoxes.containsKey(order[i])) continue;
        int? p, n;
        for (var j = i - 1; j >= 0; j--) {
          if (labelBoxes.containsKey(order[j])) {
            p = j;
            break;
          }
        }
        for (var j = i + 1; j < order.length; j++) {
          if (labelBoxes.containsKey(order[j])) {
            n = j;
            break;
          }
        }
        if (p == null || n == null) continue;
        final a = labelBoxes[order[p]]!, b = labelBoxes[order[n]]!;
        final cy = a.cy + (b.cy - a.cy) * (i - p) / (n - p);
        labelBoxes[order[i]] = _Box('', a.left, cy - a.h / 2, a.right, cy + a.h / 2);
      }
    }

    final fields = <String, String>{};
    if (type == DocType.signatoryId) {
      for (final e in labelBoxes.entries) {
        final lb = e.value;
        final below = valueBoxes
            .where((v) => v.top >= lb.bottom - lb.h * 0.3 && v.top < lb.bottom + lb.h * 2.2 && v.left < lb.right + lb.h * 2 && v.right > lb.left)
            .toList()
          ..sort((a, b) => a.top.compareTo(b.top));
        if (below.isNotEmpty) fields[labels[e.key]!] = below.first.text;
      }
    } else {
      // Value column starts right of the widest label.
      final valueX = labelBoxes.values.isEmpty ? 0.0 : labelBoxes.values.map((b) => b.right).reduce(max);
      final used = <_Box>{};
      for (final e in labelBoxes.entries) {
        final lb = e.value;
        final row = valueBoxes
            .where((v) => !used.contains(v) && v.left >= valueX - lb.h && (v.cy - lb.cy).abs() < max(lb.h, v.h) * 0.6)
            .toList()
          ..sort((a, b) => a.left.compareTo(b.left));
        used.addAll(row);
        if (row.isNotEmpty) fields[labels[e.key]!] = row.map((b) => b.text).join(' ');
      }
      // Wrapped address on the bill: an unlabelled value row right below.
      if (type == DocType.addressProof && labelBoxes['supply address'] != null && fields['address'] != null) {
        final lb = labelBoxes['supply address']!;
        final next = valueBoxes
            .where((v) => !used.contains(v) && v.left >= valueX - lb.h && v.top > lb.bottom && v.top < lb.bottom + lb.h * 3)
            .toList()
          ..sort((a, b) => a.top.compareTo(b.top));
        if (next.isNotEmpty) fields['address'] = fields['address']! + next.first.text;
      }
      final a2 = fields.remove('_address2');
      if (a2 != null && fields['address'] != null) fields['address'] = fields['address']! + a2;
    }

    // Regex fallbacks for the identifiers that matter most.
    final all = boxes.map((b) => b.text).join('\n');
    if (type == DocType.gstCertificate) {
      final g = RegExp(r'\b\d{2}[A-Z0-9]{13}\b').firstMatch(all.toUpperCase().replaceAll(' ', ''));
      fields['gstin'] = (fields['gstin'] ?? g?.group(0) ?? '').replaceAll(' ', '');
    }
    if (type == DocType.udyamCertificate) {
      final u = RegExp(r'UDYAM-[A-Z]{2}-\d{2}-\d{7}').firstMatch(all.toUpperCase().replaceAll(' ', ''));
      if (u != null) fields['number'] = u.group(0)!;
    }
    fields.removeWhere((k, v) => v.trim().isEmpty);

    final expected = _expected[type]!;
    final found = expected.where((k) => fields.containsKey(k)).length;
    return ExtractedDoc(type, fields, readability: found / expected.length, rotationDegrees: angle);
  }
}
