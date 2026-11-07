import 'dart:convert';
import 'dart:math';

/// Logistic-regression lead score trained on smb_leads.csv (tool/build_assets.py).
/// Uses only facts known before first contact, so it can score a new lead.
class PropensityModel {
  final double intercept;
  final Map<String, double> weights;
  final double cvAuc;
  const PropensityModel(this.intercept, this.weights, this.cvAuc);

  factory PropensityModel.fromJsonString(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return PropensityModel(
      (j['intercept'] as num).toDouble(),
      (j['weights'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble())),
      (j['cvAuc'] as num).toDouble(),
    );
  }

  /// [categorical] uses the CSV column names and values, e.g.
  /// {'lead_source': 'Website form', 'segment': 'Professional offices', ...}.
  double score(Map<String, String> categorical, {required int employees, required int sites, required int spend}) {
    var z = intercept;
    categorical.forEach((col, value) => z += weights['${col}_$value'] ?? 0);
    z += (weights['log_employees'] ?? 0) * log(1 + employees);
    z += (weights['log_sites'] ?? 0) * log(1 + sites);
    z += (weights['log_spend'] ?? 0) * log(1 + spend);
    return 1 / (1 + exp(-z));
  }
}
