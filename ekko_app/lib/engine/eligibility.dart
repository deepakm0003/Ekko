import 'catalogue.dart';
import 'profile.dart';

/// Why a product cannot be sold to this business.
enum Block { tier, gstin, employees, sites, dependency, feasibility }

class Violation {
  final String productId;
  final Block block;

  /// For [Block.dependency]: products that would satisfy it.
  final List<String> needsOneOf;
  const Violation(this.productId, this.block, [this.needsOneOf = const []]);

  @override
  String toString() => '$productId:${block.name}';
}

/// Deterministic catalogue rules. The AI never decides eligibility; this does.
class EligibilityEngine {
  final Catalogue catalogue;
  const EligibilityEngine(this.catalogue);

  /// Rules that depend only on the business (not on the rest of the bundle).
  List<Violation> businessViolations(String productId, BusinessProfile p) {
    final prod = catalogue[productId];
    final out = <Violation>[];
    if (!prod.tiers.contains(p.cityTier)) out.add(Violation(productId, Block.tier));
    if (prod.requiresGstin && !p.hasActiveGstin) out.add(Violation(productId, Block.gstin));
    if (p.employees < prod.minEmployees) out.add(Violation(productId, Block.employees));
    if (p.sites < prod.minSites) out.add(Violation(productId, Block.sites));
    // Fibre products need a fibre-feasible site.
    if (!p.fibreFeasible && const {'P01', 'P02', 'P03'}.contains(productId)) {
      out.add(Violation(productId, Block.feasibility));
    }
    return out;
  }

  bool isEligibleFor(String productId, BusinessProfile p) => businessViolations(productId, p).isEmpty;

  /// Full validation of a bundle: business rules plus in-bundle dependencies.
  List<Violation> validate(Iterable<String> productIds, BusinessProfile p) {
    final ids = productIds.toSet();
    final out = <Violation>[];
    for (final id in ids) {
      out.addAll(businessViolations(id, p));
      final dep = catalogue[id].requiresOneOf;
      if (dep.isNotEmpty && !dep.any(ids.contains)) out.add(Violation(id, Block.dependency, dep));
    }
    return out;
  }
}
