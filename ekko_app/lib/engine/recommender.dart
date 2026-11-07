import 'dart:math';

import 'bundle.dart';
import 'catalogue.dart';
import 'eligibility.dart';
import 'pricing.dart';
import 'profile.dart';

/// Builds a bundle from a profile, then repairs it until every catalogue rule
/// holds. Quantities follow what activated customers actually bought.
class Recommender {
  final Catalogue catalogue;
  final EligibilityEngine rules;
  final PricingEngine pricing;
  Recommender(this.catalogue)
      : rules = EligibilityEngine(catalogue),
        pricing = PricingEngine(catalogue);

  static const _gstGated = {'P03', 'P05', 'P06', 'P10', 'P12', 'P13', 'P14', 'P15', 'P21', 'P24'};

  /// What to offer instead of a product the business can't have.
  static const substitutes = <String, List<List<String>>>{
    'P03': [
      ['P02'],
    ],
    'P06': [
      ['P05'],
      ['P02', 'P09'],
    ],
    'P05': [
      ['P02', 'P09'],
    ],
    'P01': [
      ['P04'],
    ],
    'P02': [
      ['P04'],
    ],
    'P10': [
      ['P09'],
    ],
    'P21': [
      ['P22', 'P20'],
    ],
    'P15': [
      ['P18'],
    ],
  };

  /// Default needs per segment when the owner doesn't pick any.
  static const defaultNeeds = <Segment, Set<Need>>{
    Segment.micro: {Need.upiPos},
    Segment.prof: {Need.cloudEmail, Need.deviceSecurity, Need.backup},
    Segment.multi: {Need.upiPos, Need.cctv, Need.failover},
    Segment.mfg: {Need.dedicatedLine, Need.cloudEmail, Need.deviceSecurity},
  };

  /// Lowest priority first: what to drop when over budget.
  static const _trimOrder = [
    Need.website, Need.backup, Need.sms, Need.tollFree, Need.guestWifi, Need.fleet, Need.cctv,
    Need.telephony, Need.staticIp, Need.failover, Need.machineIot, Need.deviceSecurity, Need.firewall,
    Need.multiSiteMgmt, Need.whatsapp, Need.cloudEmail, Need.upiPos,
  ];

  Bundle recommend(BusinessProfile p) {
    final items = <LineItem>[];
    final notices = <Notice>[];
    final needs = p.mobileOnly ? <Need>{} : (p.needs.isEmpty ? defaultNeeds[p.segment]! : p.needs);

    if (!p.mobileOnly) {
      final base = _baseConnectivity(p, needs);
      items.add(LineItem(base, _qtyFor(base, p), origin: Origin.core, optional: false));
    }
    final line = p.segment == Segment.micro ? 'P07' : 'P08';
    items.add(LineItem(line, _lineQty(p), origin: Origin.core, optional: !p.mobileOnly));

    for (final need in needs) {
      final id = _productFor(need);
      if (id == null || items.any((i) => i.productId == id)) continue;
      items.add(LineItem(id, _qtyFor(id, p), origin: Origin.need, need: need));
    }

    final bundle = Bundle(items, notices);
    _repair(bundle, p);
    if (p.budget != null) _fitBudget(bundle, p.budget!);
    return bundle;
  }

  /// Re-runs the rules after the owner toggles or adds something.
  void revalidate(Bundle b, BusinessProfile p) => _repair(b, p);

  String _baseConnectivity(BusinessProfile p, Set<Need> needs) {
    if (needs.contains(Need.dedicatedLine) || p.segment == Segment.mfg) {
      return p.employees >= 25 ? 'P06' : 'P05';
    }
    switch (p.segment) {
      case Segment.micro:
        return 'P01';
      case Segment.prof:
        return (p.cityTier == 1 && p.employees >= 20 && p.hasActiveGstin) ? 'P03' : 'P02';
      case Segment.multi:
        return p.employees / max(p.sites, 1) >= 10 ? 'P02' : 'P01';
      case Segment.mfg:
        return 'P05';
    }
  }

  String? _productFor(Need n) => const {
        Need.upiPos: 'P19',
        Need.cctv: 'P23',
        Need.whatsapp: 'P15',
        Need.guestWifi: 'P22',
        Need.cloudEmail: 'P16',
        Need.backup: 'P17',
        Need.deviceSecurity: 'P20',
        Need.firewall: 'P21',
        Need.failover: 'P09',
        Need.multiSiteMgmt: 'P10',
        Need.staticIp: 'P11',
        Need.telephony: 'P12',
        Need.tollFree: 'P13',
        Need.sms: 'P14',
        Need.website: 'P18',
        Need.machineIot: 'P24',
        Need.fleet: 'P25',
      }[n];

