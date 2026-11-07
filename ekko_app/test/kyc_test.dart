import 'dart:io';
import 'dart:math';

import 'package:ekko/engine/doc_parser.dart';
import 'package:ekko/engine/identifiers.dart';
import 'package:ekko/engine/kyc.dart';
import 'package:ekko/engine/registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fields as printed on the 12 specimen applicants (what a perfect OCR reads).
const _gst = {
  'K01': ['37IHKXV5167L1ZS', 'Neha Kaur (Prop. Vindhya Tours & Travels)', 'Vindhya Tours & Travels', 'Shop/Unit 1, Tech Park Road, Visakhapatnam, Andhra Pradesh - 118383'],
  'K02': ['19EOGXH4115Y1ZL', 'Joseph Shah (Prop. Harmony Dental Care)', 'Harmony Dental Care', 'Shop/Unit 199, Station Road, Kolkata, West Bengal - 347550'],
  'K03': ['27XUIXG0767D1ZP', 'Joseph Singh (Prop. Ganesh Woodcraft)', 'Ganesh Woodcraft', 'Shop/Unit 80, Civil Lines, Nagpur, Maharashtra - 411231'],
  'K05': ['32TZAXB5481U1Z1', 'Balaji Realty LLP', 'Balaji Realty LLP', 'Shop/Unit 38, Civil Lines, Kochi, Kerala - 752083'],
  'K06': ['08YKZXS8189L1Z0', 'Pooja Shah (Prop. Saffron Unisex Salon)', 'Saffron Unisex Salon', 'Shop/Unit 71, Market Yard, Jaipur, Rajasthan - 194057'],
  'K07': ['07CPCXN0398P1ZT', 'Neha Banerjee (Prop. Shri Physio Clinic)', 'Neelgiri Physio Clinic', 'Shop/Unit 52, Transport Nagar, Delhi, Delhi - 334596'],
  'K08': ['24XORXG9365M1Z3', 'Joseph Rao (Prop. Green Leaf Legal Associates)', 'Green Leaf Legal Associates', 'Shop/Unit 238, Ring Road, Vadodara, Gujarat - 348176'],
  'K09': ['37LDYXK0296F1ZB', 'Anita Kulkarni (Prop. Kaveri Insurance Advisors)', 'Kaveri Insurance Advisors', 'Shop/Unit 217, Civil Lines, Visakhapatnam, Andhra Pradesh - 405337'],
  'K10': ['27QHJXK0658U1ZL', 'Kaveri Stays LLP', 'Kaveri Stays LLP', 'Shop/Unit 21, Sector 14, Mumbai, Maharashtra - 570043'],
  'K11': ['03KGZXT1320R1ZZ', 'Trinity Bake House Pvt Ltd', 'Trinity Bake House Pvt Ltd', 'Shop/Unit 188, Industrial Area Phase 2, Ludhiana, Punjab - 541498'],
  'K12': ['37NBLXS1145E1ZU', 'Pooja Agarwal (Prop. Star Electronics)', 'Star Electronics', 'Shop/Unit 216, Nehru Nagar, Visakhapatnam, Andhra Pradesh - 762071'],
};
const _udyam = {
  'K01': ['', 'Vindhya Tours & Travels', 'Services'],
  'K02': ['UDYAM-WB-00-5053330', 'Harmony Dental Care', 'Services'],
  'K03': ['UDYAM-MH-00-9516696', 'Ganesh Woodcraft', 'Manufacturing'],
  'K04': ['UDYAM-MH-00-6131836', 'Saffron Dental Care LLP', 'Services'],
  'K06': ['UDYAM-RJ-00-6577157', 'Saffron Unisex Salon', 'Services'],
  'K07': ['UDYAM-DL-00-9565547', 'Neelgiri Physio Clinic', 'Services'],
  'K08': ['UDYAM-GJ-00-8477445', 'Green Leaf Legal Associates', 'Services'],
  'K09': ['UDYAM-AP-00-9751562', 'Kaveri Insurance Advisors', 'Services'],
  'K10': ['UDYAM-MH-00-7183141', 'Kaveri Stays LLP', 'Services'],
  'K11': ['UDYAM-PB-00-9719478', 'Trinity Bake House Pvt Ltd', 'Services'],
  'K12': ['UDYAM-AP-00-5186772', 'Star Electronics', 'Services'],
};
const _id = {
  'K01': ['Neha Kaur', 'Office admin', 'Vindhya Tours & Travels', '2028-03-26'],
  'K02': ['Joseph Shah', 'Manager', 'Harmony Dental Care', '2028-09-10'],
  'K03': ['Joseph Singh', 'Owner', 'Ganesh Woodcraft', '2028-07-04'],
  'K04': ['Fatima Pillai', 'Partner', 'Saffron Dental Care LLP', '2028-08-03'],
  'K05': ['Anita Shah', 'Owner', 'Balaji Realty LLP', '2029-09-11'],
  'K06': ['Pooja Shah', 'Owner', 'Saffron Unisex Salon', '2028-09-15'],
  'K07': ['Neha Banerjee', 'Manager', 'Neelgiri Physio Clinic', '2030-05-05'],
  'K08': ['Joseph Rao', 'Office admin', 'Green Leaf Legal Associates', '2027-09-18'],
  'K09': ['Anita Kulkarni', 'Office admin', 'Kaveri Insurance Advisors', '2027-12-22'],
  'K10': ['Nisha Arora', 'Owner', 'Kaveri Stays LLP', '2029-06-01'],
  'K11': ['Vikram Pillai', 'Owner', 'Trinity Bake House Pvt Ltd', '2028-12-23'],
  'K12': ['Pooja Agarwal', 'Owner', 'Star Electronics', '2029-03-03'],
};
const _bill = {
  'K01': ['Vindhya Tours & Travels', '2026-06-26'],
  'K02': ['Harmony Dental Care', '2026-05-22'],
  'K03': ['Ganesh Woodcraft', '2026-05-30'],
  'K04': ['Saffron Dental Care LLP', '2026-05-28'],
  'K05': ['Balaji Realty LLP', '2026-06-11'],
  'K06': ['Saffron Unisex Salon', '2026-06-11'],
  'K07': ['Neelgiri Physio Clinic', '2026-07-05'],
  'K08': ['Green Leaf Legal Associates', '2026-05-26'],
  'K09': ['Kaveri Insurance Advisors', '2026-07-10'],
  'K10': ['Kaveri Stays LLP', '2026-06-18'],
  'K11': ['Trinity Bake House Pvt Ltd', '2025-10-31'],
  'K12': ['Star Electronics', '2026-07-06'],
};
const _address = {
  'K04': 'Shop/Unit 75, Lake View Colony, Nagpur, Maharashtra - 137452',
};

