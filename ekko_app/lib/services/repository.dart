import 'dart:convert';
import 'dart:math';

import 'package:sqflite_sqlcipher/sqflite.dart' show ConflictAlgorithm;

import '../engine/bundle.dart';
import '../engine/kyc.dart';
import '../engine/pricing.dart';
import '../engine/profile.dart';
import '../engine/propensity.dart';
import 'db.dart';

/// Order lifecycle shown in the tracker.
enum Stage { placed, kyc, scheduled, install, active }

class OrderEvent {
  final Stage stage;
  final String? note;
  final DateTime at;
  const OrderEvent(this.stage, this.note, this.at);
}

class Order {
  final String id;
  final Stage status;
  final BusinessProfile profile;
  final Bundle bundle;
  final int contract;
  final int monthly;
  final int setup;
  final int etaDays;
  final String? businessName;
  final String? gstinMasked;
  final DateTime createdAt;
  final List<OrderEvent> events;
  const Order(this.id, this.status, this.profile, this.bundle, this.contract, this.monthly, this.setup, this.etaDays,
      this.businessName, this.gstinMasked, this.createdAt, this.events);

  DateTime get eta => createdAt.add(Duration(days: etaDays));
}

class Repository {
  static String _orderId() => 'EK${Random.secure().nextInt(900000) + 100000}';

  // ---- Consents (DPDP) ---------------------------------------------------
  static const noticeVersion = '1.0';

  static Future<void> recordConsent(String userId, String purpose, bool granted) async {
    final db = await Db.instance;
    await db.insert('consents', {
      'user_id': userId,
      'purpose': purpose,
      'granted': granted ? 1 : 0,
      'notice_version': noticeVersion,
      'ts': Db.now,
    });
    await Db.audit(userId, granted ? 'consent_granted' : 'consent_withdrawn', purpose);
  }

  /// Latest state per purpose.
  static Future<Map<String, (bool, DateTime)>> consents(String userId) async {
    final db = await Db.instance;
    final rows = await db.query('consents', where: 'user_id = ?', whereArgs: [userId], orderBy: 'ts ASC, id ASC');
    return {
      for (final r in rows)
        r['purpose'] as String: (r['granted'] == 1, DateTime.fromMillisecondsSinceEpoch(r['ts'] as int)),
    };
  }

  // ---- KYC -------------------------------------------------------------------
  static Future<void> saveKycReport(String userId, KycReport report) async {
    final db = await Db.instance;
    await db.insert('kyc_reports', {
      'user_id': userId,
      'verdict': report.verdict.name,
      'checks': jsonEncode(report.checks.map((c) => c.toJson()).toList()),
      'ts': Db.now,
    });
    await Db.audit(userId, 'kyc_verified', report.verdict.name);
  }

  // ---- Orders ----------------------------------------------------------------
  static Future<String> placeOrder({
    required String userId,
    required BusinessProfile profile,
    required Bundle bundle,
    required Quote quote,
    required String? businessName,
    required String? gstinMasked,
    required String signedName,
  }) async {
    final db = await Db.instance;
    final id = _orderId();
    final now = DateTime.now();
    // KYC is done in-app, so scheduling starts the same day.
    final eta = max(quote.installDays, 1);
    await db.transaction((tx) async {
      await tx.insert('orders', {
        'id': id,
        'user_id': userId,
        'status': Stage.kyc.name,
        'profile': jsonEncode(profile.toJson()),
        'bundle': jsonEncode(bundle.toJson()),
        'contract': quote.contractMonths,
        'monthly': quote.monthly,
        'setup': quote.setup,
        'eta_days': eta,
        'business_name': businessName,
        'gstin_masked': gstinMasked,
        'kyc_verdict': 'approved',
        'signed_name': signedName,
        'created_at': now.millisecondsSinceEpoch,
      });
      await tx.insert('order_events', {'order_id': id, 'stage': Stage.placed.name, 'ts': now.millisecondsSinceEpoch});
      await tx.insert('order_events', {
        'order_id': id,
        'stage': Stage.kyc.name,
        'note': 'kyc_auto',
        'ts': now.millisecondsSinceEpoch + 1000,
      });
    });
    await Db.audit(userId, 'order_placed', id);
    return id;
  }

