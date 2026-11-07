import 'dart:math';

import 'bundle.dart';
import 'profile.dart';

/// "Digital Health Score": how ready the business is today vs with the plan,
/// across the pillars the case segments care about. Simple, explainable rules.
class Pillar {
  final String key;
  final String label;
  final int before;
  final int after;
  const Pillar(this.key, this.label, this.before, this.after);
}

class HealthReport {
  final List<Pillar> pillars;
  const HealthReport(this.pillars);
  int get before => (pillars.fold(0, (s, p) => s + p.before) / pillars.length).round();
  int get after => (pillars.fold(0, (s, p) => s + p.after) / pillars.length).round();
}

HealthReport digitalHealth(BusinessProfile p, Bundle b) {
  final ids = b.activeIds;
  bool has(String id) => ids.contains(id);
  int cap(int v) => min(v, 98);

  final netBefore = switch (p.currentInternet) {
    'Mobile hotspot' => 30,
    'Home broadband' => 48,
    'Business broadband' => 68,
    'Leased line' => 85,
    'Mixed per site' => 55,
    _ => 12,
  };
  final netAfter = has('P06') || has('P03') ? 96 : has('P05') ? 92 : has('P02') ? 86 : has('P01') ? 78 : has('P04') ? 72 : netBefore;

  final relBefore = p.currentInternet == 'Leased line' ? 60 : p.currentInternet == 'Mobile hotspot' ? 15 : 25;
  var relAfter = relBefore;
  if (has('P01') || has('P02') || has('P03') || has('P04')) relAfter = max(relAfter, 55);
  if (has('P05') || has('P06')) relAfter = max(relAfter, 85);
  if (has('P09')) relAfter = 94;
  if (has('P10')) relAfter = cap(relAfter + 4);

  const payBefore = 25; // UPI QR on the owner's phone
  final payAfter = has('P19') ? 92 : payBefore;

  var reach = 15;
  if (has('P07') || has('P08')) reach += 10;
  if (has('P15')) reach += 40;
  if (has('P18')) reach += 25;
  if (has('P14')) reach += 20;
  if (has('P13')) reach += 15;
  if (has('P12')) reach += 15;

  var sec = 10;
  if (has('P20')) sec += 40;
  if (has('P21')) sec += 40;
  if (has('P22')) sec += 25;
  if (has('P23')) sec += 15;

  var prod = 20;
  if (has('P16')) prod += 45;
  if (has('P17')) prod += 30;
  if (has('P24')) prod += 20;
  if (has('P25')) prod += 10;

  final all = {
    'net': Pillar('net', 'Internet speed', netBefore, netAfter),
    'rel': Pillar('rel', 'Always online', relBefore, relAfter),
    'pay': Pillar('pay', 'Billing & payments', payBefore, payAfter),
    'reach': Pillar('reach', 'Reach customers', 15, cap(reach)),
    'sec': Pillar('sec', 'Security', 10, cap(sec)),
    'prod': Pillar('prod', 'Work & data', 20, cap(prod)),
  };
  final keys = switch (p.segment) {
    Segment.micro => ['net', 'rel', 'pay', 'reach', 'sec'],
    Segment.prof => ['net', 'rel', 'reach', 'sec', 'prod'],
    Segment.multi => ['net', 'rel', 'pay', 'reach', 'sec', 'prod'],
    Segment.mfg => ['net', 'rel', 'sec', 'prod'],
  };
  return HealthReport([for (final k in keys) all[k]!]);
}

/// How many separate vendors/bills the bundle replaces (one per category).
int vendorsReplaced(Bundle b, String Function(String id) categoryOf) =>
    b.activeIds.map(categoryOf).toSet().length;