Map<DocType, ExtractedDoc> applicant(String k) {
  final docs = <DocType, ExtractedDoc>{};
  final g = _gst[k];
  final addr = g?[3] ?? _address[k]!;
  if (g != null) {
    docs[DocType.gstCertificate] = ExtractedDoc(DocType.gstCertificate,
        {'gstin': g[0], 'legalName': g[1], 'tradeName': g[2], 'constitution': '', 'address': g[3]},
        rotationDegrees: k == 'K02' ? -7 : 0);
  } else {
    // K04: blurred GST certificate — almost nothing readable.
    docs[DocType.gstCertificate] = const ExtractedDoc(DocType.gstCertificate, {}, readability: 0.1);
  }
  final u = _udyam[k];
  if (u != null) {
    docs[DocType.udyamCertificate] =
        ExtractedDoc(DocType.udyamCertificate, {'number': u[0], 'enterpriseName': u[1], 'majorActivity': u[2]});
  }
  final i = _id[k]!;
  docs[DocType.signatoryId] = ExtractedDoc(DocType.signatoryId,
      {'name': i[0], 'designation': i[1], 'forBusiness': i[2], 'validTill': i[3]});
  final b = _bill[k]!;
  docs[DocType.addressProof] =
      ExtractedDoc(DocType.addressProof, {'billedTo': b[0], 'billDate': b[1], 'address': addr});
  return docs;
}

