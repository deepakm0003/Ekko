import 'dart:io';

import 'package:ekko/engine/catalogue.dart';
import 'package:ekko/engine/health.dart';
import 'package:ekko/engine/profile.dart';
import 'package:ekko/engine/recommender.dart';
import 'package:ekko/engine/self_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cat = Catalogue.fromJsonString(File('assets/data/catalogue.json').readAsStringSync());

  test('every in-app self-test scenario passes', () {
    final r = SelfTestRunner(cat);
    for (final t in selfTests) {
      final res = r.run(t);
      expect(res.passed, isTrue, reason: '${t.title}: ${res.products}');
    }
  });

  test('random sweep finds no rule violations', () {
    final (n, bad) = SelfTestRunner(cat).sweep();
    expect(n, 1792);
    expect(bad, 0);
  });

  test('health score improves with the plan', () {
    final p = BusinessProfile(businessType: 'Kirana store', employees: 3, currentInternet: 'Mobile hotspot', needs: {Need.upiPos, Need.cctv});
    final b = Recommender(cat).recommend(p);
    final h = digitalHealth(p, b);
    expect(h.before, lessThan(30));
    expect(h.after, greaterThan(h.before + 30));
    expect(vendorsReplaced(b, (id) => cat[id].category), greaterThanOrEqualTo(3));
  });
}
