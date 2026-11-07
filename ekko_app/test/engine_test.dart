import 'dart:io';

import 'package:ekko/engine/bundle.dart';
import 'package:ekko/engine/catalogue.dart';
import 'package:ekko/engine/eligibility.dart';
import 'package:ekko/engine/identifiers.dart';
import 'package:ekko/engine/pricing.dart';
import 'package:ekko/engine/profile.dart';
import 'package:ekko/engine/propensity.dart';
import 'package:ekko/engine/recommender.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogue = Catalogue.fromJsonString(File('assets/data/catalogue.json').readAsStringSync());
  final rec = Recommender(catalogue);
  final rules = EligibilityEngine(catalogue);
  final pricing = PricingEngine(catalogue);

  Set<String> ids(Bundle b) => b.activeIds;
  void expectValid(Bundle b, BusinessProfile p) =>
      expect(rules.validate(b.activeIds, p), isEmpty, reason: 'bundle must satisfy every catalogue rule');

  group('GSTIN', () {
    test('valid mock GSTINs pass format and checksum (4th PAN char X)', () {
      expect(Gstin.isValid('37IHKXV5167L1ZS'), isTrue);
      expect(Gstin.isValid('08YKZXS5189L1ZO'), isTrue);
    });
    test('tampered K06 GSTIN fails checksum', () {
      expect(Gstin.hasValidFormat('08YKZXS8189L1Z0'), isTrue);
      expect(Gstin.hasValidChecksum('08YKZXS8189L1Z0'), isFalse);
    });
    test('masking', () => expect(Gstin.mask('37IHKXV5167L1ZS'), '37IHK••••••L1ZS'));
    test('every registry GSTIN is valid', () {
      final raw = File('assets/data/gstin_registry.json').readAsStringSync();
      final all = RegExp(r'"(\d{2}[A-Z0-9]{13})"').allMatches(raw).map((m) => m[1]!).toList();
      expect(all.length, 3534);
      expect(all.every(Gstin.isValid), isTrue);
    });
  });

  group('Advisor scenarios', () {
    test('1. Tier-2 kirana, no GSTIN, hotspot -> fibre + 2 lines + POS', () {
      final p = BusinessProfile(businessType: 'Kirana store', segment: Segment.micro, employees: 2, cityTier: 2);
      final b = rec.recommend(p);
      expect(ids(b), containsAll(['P01', 'P07', 'P19']));
      expect(b.item('P07')!.qty, 2);
      expectValid(b, p);
      final q = pricing.quote(b);
      expect(q.monthly, inInclusiveRange(1600, 3000));
      expect(q.contractMonths, 12);
    });

    test('2. No GSTIN asks for WhatsApp API -> website instead + upgrade path', () {
      final p = BusinessProfile(
          businessType: 'Boutique', segment: Segment.micro, employees: 3, needs: {Need.whatsapp, Need.upiPos});
      final b = rec.recommend(p);
      expect(ids(b), isNot(contains('P15')));
      expect(ids(b), contains('P18'));
      expect(b.notices.any((n) => n.kind == NoticeKind.upgradePath && n.productId == 'P15'), isTrue);
      expectValid(b, p);
    });

    test('3. Dental clinic tier 1 with GSTIN -> office bundle', () {
      final p = BusinessProfile(
          businessType: 'Dental clinic', segment: Segment.prof, employees: 14, gstStatus: GstStatus.active);
      final b = rec.recommend(p);
      expect(ids(b), containsAll(['P02', 'P08', 'P16', 'P20', 'P17']));
      expect(b.item('P16')!.qty, 14);
      expectValid(b, p);
    });

    test('4. Tier-2 CA firm wants 1 Gbps -> Fibre 300', () {
      final p = BusinessProfile(
          businessType: 'CA firm', segment: Segment.prof, employees: 30, cityTier: 2, gstStatus: GstStatus.active);
      final b = rec.recommend(p);
      // Force a 1G request through revalidation.
      b.items.add(LineItem('P03', 1, origin: Origin.user));
      b.items.removeWhere((i) => i.productId == 'P02');
      rec.revalidate(b, p);
      expect(ids(b), isNot(contains('P03')));
      expect(ids(b), contains('P02'));
      expect(b.notices.any((n) => n.productId == 'P03' && n.block == Block.tier), isTrue);
      expectValid(b, p);
    });

    test('5. 8-employee office asks for leased line -> fibre + failover', () {
      final p = BusinessProfile(
          businessType: 'Architecture studio',
          segment: Segment.prof,
          employees: 8,
          gstStatus: GstStatus.active,
          needs: {Need.dedicatedLine});
      final b = rec.recommend(p);
      expect(ids(b), isNot(contains('P05')));
      expect(ids(b), containsAll(['P02', 'P09']));
      expectValid(b, p);
    });

    test('6. 2-site chain asks for SD-WAN -> failover per site', () {
      final p = BusinessProfile(
          businessType: 'Restaurant chain',
          segment: Segment.multi,
          employees: 20,
          sites: 2,
          gstStatus: GstStatus.active,
          needs: {Need.multiSiteMgmt});
      final b = rec.recommend(p);
      expect(ids(b), isNot(contains('P10')));
      expect(b.item('P09')!.qty, 2);
      expectValid(b, p);
    });

    test('7. 6-site retail chain with GSTIN -> full chain bundle', () {
      final p = BusinessProfile(
          businessType: 'Apparel retail chain',
          segment: Segment.multi,
          employees: 60,
          sites: 6,
          gstStatus: GstStatus.active,
          needs: {Need.upiPos, Need.cctv, Need.failover, Need.multiSiteMgmt, Need.tollFree, Need.whatsapp});
      final b = rec.recommend(p);
      expect(ids(b), containsAll(['P02', 'P09', 'P19', 'P23', 'P10', 'P13', 'P15', 'P08']));
      expect(b.item('P10')!.qty, 6);
      expectValid(b, p);
      final q = pricing.quote(b);
      expect(q.contractMonths, 24);
      expect(q.contractDrivenBy, 'P10');
      expect(q.monthly, greaterThan(20000));
    });

    test('8. 85-staff auto-parts unit -> leased line 100 + firewall + IoT; static IP gets fibre', () {
      final p = BusinessProfile(
          businessType: 'Auto-parts unit',
          segment: Segment.mfg,
          employees: 85,
          gstStatus: GstStatus.active,
          needs: {Need.dedicatedLine, Need.firewall, Need.machineIot, Need.cloudEmail, Need.staticIp});
      final b = rec.recommend(p);
      expect(ids(b), containsAll(['P06', 'P21', 'P24', 'P08', 'P16', 'P11']));
      expect(ids(b).intersection({'P01', 'P02', 'P03'}), isNotEmpty, reason: 'static IP needs fibre');
      expectValid(b, p);
    });

    test('10. CCTV only -> connectivity auto-added', () {
      final p = BusinessProfile(businessType: 'Pharmacy', segment: Segment.micro, employees: 3, needs: {Need.cctv});
      final b = rec.recommend(p);
      expect(ids(b), containsAll(['P23', 'P01']));
      expectValid(b, p);
    });

    test('11. Cancelled GSTIN is treated as no GSTIN', () {
      final p = BusinessProfile(
          businessType: 'Travel agency',
          segment: Segment.prof,
          employees: 12,
          gstStatus: GstStatus.cancelled,
          needs: {Need.telephony, Need.sms, Need.cloudEmail, Need.firewall});
      final b = rec.recommend(p);
      expect(ids(b).intersection({'P12', 'P14', 'P21', 'P03', 'P05', 'P06'}), isEmpty);
      expectValid(b, p);
    });

    test('13. Fibre not feasible -> AirFiber; failover and static IP removed', () {
      final p = BusinessProfile(
          businessType: 'Coaching centre',
          segment: Segment.prof,
          employees: 6,
          fibreFeasible: false,
          needs: {Need.failover, Need.staticIp, Need.cloudEmail});
      final b = rec.recommend(p);
      expect(ids(b), contains('P04'));
      expect(ids(b).intersection({'P01', 'P02', 'P03', 'P09', 'P11'}), isEmpty);
      expect(b.notices.where((n) => n.kind == NoticeKind.blocked).map((n) => n.productId), containsAll(['P09', 'P11']));
      expectValid(b, p);
    });

    test('14. Mobile only -> just a line, no lock-in', () {
      final p = BusinessProfile(businessType: 'Salon', segment: Segment.micro, employees: 1, mobileOnly: true);
      final b = rec.recommend(p);
      expect(ids(b), {'P07'});
      expect(pricing.quote(b).noLockIn, isTrue);
    });

    test('15. Budget cap trims optional add-ons', () {
      final p = BusinessProfile(
          businessType: 'Bakery',
          segment: Segment.micro,
          employees: 4,
          budget: 2000,
          needs: {Need.upiPos, Need.cctv, Need.guestWifi, Need.website});
      final b = rec.recommend(p);
      expect(pricing.quote(b).monthly, lessThanOrEqualTo(2000));
      expect(ids(b), containsAll(['P01', 'P07']));
    });

    test('Secure Wi-Fi with only a leased line gets an access line', () {
      final p = BusinessProfile(
          businessType: 'Textile unit',
          segment: Segment.mfg,
          employees: 40,
          gstStatus: GstStatus.active,
          needs: {Need.dedicatedLine, Need.guestWifi});
      final b = rec.recommend(p);
      expect(ids(b), contains('P22'));
      expectValid(b, p);
    });

    test('every segment default bundle is valid for many profiles', () {
      for (final seg in Segment.values) {
        for (final emp in [1, 3, 9, 10, 24, 25, 60]) {
          for (final sites in [1, 2, 3, 8]) {
            for (final tier in [1, 2]) {
              for (final gst in GstStatus.values) {
                for (final feasible in [true, false]) {
                  final p = BusinessProfile(
                      segment: seg,
                      employees: emp,
                      sites: sites,
                      cityTier: tier,
                      gstStatus: gst,
                      fibreFeasible: feasible,
                      needs: Need.values.toSet());
                  final b = rec.recommend(p);
                  expectValid(b, p);
                  expect(b.activeIds, isNotEmpty);
                }
              }
            }
          }
        }
      }
    });
  });

  group('Pricing', () {
    test('setup is sum of setup x qty; contract is the max minimum', () {
      final b = Bundle([
        LineItem('P01', 2, origin: Origin.core),
        LineItem('P23', 3, origin: Origin.need),
        LineItem('P19', 1, origin: Origin.need),
      ], []);
      final q = pricing.quote(b);
      expect(q.setup, 3 * 1800 + 2500);
      expect(q.contractMonths, 12);
      expect(q.monthly, 2 * 1099 + 3 * 249 + 749);
    });
    test('24-month term is cheaper', () {
      final b = Bundle([LineItem('P02', 1, origin: Origin.core), LineItem('P08', 2, origin: Origin.core)], []);
      expect(pricing.contractOptions(b), [12, 24]);
      expect(pricing.longTermSaving(b), greaterThan(0));
    });
  });

  group('Propensity', () {
    final m = PropensityModel.fromJsonString(File('assets/data/propensity_model.json').readAsStringSync());
    test('referral manufacturer with GSTIN outranks WhatsApp micro without', () {
      final hi = m.score({
        'lead_source': 'Referral',
        'segment': 'Small manufacturers',
        'gst_status': 'Active',
        'city_tier': '1'
      }, employees: 80, sites: 1, spend: 15000);
      final lo = m.score({
        'lead_source': 'WhatsApp campaign',
        'segment': 'Micro retail & services',
        'gst_status': 'none',
        'city_tier': '2'
      }, employees: 2, sites: 1, spend: 600);
      expect(hi, greaterThan(lo * 3));
      expect(m.cvAuc, greaterThan(0.65));
    });
  });
}
