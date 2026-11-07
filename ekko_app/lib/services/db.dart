import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'secure_store.dart';

/// SQLCipher-encrypted local database. Stores only what each step needs:
/// no document images, and identifiers are stored masked.
class Db {
  static Database? _db;
  static const _name = 'ekko.db';

  static Future<Database> get instance async => _db ??= await _open();

  static Future<Database> _open() async {
    final key = await SecureStore.databaseKey();
    final path = p.join(await getDatabasesPath(), _name);
    return openDatabase(path, password: key, version: 1, onCreate: (db, _) async {
      final b = db.batch();
      b.execute('''CREATE TABLE users(
        id TEXT PRIMARY KEY, phone_hash TEXT UNIQUE, phone_masked TEXT, role TEXT NOT NULL,
        created_at INTEGER NOT NULL)''');
      b.execute('''CREATE TABLE consents(
        id INTEGER PRIMARY KEY AUTOINCREMENT, user_id TEXT NOT NULL, purpose TEXT NOT NULL,
        granted INTEGER NOT NULL, notice_version TEXT NOT NULL, ts INTEGER NOT NULL)''');
      b.execute('''CREATE TABLE orders(
        id TEXT PRIMARY KEY, user_id TEXT NOT NULL, status TEXT NOT NULL, profile TEXT NOT NULL,
        bundle TEXT NOT NULL, contract INTEGER NOT NULL, monthly INTEGER NOT NULL, setup INTEGER NOT NULL,
        eta_days INTEGER NOT NULL, business_name TEXT, gstin_masked TEXT, kyc_verdict TEXT,
        signed_name TEXT, created_at INTEGER NOT NULL)''');
      b.execute('''CREATE TABLE order_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT, order_id TEXT NOT NULL, stage TEXT NOT NULL,
        note TEXT, ts INTEGER NOT NULL)''');
      b.execute('''CREATE TABLE kyc_reports(
        id INTEGER PRIMARY KEY AUTOINCREMENT, user_id TEXT NOT NULL, order_id TEXT, verdict TEXT NOT NULL,
        checks TEXT NOT NULL, ts INTEGER NOT NULL)''');
      b.execute('''CREATE TABLE leads(
        id TEXT PRIMARY KEY, user_id TEXT, profile TEXT NOT NULL, score REAL NOT NULL, stage TEXT NOT NULL,
        reason TEXT, contacted INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)''');
      b.execute('''CREATE TABLE contacted(lead_id TEXT PRIMARY KEY, ts INTEGER NOT NULL)''');
      b.execute('''CREATE TABLE drafts(user_id TEXT PRIMARY KEY, data TEXT NOT NULL, updated_at INTEGER NOT NULL)''');
      b.execute('''CREATE TABLE audit_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT, ts INTEGER NOT NULL, actor TEXT NOT NULL, action TEXT NOT NULL,
        detail TEXT)''');
      await b.commit(noResult: true);
    });
  }

  static int get now => DateTime.now().millisecondsSinceEpoch;

  /// Append-only security/audit trail. Callers pass already-masked details.
  static Future<void> audit(String actor, String action, [String? detail]) async {
    final db = await instance;
    await db.insert('audit_log', {'ts': now, 'actor': actor, 'action': action, 'detail': detail});
  }

  /// Everything stored about a user, for the DPDP "download my data" right.
  static Future<String> exportUser(String userId) async {
    final db = await instance;
    Future<List<Map<String, Object?>>> q(String t, [String col = 'user_id']) =>
        db.query(t, where: '$col = ?', whereArgs: [userId]);
    final orders = await q('orders');
    final events = <Map<String, Object?>>[];
    for (final o in orders) {
      events.addAll(await db.query('order_events', where: 'order_id = ?', whereArgs: [o['id']]));
    }
    return const JsonEncoder.withIndent('  ').convert({
      'user': await q('users', 'id'),
      'consents': await q('consents'),
      'orders': orders,
      'order_events': events,
      'kyc_reports': await q('kyc_reports'),
      'leads': await q('leads'),
      'exported_at': DateTime.now().toIso8601String(),
    });
  }

  /// DPDP erasure: close and delete the whole database file (one user per phone).
  static Future<void> eraseAll() async {
    final db = await instance;
    await db.close();
    _db = null;
    await deleteDatabase(p.join(await getDatabasesPath(), _name));
  }
}
