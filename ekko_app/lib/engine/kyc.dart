import 'identifiers.dart';
import 'registry.dart';

enum DocType { gstCertificate, udyamCertificate, signatoryId, addressProof }

/// Fields read from one document, plus image-quality signals from OCR.
class ExtractedDoc {
  final DocType type;
  final Map<String, String> fields;

  /// Share of expected fields that were readable (0..1).
  final double readability;
  final double rotationDegrees;
  const ExtractedDoc(this.type, this.fields, {this.readability = 1, this.rotationDegrees = 0});

  String? operator [](String k) {
    final v = fields[k]?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  Map<String, dynamic> toJson() =>
      {'type': type.name, 'fields': fields, 'readability': readability, 'rotation': rotationDegrees};

  factory ExtractedDoc.fromJson(Map<String, dynamic> j) => ExtractedDoc(
        DocType.values.byName(j['type']),
        Map<String, String>.from(j['fields']),
        readability: (j['readability'] as num).toDouble(),
        rotationDegrees: (j['rotation'] as num).toDouble(),
      );
}

/// fail = hard stop, action = owner must fix something, warn = noted, pass = ok.
enum Severity { pass, info, warn, action, fail }

class Check {
  final String id;
  final Severity severity;
  final String message;
  final String? fix;
  const Check(this.id, this.severity, this.message, {this.fix});
  Map<String, dynamic> toJson() => {'id': id, 'severity': severity.name, 'message': message, 'fix': fix};
  factory Check.fromJson(Map<String, dynamic> j) =>
      Check(j['id'], Severity.values.byName(j['severity']), j['message'], fix: j['fix']);
}

enum Verdict { approved, actionNeeded, rejected }

class KycReport {
  final List<Check> checks;
  final GstRecord? gst;
  final UdyamRecord? udyam;
  const KycReport(this.checks, this.gst, this.udyam);

  Verdict get verdict {
    if (checks.any((c) => c.severity == Severity.fail)) return Verdict.rejected;
    if (checks.any((c) => c.severity == Severity.action)) return Verdict.actionNeeded;
    return Verdict.approved;
  }

  Iterable<Check> get problems => checks.where((c) => c.severity.index >= Severity.warn.index);
}

/// Smart KYC rules. All decisions are deterministic; OCR only supplies fields.
class KycValidator {
  final Registry registry;

  /// The README fixes "today" at 2026-07-15 for date checks.
  final DateTime today;
  static const maxAddressProofAgeDays = 90;
  static const minReadability = 0.6;

  KycValidator(this.registry, {DateTime? today}) : today = today ?? DateTime(2026, 7, 15);

