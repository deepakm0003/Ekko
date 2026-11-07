import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Android Keystore-backed storage for keys, salts and the session.
class SecureStore {
  static const _s = FlutterSecureStorage();

  static const _dbKey = 'db_key_v1';
  static const _salt = 'phone_salt_v1';
  static const _session = 'session_user_v1';
  static const _lockUntil = 'otp_lock_until_v1';
  static const _appLock = 'app_lock_v1';
  static const _lang = 'lang_v1';

  static String _random(int bytes) {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(bytes, (_) => r.nextInt(256)));
  }

  /// 256-bit SQLCipher key, generated once per install.
  static Future<String> databaseKey() async {
    var k = await _s.read(key: _dbKey);
    if (k == null) {
      k = _random(32);
      await _s.write(key: _dbKey, value: k);
    }
    return k;
  }

  static Future<String> phoneSalt() async {
    var k = await _s.read(key: _salt);
    if (k == null) {
      k = _random(16);
      await _s.write(key: _salt, value: k);
    }
    return k;
  }

  static Future<String?> sessionUser() => _s.read(key: _session);
  static Future<void> setSessionUser(String? id) =>
      id == null ? _s.delete(key: _session) : _s.write(key: _session, value: id);

  static Future<DateTime?> otpLockUntil() async {
    final v = await _s.read(key: _lockUntil);
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(int.parse(v));
  }

  static Future<void> setOtpLockUntil(DateTime? t) => t == null
      ? _s.delete(key: _lockUntil)
      : _s.write(key: _lockUntil, value: '${t.millisecondsSinceEpoch}');

  static Future<bool> appLockEnabled() async => (await _s.read(key: _appLock)) == '1';
  static Future<void> setAppLock(bool on) => _s.write(key: _appLock, value: on ? '1' : '0');

  static Future<String?> language() => _s.read(key: _lang);
  static Future<void> setLanguage(String l) => _s.write(key: _lang, value: l);

  /// Wipes everything, including the database key (crypto-shreds the DB).
  static Future<void> wipe() => _s.deleteAll();
}