  static Future<List<Order>> orders(String userId) async {
    final db = await Db.instance;
    final rows = await db.query('orders', where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
    return [for (final r in rows) await _order(r)];
  }

  static Future<Order?> order(String id) async {
    final db = await Db.instance;
    final rows = await db.query('orders', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _order(rows.first);
  }

  static Future<Order> _order(Map<String, Object?> r) async {
    final db = await Db.instance;
    final ev = await db.query('order_events', where: 'order_id = ?', whereArgs: [r['id']], orderBy: 'ts ASC');
    return Order(
      r['id'] as String,
      Stage.values.byName(r['status'] as String),
      BusinessProfile.fromJson(jsonDecode(r['profile'] as String)),
      Bundle.fromJson(jsonDecode(r['bundle'] as String)),
      r['contract'] as int,
      r['monthly'] as int,
      r['setup'] as int,
      r['eta_days'] as int,
      r['business_name'] as String?,
      r['gstin_masked'] as String?,
      DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      [
        for (final e in ev)
          OrderEvent(Stage.values.byName(e['stage'] as String), e['note'] as String?,
              DateTime.fromMillisecondsSinceEpoch(e['ts'] as int)),
      ],
    );
  }

  /// Moves an order to its next stage (demo control for the live tracker).
  static Future<void> advance(String orderId, String actor) async {
    final o = await order(orderId);
    if (o == null || o.status == Stage.active) return;
    final next = Stage.values[o.status.index + 1];
    final db = await Db.instance;
    await db.transaction((tx) async {
      await tx.update('orders', {'status': next.name}, where: 'id = ?', whereArgs: [orderId]);
      await tx.insert('order_events', {'order_id': orderId, 'stage': next.name, 'ts': Db.now});
    });
    await Db.audit(actor, 'order_stage', '$orderId:${next.name}');
  }

  // ---- Leads (advisor couldn't close) --------------------------------------
  static Future<void> saveLead({
    required String? userId,
    required BusinessProfile profile,
    required PropensityModel model,
    required String stage,
    required String reason,
  }) async {
    final db = await Db.instance;
    final score = scoreProfile(model, profile, source: 'Website form');
    final id = 'APP-${Random.secure().nextInt(90000) + 10000}';
    await db.insert('leads', {
      'id': id,
      'user_id': userId,
      'profile': jsonEncode(profile.toJson()),
      'score': score,
      'stage': stage,
      'reason': reason,
      'created_at': Db.now,
    });
    await Db.audit(userId ?? 'anon', 'lead_created', '$id:$reason');
  }

  static Future<List<Map<String, Object?>>> appLeads() async {
    final db = await Db.instance;
    return db.query('leads', orderBy: 'score DESC');
  }

  static Future<Set<String>> contactedIds() async {
    final db = await Db.instance;
    return (await db.query('contacted')).map((r) => r['lead_id'] as String).toSet();
  }

  static Future<void> markContacted(String leadId, String actor) async {
    final db = await Db.instance;
    await db.insert('contacted', {'lead_id': leadId, 'ts': Db.now});
    await Db.audit(actor, 'lead_contacted', leadId);
  }

  // ---- Advisor draft (resume later) ---------------------------------------
  static Future<void> saveDraft(String userId, Map<String, dynamic> data) async {
    final db = await Db.instance;
    await db.insert('drafts', {'user_id': userId, 'data': jsonEncode(data), 'updated_at': Db.now},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, Object?>>> auditLog({int limit = 100}) async {
    final db = await Db.instance;
    return db.query('audit_log', orderBy: 'id DESC', limit: limit);
  }
}

/// Map an in-app profile onto the propensity model's training columns.
double scoreProfile(PropensityModel m, BusinessProfile p, {required String source}) {
  const seg = {
    Segment.micro: 'Micro retail & services',
    Segment.prof: 'Professional offices',
    Segment.multi: 'Small multi-site businesses',
    Segment.mfg: 'Small manufacturers',
  };
  const gst = {
    GstStatus.active: 'Active',
    GstStatus.cancelled: 'Cancelled',
    GstStatus.suspended: 'Suspended',
    GstStatus.none: 'none',
  };
  return m.score({
    'lead_source': source,
    'segment': seg[p.segment]!,
    'city_tier': '${p.cityTier}',
    'gst_status': gst[p.gstStatus]!,
    'has_udyam': p.hasUdyam ? 'Y' : 'N',
    if (p.currentInternet.isNotEmpty) 'current_internet': p.currentInternet,
  }, employees: p.employees, sites: p.sites, spend: p.currentMonthlySpend);
}
