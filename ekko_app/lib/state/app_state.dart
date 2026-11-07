import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../data/app_data.dart';
import '../engine/bundle.dart';
import '../engine/kyc.dart';
import '../engine/pricing.dart';
import '../engine/profile.dart';
import '../l10n/strings.dart';
import '../services/advisor_backend.dart';
import '../services/auth_service.dart';
import '../services/db.dart';
import '../services/secure_store.dart';

/// App-wide state: reference data, session, language and the journey in progress.
class AppState extends ChangeNotifier {
  final AppData data;
  final auth = AuthService();
  final backend = AdvisorBackend();
  final _localAuth = LocalAuthentication();

  AppUser? user;
  String lang = 'en';
  bool appLock = false;
  bool locked = false;

  // Journey in progress.
  BusinessProfile? profile;
  Bundle? bundle;
  int? contractMonths;
  String? businessName;
  KycReport? kycReport;

  /// Bumped when an order is placed so order lists refresh.
  int ordersVersion = 0;

  AppState(this.data);

  void orderPlaced() {
    ordersVersion++;
    resetJourney();
  }

  S get s => S(lang);
  PricingEngine get pricing => data.recommender.pricing;
  Quote? get quote => bundle == null ? null : pricing.quote(bundle!, contractMonths: contractMonths);

  Future<void> init() async {
    lang = await SecureStore.language() ?? 'en';
    appLock = await SecureStore.appLockEnabled();
    user = await auth.restore();
    locked = user != null && appLock;
    backend.checkHealth().then((_) => notifyListeners());
    notifyListeners();
  }

  Future<void> setLanguage(String l) async {
    lang = l;
    await SecureStore.setLanguage(l);
    notifyListeners();
  }

  void signedIn(AppUser u) {
    user = u;
    locked = false;
    notifyListeners();
  }

  Future<void> logout() async {
    if (user != null) await auth.logout(user!);
    user = null;
    resetJourney();
  }

  void resetJourney() {
    profile = null;
    bundle = null;
    contractMonths = null;
    businessName = null;
    kycReport = null;
    notifyListeners();
  }

  void setPlan(BusinessProfile p, Bundle b, {String? name}) {
    profile = p;
    bundle = b;
    businessName = name ?? businessName;
    contractMonths = null;
    notifyListeners();
  }

  void touch() => notifyListeners();

  // ---- App lock (biometric / device PIN) ------------------------------------
  Future<bool> setAppLock(bool on) async {
    if (on) {
      final ok = await _authenticate();
      if (!ok) return false;
    }
    appLock = on;
    await SecureStore.setAppLock(on);
    if (user != null) await Db.audit(user!.id, on ? 'app_lock_on' : 'app_lock_off');
    notifyListeners();
    return true;
  }

  void lockIfEnabled() {
    if (appLock && user != null) {
      locked = true;
      notifyListeners();
    }
  }

  Future<void> unlock() async {
    if (await _authenticate()) {
      locked = false;
      notifyListeners();
    }
  }

  Future<bool> _authenticate() async {
    try {
      if (!await _localAuth.isDeviceSupported()) return true;
      return await _localAuth.authenticate(localizedReason: s.t('unlock_reason'));
    } on PlatformException {
      return false;
    }
  }

  /// DPDP erasure + crypto-shred: delete the DB, then the keys that encrypted it.
  Future<void> eraseEverything() async {
    await Db.eraseAll();
    await SecureStore.wipe();
    user = null;
    appLock = false;
    resetJourney();
  }
}

/// Blocks screenshots/screen recording while KYC data is on screen.
class SecureWindow {
  static const _ch = MethodChannel('ekko/secure_window');

  /// Only for recording the demo video (--dart-define=EKKO_ALLOW_CAPTURE=true).
  static const _allowCapture = bool.fromEnvironment('EKKO_ALLOW_CAPTURE');

  static Future<void> set(bool on) async {
    if (_allowCapture) return;
    try {
      await _ch.invokeMethod('set', on);
    } catch (_) {}
  }
}
