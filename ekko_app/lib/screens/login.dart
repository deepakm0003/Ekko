import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _pid = TextEditingController();
  final _pin = TextEditingController();
  bool _partner = false;
  bool _busy = false;
  String? _demoOtp;
  String? _error;

  @override
  void dispose() {
    for (final c in [_phone, _otp, _pid, _pin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final app = context.read<AppState>();
    final phone = AuthService.normalisePhone(_phone.text);
    if (phone == null) return setState(() => _error = app.s.t('phone_invalid'));
    setState(() => _busy = true);
    final otp = await app.auth.sendOtp(phone);
    final locked = otp == null ? await app.auth.lockedMinutes() : null;
    setState(() {
      _busy = false;
      _demoOtp = otp;
      _error = otp == null ? app.s.t('otp_locked', {'n': locked ?? 10}) : null;
    });
  }

  Future<void> _verify() async {
    final app = context.read<AppState>();
    setState(() => _busy = true);
    final r = await app.auth.verifyOtp(_otp.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case OtpOk(:final user):
        app.signedIn(user);
      case OtpWrong(:final attemptsLeft):
        setState(() => _error = app.s.t('otp_invalid', {'n': attemptsLeft}));
      case OtpExpired():
        setState(() {
          _error = app.s.t('otp_expired');
          _demoOtp = null;
        });
      case OtpLocked(:final minutes):
        setState(() {
          _error = app.s.t('otp_locked', {'n': minutes});
          _demoOtp = null;
        });
    }
  }

  Future<void> _partnerLogin() async {
    final app = context.read<AppState>();
    setState(() => _busy = true);
    final u = await app.auth.partnerLogin(_pid.text, _pin.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (u == null) {
      final locked = await app.auth.lockedMinutes();
      setState(() => _error = locked != null ? app.s.t('otp_locked', {'n': locked}) : app.s.t('partner_invalid'));
    } else {
      app.signedIn(u);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xxl, Sp.xl, Sp.xl), children: [
          const EkkoLogo(size: 40),
          const Gap(Sp.xxxl + 8),
          IconBadge(_partner ? Icons.storefront_rounded : Icons.phone_iphone_rounded, size: 52),
          const Gap(Sp.lg),
          Text(_partner ? context.t('partner_login') : context.t('login_title'), style: T.h1),
          const Gap(Sp.sm),
          Text(_partner ? 'See leads to call, ranked by our model.' : context.t('login_note'), style: T.bodySoft),
          const Gap(Sp.xxl),
          if (!_partner) ..._ownerForm(context) else ..._partnerForm(context),
          if (_error != null) ...[
            const Gap(Sp.md),
            InfoBanner(_error!, icon: Icons.error_outline_rounded, color: EkkoColors.redDark, bg: EkkoColors.redSoft),
          ],
          const Gap(Sp.xl),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() {
                _partner = !_partner;
                _error = null;
              }),
              icon: Icon(_partner ? Icons.person_rounded : Icons.storefront_rounded, size: 18),
              label: Text(_partner ? context.t('owner_login') : context.t('partner_login')),
            ),
          ),
          const Gap(Sp.xl),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock_rounded, size: 14, color: EkkoColors.muted),
            Gap(6),
            Text('Encrypted on your phone · DPDP-compliant', style: T.small),
          ]),
        ]),
      ),
    );
  }

  List<Widget> _ownerForm(BuildContext context) => [
        TextField(
          controller: _phone,
          enabled: _demoOtp == null,
          keyboardType: TextInputType.phone,
          style: T.h3.copyWith(fontSize: 18, letterSpacing: 1),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          decoration: InputDecoration(
            labelText: context.t('phone_label'),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 18, right: 8),
              child: Text('🇮🇳  +91', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
        ),
        const Gap(Sp.lg),
        if (_demoOtp == null)
          FilledButton(onPressed: _busy ? null : _sendOtp, child: Text(context.t('send_otp')))
        else ...[
          InfoBanner(context.t('otp_demo', {'otp': _demoOtp}), icon: Icons.sms_rounded, color: EkkoColors.green, bg: EkkoColors.greenSoft),
          const Gap(Sp.lg),
          TextField(
            controller: _otp,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            style: const TextStyle(fontFamily: 'Jakarta', fontSize: 26, letterSpacing: 14, fontWeight: FontWeight.w800),
            decoration: InputDecoration(labelText: context.t('otp_label')),
            onSubmitted: (_) => _verify(),
          ),
          const Gap(Sp.lg),
          FilledButton(onPressed: _busy ? null : _verify, child: Text(context.t('verify'))),
        ],
      ];

  List<Widget> _partnerForm(BuildContext context) => [
        TextField(
          controller: _pid,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: context.t('partner_id'), prefixIcon: const Icon(Icons.badge_rounded)),
        ),
        const Gap(Sp.md),
        TextField(
          controller: _pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          decoration: InputDecoration(labelText: context.t('partner_pin'), prefixIcon: const Icon(Icons.password_rounded)),
          onSubmitted: (_) => _partnerLogin(),
        ),
        const Gap(Sp.lg),
        FilledButton(onPressed: _busy ? null : _partnerLogin, child: Text(context.t('continue'))),
      ];
}
