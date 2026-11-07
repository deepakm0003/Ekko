import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show ConflictAlgorithm;
import 'package:uuid/uuid.dart';

import '../config/demo_seed.dart';
import 'db.dart';
import 'secure_store.dart';

enum Role { owner, partner }

class AppUser {
  final String id;
  final Role role;
  final String label; // masked phone or partner ID
  const AppUser(this.id, this.role, this.label);
}

sealed class OtpResult {}

class OtpOk extends OtpResult {
  final AppUser user;
  OtpOk(this.user);
}

class OtpWrong extends OtpResult {
  final int attemptsLeft;
  OtpWrong(this.attemptsLeft);
}

class OtpExpired extends OtpResult {}

class OtpLocked extends OtpResult {
  final int minutes;
  OtpLocked(this.minutes);
}

/// Phone + OTP login (OTP is shown on screen in this demo build instead of SMS).
/// The phone number itself is never stored — only a salted hash and a mask.
class AuthService {
  static const otpTtl = Duration(minutes: 5);
  static const maxAttempts = 5;
  static const lockout = Duration(minutes: 10);

  String? _otpHash;
  String? _phone;
  DateTime? _otpExpiry;
  int _attempts = 0;

  static final _phonePattern = RegExp(r'^[6-9]\d{9}$');

  static String? normalisePhone(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
    return _phonePattern.hasMatch(d) ? d : null;
  }

  static String maskPhone(String p) => '+91 ••••••${p.substring(6)}';

  String _hash(String v) => sha256.convert(utf8.encode(v)).toString();

  Future<int?> lockedMinutes() async {
    final until = await SecureStore.otpLockUntil();
    if (until == null || until.isBefore(DateTime.now())) return null;
    return until.difference(DateTime.now()).inMinutes + 1;
  }

  /// Returns the OTP to display (demo SMS), or null when locked out.
  Future<String?> sendOtp(String phone) async {
    if (await lockedMinutes() != null) return null;
    final otp = (Random.secure().nextInt(900000) + 100000).toString();
    _phone = phone;
    _otpHash = _hash('$phone:$otp');
    _otpExpiry = DateTime.now().add(otpTtl);
    _attempts = 0;
    await Db.audit('anon', 'otp_sent', maskPhone(phone));
    return otp;
  }

  Future<OtpResult> verifyOtp(String otp) async {
    final locked = await lockedMinutes();
    if (locked != null) return OtpLocked(locked);
    if (_otpHash == null || _otpExpiry == null || DateTime.now().isAfter(_otpExpiry!)) return OtpExpired();
    if (_hash('$_phone:$otp') != _otpHash) {
      _attempts++;
      await Db.audit('anon', 'otp_failed', maskPhone(_phone!));
      if (_attempts >= maxAttempts) {
        await SecureStore.setOtpLockUntil(DateTime.now().add(lockout));
        _otpHash = null;
        return OtpLocked(lockout.inMinutes);
      }
      return OtpWrong(maxAttempts - _attempts);
    }
    final phone = _phone!;
    _otpHash = null;
    final user = await _upsertOwner(phone);
    await SecureStore.setSessionUser(user.id);
    await Db.audit(user.id, 'login', 'owner');
    return OtpOk(user);
  }

  Future<AppUser> _upsertOwner(String phone) async {
    final db = await Db.instance;
    final hash = _hash('${await SecureStore.phoneSalt()}:$phone');
    final rows = await db.query('users', where: 'phone_hash = ?', whereArgs: [hash]);
    if (rows.isNotEmpty) return AppUser(rows.first['id'] as String, Role.owner, rows.first['phone_masked'] as String);
    final id = const Uuid().v4();
    await db.insert('users', {
      'id': id,
      'phone_hash': hash,
      'phone_masked': maskPhone(phone),
      'role': Role.owner.name,
      'created_at': Db.now,
    });
    return AppUser(id, Role.owner, maskPhone(phone));
  }

  Future<AppUser?> partnerLogin(String id, String pin) async {
    if (await lockedMinutes() != null) return null;
    final ok = id.trim().toUpperCase() == DemoSeed.partnerId &&
        _hash('${DemoSeed.partnerPinSalt}:${DemoSeed.partnerId}:${pin.trim()}') == DemoSeed.partnerPinHash;
    if (!ok) {
      _attempts++;
      await Db.audit('anon', 'partner_login_failed');
      if (_attempts >= maxAttempts) await SecureStore.setOtpLockUntil(DateTime.now().add(lockout));
      return null;
    }
    _attempts = 0;
    final db = await Db.instance;
    const uid = 'partner:${DemoSeed.partnerId}';
    await db.insert('users', {'id': uid, 'role': Role.partner.name, 'phone_masked': DemoSeed.partnerId, 'created_at': Db.now},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await SecureStore.setSessionUser(uid);
    await Db.audit(uid, 'login', 'partner');
    return const AppUser(uid, Role.partner, DemoSeed.partnerId);
  }

  Future<AppUser?> restore() async {
    final id = await SecureStore.sessionUser();
    if (id == null) return null;
    final db = await Db.instance;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return AppUser(id, Role.values.byName(rows.first['role'] as String), rows.first['phone_masked'] as String);
  }

  Future<void> logout(AppUser u) async {
    await Db.audit(u.id, 'logout');
    await SecureStore.setSessionUser(null);
  }
}