  int _lineQty(BusinessProfile p) {
    if (p.segment == Segment.micro) return p.employees >= 2 ? 2 : 1;
    return min(max((p.employees / 10).ceil(), 1), 6);
  }

  int _qtyFor(String id, BusinessProfile p) {
    final sites = max(p.sites, 1);
    switch (id) {
      case 'P03':
      case 'P05':
      case 'P06':
      case 'P11':
      case 'P13':
      case 'P14':
      case 'P15':
      case 'P17':
      case 'P18':
        return 1;
      case 'P07':
      case 'P08':
        return _lineQty(p);
      case 'P16':
        return min(max(p.employees, 1), 20);
      case 'P20':
        return min(max(p.employees, 1), 12);
      case 'P23':
        return min(sites * (p.segment == Segment.micro ? 1 : 2), 24);
      case 'P21':
        return p.segment == Segment.multi ? sites : 1;
      case 'P12':
        return min(max((p.employees / 6).ceil(), 2), 4);
      case 'P24':
        return max(p.machines, 1);
      case 'P25':
        return max(p.vehicles, 1);
      default:
        return sites; // per-site products: P01 P02 P04 P09 P10 P19 P22
    }
  }

  void _repair(Bundle b, BusinessProfile p) {
    for (var pass = 0; pass < 6; pass++) {
      var changed = false;

      // 1. Business rules: tier, GSTIN, size, feasibility.
      for (final item in List.of(b.items)) {
        final v = rules.businessViolations(item.productId, p);
        if (v.isEmpty) continue;
        b.items.remove(item);
        changed = true;
        final block = v.first.block;
        final alt = _firstEligibleSubstitute(item.productId, p, b);
        if (alt != null) {
          for (final id in alt) {
            if (!b.contains(id)) {
              b.items.add(LineItem(id, _qtyFor(id, p),
                  origin: Origin.substitute, replaces: item.productId, need: item.need, optional: item.optional));
            }
          }
          b.notices.add(Notice(NoticeKind.substituted, item.productId, block: block, alternatives: alt));
        } else {
          b.notices.add(Notice(NoticeKind.blocked, item.productId, block: block));
        }
        if (block == Block.gstin && _gstGated.contains(item.productId)) {
          b.notices.add(Notice(NoticeKind.upgradePath, item.productId, block: Block.gstin));
        }
      }

      // 2. In-bundle dependencies.
      for (final v in rules.validate(b.items.map((i) => i.productId), p)) {
        if (v.block != Block.dependency) continue;
        // Only ever auto-add an affordable access line, never a leased line.
        final add = v.needsOneOf.firstWhere(
          (id) => rules.isEligibleFor(id, p) && const {'P01', 'P02', 'P04'}.contains(id),
          orElse: () => '',
        );
        if (add.isEmpty) {
          b.items.removeWhere((i) => i.productId == v.productId);
          b.notices.add(Notice(NoticeKind.blocked, v.productId, block: Block.dependency));
        } else {
          final qty = const {'P05', 'P06', 'P03'}.contains(add) || v.productId == 'P11' ? 1 : _qtyFor(add, p);
          b.items.add(LineItem(add, qty, origin: Origin.dependency, optional: false));
          b.notices.add(Notice(NoticeKind.autoAdded, add, alternatives: [v.productId]));
        }
        changed = true;
        break; // re-validate after each structural change
      }
      if (!changed) return;
    }
  }

  List<String>? _firstEligibleSubstitute(String id, BusinessProfile p, Bundle b) {
    for (final option in substitutes[id] ?? const <List<String>>[]) {
      if (option.every((s) => rules.isEligibleFor(s, p))) return option;
    }
    return null;
  }

  void _fitBudget(Bundle b, int budget) {
    for (final need in _trimOrder) {
      if (pricing.quote(b).monthly <= budget) return;
      for (final item in b.items.where((i) => i.need == need && i.optional && i.enabled)) {
        item.enabled = false;
        b.notices.add(Notice(NoticeKind.trimmed, item.productId));
      }
    }
  }
}
