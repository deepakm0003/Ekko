import 'dart:math';

import 'bundle.dart';
import 'catalogue.dart';

class QuoteLine {
  final String productId;
  final int qty;
  final int unitPrice;
  final int setup;
  int get monthly => unitPrice * qty;
  const QuoteLine(this.productId, this.qty, this.unitPrice, this.setup);
}

class Quote {
  final List<QuoteLine> lines;
  final int contractMonths;

  /// The product that forces the contract length (for the "why 24 months" hint).
  final String? contractDrivenBy;
  final int installDays;
  final String? installDrivenBy;
  static const gstRate = 0.18;

  const Quote(this.lines, this.contractMonths, this.contractDrivenBy, this.installDays, this.installDrivenBy);

  int get monthly => lines.fold(0, (s, l) => s + l.monthly);
  int get setup => lines.fold(0, (s, l) => s + l.setup);
  int get monthlyWithGst => (monthly * (1 + gstRate)).round();
  int get setupWithGst => (setup * (1 + gstRate)).round();
  bool get noLockIn => contractMonths <= 1;
}

/// Pricing rules matched to the data: setup = sum(setup x qty) and
/// contract = longest minimum contract in the bundle (true for all 368
/// activated bundles). Monthly price is our policy: midpoint of the catalogue
/// range, or the long-term price on a 24-month term.
class PricingEngine {
  final Catalogue catalogue;
  const PricingEngine(this.catalogue);

  int minimumContract(Bundle b) =>
      b.active.fold(1, (m, i) => max(m, catalogue[i.productId].minContract));

  /// Terms the owner can pick: the minimum, plus 24 months for a better rate.
  List<int> contractOptions(Bundle b) {
    final minC = minimumContract(b);
    return {minC, if (minC < 24) 24}.toList()..sort();
  }

  Quote quote(Bundle b, {int? contractMonths}) {
    final minC = minimumContract(b);
    final term = max(contractMonths ?? minC, minC);
    final longTerm = term >= 24;
    String? driver;
    String? installDriver;
    var install = 0;
    final lines = <QuoteLine>[];
    for (final i in b.active) {
      final p = catalogue[i.productId];
      if (p.minContract == minC && minC > 1) driver ??= p.id;
      if (p.installDays > install) {
        install = p.installDays;
        installDriver = p.id;
      }
      lines.add(QuoteLine(p.id, i.qty, longTerm ? p.longTermPrice : p.listPrice, p.setup * i.qty));
    }
    return Quote(lines, term, driver, install, installDriver);
  }

  /// Savings per month of the 24-month term over the minimum term.
  int longTermSaving(Bundle b) {
    final minC = minimumContract(b);
    if (minC >= 24) return 0;
    return quote(b, contractMonths: minC).monthly - quote(b, contractMonths: 24).monthly;
  }
}
