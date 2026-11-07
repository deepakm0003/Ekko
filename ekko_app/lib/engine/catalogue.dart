import 'dart:convert';

/// One product row from product_catalogue.csv.
class Product {
  final String id;
  final String category;
  final String name;
  final String description;
  final String unit;
  final int priceMin;
  final int priceMax;
  final int setup;
  final int minContract;
  final List<int> tiers;
  final int minEmployees;
  final int minSites;
  final bool requiresGstin;
  final List<String> requiresOneOf;
  final int installDays;
  final List<String> segments;

  const Product({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.unit,
    required this.priceMin,
    required this.priceMax,
    required this.setup,
    required this.minContract,
    required this.tiers,
    required this.minEmployees,
    required this.minSites,
    required this.requiresGstin,
    required this.requiresOneOf,
    required this.installDays,
    required this.segments,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'],
        category: j['category'],
        name: j['name'],
        description: j['description'],
        unit: j['unit'],
        priceMin: j['priceMin'],
        priceMax: j['priceMax'],
        setup: j['setup'],
        minContract: j['minContract'],
        tiers: List<int>.from(j['tiers']),
        minEmployees: j['minEmployees'],
        minSites: j['minSites'],
        requiresGstin: j['requiresGstin'],
        requiresOneOf: List<String>.from(j['requiresOneOf']),
        installDays: j['installDays'],
        segments: List<String>.from(j['segments']),
      );

  /// Standard (12-month or minimum term) list price: midpoint of the range.
  int get listPrice => ((priceMin + priceMax) / 2).round();

  /// Long-term (24-month) price: a quarter of the way up from the minimum.
  int get longTermPrice => (priceMin + (priceMax - priceMin) * 0.25).round();

  bool get isConnectivityBase => const {'P01', 'P02', 'P03', 'P04', 'P05', 'P06'}.contains(id);
}

class Catalogue {
  final Map<String, Product> byId;
  Catalogue(List<Product> products) : byId = {for (final p in products) p.id: p};

  factory Catalogue.fromJsonString(String raw) =>
      Catalogue((jsonDecode(raw) as List).map((e) => Product.fromJson(e)).toList());

  Product operator [](String id) {
    final p = byId[id];
    if (p == null) throw ArgumentError('Unknown product $id');
    return p;
  }

  Iterable<Product> get all => byId.values;
}
