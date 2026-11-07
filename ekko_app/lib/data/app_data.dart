import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../engine/catalogue.dart';
import '../engine/kyc.dart';
import '../engine/propensity.dart';
import '../engine/recommender.dart';
import '../engine/registry.dart';

/// Read-only reference data shipped with the app (built from the case CSVs).
class AppData {
  final Catalogue catalogue;
  final Registry registry;
  final PropensityModel propensity;
  final Map<String, dynamic> insights;
  final List<Map<String, dynamic>> cockpitLeads;
  final Recommender recommender;
  final KycValidator kyc;

  AppData._(this.catalogue, this.registry, this.propensity, this.insights, this.cockpitLeads)
      : recommender = Recommender(catalogue),
        kyc = KycValidator(registry);

  static Future<AppData> load() async {
    final raws = await Future.wait([
      rootBundle.loadString('assets/data/catalogue.json'),
      rootBundle.loadString('assets/data/gstin_registry.json'),
      rootBundle.loadString('assets/data/udyam_registry.json'),
      rootBundle.loadString('assets/data/propensity_model.json'),
      rootBundle.loadString('assets/data/insights.json'),
      rootBundle.loadString('assets/data/cockpit_leads.json'),
    ]);
    final registry = await compute(_parseRegistry, [raws[1], raws[2]]);
    final leads = await compute(_parseList, raws[5]);
    return AppData._(
      Catalogue.fromJsonString(raws[0]),
      registry,
      PropensityModel.fromJsonString(raws[3]),
      jsonDecode(raws[4]) as Map<String, dynamic>,
      leads,
    );
  }

  static Registry _parseRegistry(List<String> r) => Registry.fromJson(r[0], r[1]);
  static List<Map<String, dynamic>> _parseList(String r) =>
      (jsonDecode(r) as List).cast<Map<String, dynamic>>();
}

/// Cities served (from the leads data) with their tier and state.
const cities = <String, (int, String)>{
  'Ahmedabad': (1, 'Gujarat'),
  'Bengaluru': (1, 'Karnataka'),
  'Bangalore': (1, 'Karnataka'),
  'Bhopal': (2, 'Madhya Pradesh'),
  'Chennai': (1, 'Tamil Nadu'),
  'Coimbatore': (2, 'Tamil Nadu'),
  'Delhi': (1, 'Delhi'),
  'New Delhi': (1, 'Delhi'),
  'Hyderabad': (1, 'Telangana'),
  'Indore': (2, 'Madhya Pradesh'),
  'Jaipur': (2, 'Rajasthan'),
  'Kochi': (2, 'Kerala'),
  'Kolkata': (1, 'West Bengal'),
  'Lucknow': (2, 'Uttar Pradesh'),
  'Ludhiana': (2, 'Punjab'),
  'Mumbai': (1, 'Maharashtra'),
  'Mysuru': (2, 'Karnataka'),
  'Nagpur': (2, 'Maharashtra'),
  'Nashik': (2, 'Maharashtra'),
  'Patna': (2, 'Bihar'),
  'Pune': (1, 'Maharashtra'),
  'Surat': (2, 'Gujarat'),
  'Vadodara': (2, 'Gujarat'),
  'Visakhapatnam': (2, 'Andhra Pradesh'),
};

/// Business types seen in the leads data, most common first, for quick chips.
const businessTypes = [
  'Kirana store', 'Pharmacy', 'Salon', 'Bakery', 'Boutique', 'Mobile repair shop', 'Hardware store',
  'Sweet shop', 'Stationery shop', 'Optician', 'Dental clinic', 'Physiotherapy clinic', 'Diagnostic lab',
  'CA firm', 'Law office', 'Coaching centre', 'Architecture studio', 'Insurance agency', 'Real estate agency',
  'Travel agency', 'Restaurant chain', 'Pharmacy chain', 'Bakery chain', 'Apparel retail chain',
  'Electronics retail chain', 'Gym chain', 'Budget hotel group', 'Pre-school chain', 'Auto-parts unit',
  'Textile unit', 'Food processing unit', 'Packaging unit', 'Plastic moulding unit', 'Printing press',
  'Furniture workshop',
];