  /// [gstRequired]: the order contains GST-only products (or the owner gave a GSTIN).
  KycReport validate(Map<DocType, ExtractedDoc> docs, {bool gstRequired = true}) {
    final out = <Check>[];
    final gstDoc = docs[DocType.gstCertificate];
    final udyamDoc = docs[DocType.udyamCertificate];
    final idDoc = docs[DocType.signatoryId];
    final billDoc = docs[DocType.addressProof];

    // Image quality first: an unreadable scan is a re-upload, not a rejection.
    for (final d in docs.values) {
      if (d.readability < minReadability) {
        out.add(Check('quality_${d.type.name}', Severity.action, '${_label(d.type)} is too blurry to read.',
            fix: 'Retake the photo in good light, flat and in focus.'));
      } else if (d.rotationDegrees.abs() >= 2) {
        out.add(Check('rotation_${d.type.name}', Severity.info,
            '${_label(d.type)} was tilted ${d.rotationDegrees.abs().toStringAsFixed(0)}° — straightened automatically.'));
      }
    }
    bool readable(ExtractedDoc? d) => d != null && d.readability >= minReadability;

    // ---- GST certificate + GSTN lookup -------------------------------------
    GstRecord? gst;
    if (gstDoc == null) {
      out.add(gstRequired
          ? const Check('gst_missing', Severity.action, 'GST certificate not uploaded.',
              fix: 'Upload the GST registration certificate, or continue without GST (some products need it).')
          : const Check('gst_missing', Severity.info, 'No GST certificate — plan has no GST-only products.'));
    } else if (readable(gstDoc)) {
      final raw = gstDoc['gstin'];
      final g = raw == null ? null : Gstin.ocrRepair(raw, exists: (x) => registry.gstin(x) != null);
      if (raw != null && g != Gstin.normalise(raw)) {
        out.add(Check('gst_ocr_fix', Severity.info,
            'GSTIN look-alike characters corrected from the scan (e.g. 0/O) and confirmed with GSTN.'));
      }
      if (g == null) {
        out.add(const Check('gst_number', Severity.action, 'GSTIN not found on the certificate.',
            fix: 'Type your 15-character GSTIN.'));
      } else if (!Gstin.hasValidFormat(g)) {
        out.add(Check('gst_format', Severity.fail, 'GSTIN ${Gstin.mask(g)} is not a valid GSTIN format.',
            fix: 'Check the number on your certificate.'));
      } else if (!Gstin.hasValidChecksum(g)) {
        out.add(Check('gst_checksum', Severity.fail,
            'GSTIN ${Gstin.mask(g)} fails the GSTN check digit — the number has been altered or mistyped.',
            fix: 'Re-check every character, especially 0/O, 5/S, 8/B.'));
      } else {
        out.add(Check('gst_format', Severity.pass, 'GSTIN ${Gstin.mask(g)} format and check digit valid.'));
        gst = registry.gstin(g);
        if (gst == null) {
          out.add(Check('gst_registry', Severity.fail, 'GSTIN ${Gstin.mask(g)} not found in the GST registry.'));
        } else {
          out.add(gst.isActive
              ? const Check('gst_status', Severity.pass, 'GST registration is Active.')
              : Check('gst_status', Severity.fail, 'GST registration is ${gst.status} in the GST registry.',
                  fix: 'Restore your GST registration on the GST portal, or continue without GST products.'));
          final codeState = Gstin.stateOf(g);
          if (codeState != null && codeState != gst.state) {
            out.add(Check('gst_state', Severity.fail, 'GSTIN state code ($codeState) does not match ${gst.state}.'));
          }
          final legal = gstDoc['legalName'];
          if (legal != null && nameSimilarity(legal, gst.legalName) < 0.8) {
            out.add(Check('gst_legal_name', Severity.fail,
                'Legal name on certificate ("$legal") does not match GST records ("${gst.legalName}").',
                fix: 'Upload the original certificate.'));
          }
          final trade = gstDoc['tradeName'];
          if (trade != null && nameSimilarity(trade, gst.tradeName) < 0.8) {
            out.add(Check('gst_trade_name', Severity.fail,
                'Trade name on certificate does not match GST records ("${gst.tradeName}").'));
          }
          final propTrade = legal == null ? null : proprietorTradeName(legal);
          if (propTrade != null && trade != null && nameSimilarity(propTrade, trade) < 0.8) {
            out.add(Check('gst_internal_name', Severity.fail,
                'Certificate is inconsistent: legal name says "$propTrade" but trade name says "$trade".'));
          }
          // The GSTN record is authoritative for the address; a scan difference is
          // usually OCR noise, so it's noted rather than blocking.
          final addr = gstDoc['address'];
          if (addr != null && !_sameAddress(addr, gst.address)) {
            out.add(const Check('gst_address', Severity.warn,
                'Address on the certificate scan differs slightly from GST records; GST records used.'));
          }
          if (!out.any((c) => c.id.startsWith('gst_') && c.severity == Severity.fail)) {
            out.add(const Check('gst_match', Severity.pass, 'Certificate details match GST records.'));
          }
        }
      }
    }

    // ---- Udyam certificate + Udyam lookup ----------------------------------
    UdyamRecord? udyam;
    if (udyamDoc == null) {
      // GST alone proves the business; without GST, Udyam is the registration we rely on.
      out.add(Check('udyam_missing', gst != null && gst.isActive ? Severity.warn : Severity.action,
          'Udyam certificate not uploaded.',
          fix: 'Upload it, or fetch it from DigiLocker.'));
    } else if (readable(udyamDoc)) {
      final raw = udyamDoc['number'];
      final n = raw == null ? null : Udyam.normalise(raw);
      if (n == null) {
        out.add(const Check('udyam_number', Severity.action, 'Udyam registration number is blank on the certificate.',
            fix: 'Upload a complete Udyam certificate or type the number.'));
      } else if (!Udyam.isValidFormat(n)) {
        out.add(Check('udyam_format', Severity.fail, 'Udyam number ${Udyam.mask(n)} is not a valid format.'));
      } else {
        udyam = registry.udyam(n);
        if (udyam == null) {
          out.add(Check('udyam_registry', Severity.fail, 'Udyam ${Udyam.mask(n)} not found in the Udyam registry.'));
        } else {
          out.add(Check('udyam_registry', Severity.pass, 'Udyam ${Udyam.mask(n)} found.'));
          final name = udyamDoc['enterpriseName'];
          if (name != null && nameSimilarity(name, udyam.enterpriseName) < 0.8) {
            out.add(const Check('udyam_name', Severity.fail, 'Enterprise name does not match Udyam records.'));
          }
          if (gst != null && nameSimilarity(udyam.enterpriseName, gst.tradeName) < 0.8) {
            out.add(const Check('udyam_vs_gst', Severity.fail,
                'Udyam registration belongs to a different business than the GSTIN.'));
          }
          if (gst != null && udyam.state != gst.state) {
            out.add(Check('udyam_state', Severity.warn, 'Udyam state (${udyam.state}) differs from GST state (${gst.state}).'));
          }
          final act = udyamDoc['majorActivity'];
          if (act != null && act.toLowerCase() != udyam.majorActivity.toLowerCase()) {
            out.add(Check('udyam_activity', Severity.warn,
                'Activity on certificate ($act) differs from Udyam records (${udyam.majorActivity}).'));
          }
        }
      }
    }

    // ---- Authorised signatory ---------------------------------------------
    if (idDoc == null) {
      out.add(const Check('id_missing', Severity.action, 'Authorised signatory ID not uploaded.'));
    } else if (readable(idDoc)) {
      final validTill = _date(idDoc['validTill']);
      if (validTill != null && validTill.isBefore(today)) {
        out.add(const Check('id_expired', Severity.action, 'Signatory ID has expired.', fix: 'Upload a valid ID.'));
      }
      final biz = idDoc['forBusiness'];
      final tradeRef = gst?.tradeName ?? gstDoc?['tradeName'];
      if (biz != null && tradeRef != null && nameSimilarity(biz, tradeRef) < 0.8) {
        out.add(const Check('id_business', Severity.fail, 'Signatory ID is for a different business.'));
      }
      out.add(_signatoryCheck(idDoc, gst));
    }

    // ---- Address proof -------------------------------------------------------
    if (billDoc == null) {
      out.add(const Check('bill_missing', Severity.action, 'Address proof not uploaded.'));
    } else if (readable(billDoc)) {
      final date = _date(billDoc['billDate']);
      if (date == null) {
        out.add(const Check('bill_date', Severity.action, 'Bill date not readable.'));
      } else {
        final age = today.difference(date).inDays;
        out.add(age > maxAddressProofAgeDays
            ? Check('bill_age', Severity.action,
                'Address proof is $age days old (dated ${_fmt(date)}); it must be within $maxAddressProofAgeDays days.',
                fix: 'Upload your latest electricity, water or phone bill.')
            : Check('bill_age', Severity.pass, 'Address proof is recent ($age days old).'));
      }
      final billed = billDoc['billedTo'];
      final tradeRef = gst?.tradeName ?? gstDoc?['tradeName'];
      if (billed != null && tradeRef != null && nameSimilarity(billed, tradeRef) < 0.8) {
        out.add(const Check('bill_name', Severity.fail, 'Bill is in a different name from the business.'));
      }
      final addr = billDoc['address'];
      final ref = gst?.address ?? gstDoc?['address'];
      if (addr != null && ref != null) {
        out.add(_sameAddress(addr, ref)
            ? const Check('bill_address', Severity.pass, 'Bill address matches the GST address.')
            : const Check('bill_address', Severity.fail, 'Bill address does not match the GST address.'));
      }
    }

    out.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return KycReport(out, gst, udyam);
  }