void main() {
  final registry = Registry.fromJson(File('assets/data/gstin_registry.json').readAsStringSync(),
      File('assets/data/udyam_registry.json').readAsStringSync());
  final v = KycValidator(registry);

  const expected = {
    'K01': (Verdict.rejected, ['gst_status', 'udyam_number', 'id_role']),
    'K02': (Verdict.approved, ['rotation_gstCertificate']),
    'K03': (Verdict.approved, <String>[]),
    'K04': (Verdict.actionNeeded, ['quality_gstCertificate']),
    'K05': (Verdict.actionNeeded, ['udyam_missing', 'id_role']),
    'K06': (Verdict.rejected, ['gst_checksum']),
    'K07': (Verdict.rejected, ['gst_legal_name']),
    'K08': (Verdict.actionNeeded, ['id_role']),
    'K09': (Verdict.actionNeeded, ['id_role']),
    'K10': (Verdict.actionNeeded, ['id_role', 'udyam_activity']),
    'K11': (Verdict.actionNeeded, ['bill_age', 'id_role']),
    'K12': (Verdict.approved, ['udyam_activity']),
  };

  for (final e in expected.entries) {
    test('${e.key} -> ${e.value.$1.name}', () {
      final r = v.validate(applicant(e.key));
      final flagged = r.checks.where((c) => c.severity != Severity.pass).map((c) => c.id).toSet();
      expect(r.verdict, e.value.$1, reason: r.checks.map((c) => '${c.severity.name}:${c.id} ${c.message}').join('\n'));
      expect(flagged, containsAll(e.value.$2));
    });
  }

  group('OCR repair (strings seen from ML Kit on the specimens)', () {
    bool exists(String g) => registry.gstin(g) != null;
    test('K02 0/O confusion in PAN letters', () => expect(Gstin.ocrRepair('19E0GXH4115Y1ZL', exists: exists), '19EOGXH4115Y1ZL'));
    test('K05 U read as 0, with a stray space', () => expect(Gstin.ocrRepair('32TZAXB548 101Z1', exists: exists), '32TZAXB5481U1Z1'));
    test('K06 tampered digit is NOT repaired', () {
      final r = Gstin.ocrRepair('08YKZXS8189L1Zo', exists: exists);
      expect(Gstin.hasValidChecksum(r) && exists(r), isFalse);
    });
    test('Udyam prefix rebuilt and spaces removed', () {
      expect(Udyam.normalise('-MH-00-9516696'), 'UDYAM-MH-00-9516696');
      expect(Udyam.normalise('-WB- 00-5053330'), 'UDYAM-WB-00-5053330');
      expect(Udyam.normalise('UDYAM-RJ- 00-6577 157'), 'UDYAM-RJ-00-6577157');
    });
  });

  group('DocParser', () {
    List<Point<double>> rect(double x, double y, double w, double h, double deg) {
      final r = deg * pi / 180;
      Point<double> rot(double px, double py) => Point(px * cos(r) - py * sin(r), px * sin(r) + py * cos(r));
      return [rot(x, y), rot(x + w, y), rot(x + w, y + h), rot(x, y + h)];
    }

    List<OcrLine> gstPage(double deg) {
      final rows = [
        ['GSTIN', '37IHKXV5167L1ZS'],
        ['Legal name', 'Neha Kaur (Prop. Vindhya Tours & Travels)'],
        ['Trade name', 'Vindhya Tours & Travels'],
        ['Constitution', 'Proprietorship'],
        ['Address of principal', 'Shop/Unit 1, Tech Park Road, Visakhapatnam, A'],
        ['place of business', 'ndhra Pradesh - 118383'],
        ['Date of liability', '2025-06-07'],
        ['Type of registration', 'Regular'],
      ];
      return [
        OcrLine('Specimen: GST Registration Certificate', rect(80, 80, 880, 40, deg)),
        OcrLine('SYNTHETIC SPECIMEN - NOT A VALID DOCUM', rect(100, 400, 900, 40, deg - 25)),
        for (var i = 0; i < rows.length; i++) ...[
          OcrLine(rows[i][0], rect(90, 250.0 + i * 70, 260, 26, deg)),
          OcrLine(rows[i][1], rect(520, 252.0 + i * 70, 560, 26, deg)),
        ],
      ];
    }

    for (final deg in [0.0, -7.0, 5.0]) {
      test('GST certificate parsed at ${deg.toStringAsFixed(0)}°', () {
        final d = DocParser().parse(DocType.gstCertificate, gstPage(deg));
        expect(d['gstin'], '37IHKXV5167L1ZS');
        expect(d['legalName'], 'Neha Kaur (Prop. Vindhya Tours & Travels)');
        expect(d['address'], 'Shop/Unit 1, Tech Park Road, Visakhapatnam, Andhra Pradesh - 118383');
        expect(d['dateOfLiability'], '2025-06-07');
        expect(d.readability, 1.0);
        expect(d.rotationDegrees, closeTo(deg, 0.01));
      });
    }

    test('Udyam with clipped and hidden labels (real K03 OCR layout)', () {
      final lines = [
        OcrLine('Udyam reg. number', rect(92, 255, 260, 26, 0)),
        OcrLine('Enterprise', rect(92, 325, 140, 26, 0)),
        OcrLine('Major activity', rect(92, 395, 180, 26, 0)),
        OcrLine('C', rect(115, 426, 20, 26, -16.5)),
        OcrLine('State', rect(92, 534, 70, 26, 0)),
        OcrLine('Date of registration', rect(92, 605, 260, 26, 0)),
        OcrLine('CcEN - NOUDYAN', rect(210, 354, 300, 30, -18.1)),
        OcrLine('-MH-00-9516696', rect(605, 256, 300, 26, 0)),
        OcrLine('Ganesh Woodcraft', rect(521, 325, 250, 26, 0)),
        OcrLine('Manufacturing', rect(522, 392, 200, 26, 0.6)),
        OcrLine('Nagpur', rect(522, 466, 100, 26, 0)),
        OcrLine('Maharashtra', rect(522, 535, 160, 26, 0)),
        OcrLine('2024-11-21', rect(522, 605, 150, 26, -0.8)),
      ];
      final d = DocParser().parse(DocType.udyamCertificate, lines);
      expect(Udyam.normalise(d['number']!), 'UDYAM-MH-00-9516696');
      expect(d['enterpriseName'], 'Ganesh Woodcraft');
      expect(d['city'], 'Nagpur');
      expect(d['state'], 'Maharashtra');
      expect(d.readability, 1.0);
    });

    test('signatory card (label above value)', () {
      final rows = [
        ['Name', 'Neha Kaur'],
        ['Designation', 'Office admin'],
        ['For business', 'Vindhya Tours & Travels'],
        ['ID no.', 'SYN-ID-346190'],
        ['Valid tilI', '2028-03-26'],
      ];
      final lines = [
        for (var i = 0; i < rows.length; i++) ...[
          OcrLine(rows[i][0], rect(340, 132.0 + i * 70, 80, 20, 0)),
          OcrLine(rows[i][1], rect(340, 158.0 + i * 70, 300, 26, 0)),
        ],
      ];
      final d = DocParser().parse(DocType.signatoryId, lines);
      expect(d['name'], 'Neha Kaur');
      expect(d['designation'], 'Office admin');
      expect(d['validTill'], '2028-03-26');
      expect(d.readability, 1.0);
    });
  });
}