  Check _signatoryCheck(ExtractedDoc id, GstRecord? gst) {
    final role = (id['designation'] ?? '').toLowerCase();
    final name = id['name'] ?? '';
    final constitution = gst?.constitution ?? '';
    const proprietor = {'owner', 'proprietor'};
    const partner = {'partner', 'designated partner'};
    const director = {'director', 'managing director'};
    if (role.contains('admin')) {
      return Check('id_role', Severity.action, '"${id['designation']}" is not an authorised signatory role.',
          fix: 'The proprietor/partner/director must sign, or upload a board resolution / authorisation letter.');
    }
    if (constitution == 'Limited Liability Partnership' && !partner.contains(role)) {
      return Check('id_role', Severity.action,
          'For an LLP the signatory must be a designated partner, not "${id['designation']}".',
          fix: 'Upload a partner\'s ID or an authorisation letter signed by the partners.');
    }
    if (constitution == 'Private Limited Company' && !director.contains(role)) {
      return Check('id_role', Severity.action,
          'For a private limited company the signatory must be a director, not "${id['designation']}".',
          fix: 'Upload a director\'s ID or a board resolution.');
    }
    if (constitution == 'Proprietorship') {
      final person = gst == null ? null : proprietorPerson(gst.legalName);
      final isProprietor = person != null && nameSimilarity(person, name) >= 0.99;
      if (!isProprietor) {
        return const Check('id_role', Severity.action, 'Signatory is not the registered proprietor.',
            fix: 'The proprietor must sign, or upload an authorisation letter.');
      }
      if (!proprietor.contains(role)) {
        return Check('id_role', Severity.warn,
            'ID shows role "${id['designation']}", but the name matches the registered proprietor — accepted.');
      }
    }
    return const Check('id_role', Severity.pass, 'Signatory is authorised for this business.');
  }

  static bool _sameAddress(String a, String b) {
    String n(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return n(a) == n(b);
  }

  static DateTime? _date(String? s) {
    if (s == null) return null;
    final m = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (m == null) return null;
    return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _label(DocType t) => const {
        DocType.gstCertificate: 'GST certificate',
        DocType.udyamCertificate: 'Udyam certificate',
        DocType.signatoryId: 'Signatory ID',
        DocType.addressProof: 'Address proof',
      }[t]!;
}
