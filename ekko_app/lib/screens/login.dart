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
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 20), children: [
          const EkkoLogo(size: 40),
          const SizedBox(height: 32),
          Text(_partner ? context.t('partner_login') : context.t('login_title'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 20),
          if (!_partner) ..._ownerForm(context) else ..._partnerForm(context),
          if (_error != null) ...[
            const SizedBox(height: 12),
            InfoBanner(_error!, icon: Icons.error_outline, color: EkkoColors.redDark, bg: EkkoColors.redSoft),
          ],
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => setState(() {
              _partner = !_partner;
              _error = null;
            }),
            child: Text(_partner ? context.t('owner_login') : context.t('partner_login'),
                style: const TextStyle(color: EkkoColors.red, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          InfoBanner(context.t('login_note'), icon: Icons.lock_outline),
        ]),
      ),
    );
  }

  List<Widget> _ownerForm(BuildContext context) => [
        TextField(
          controller: _phone,
          enabled: _demoOtp == null,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          decoration: InputDecoration(labelText: context.t('phone_label'), prefixText: '+91  '),
        ),
        const SizedBox(height: 14),
        if (_demoOtp == null)
          FilledButton(onPressed: _busy ? null : _sendOtp, child: Text(context.t('send_otp')))
        else ...[
          InfoBanner(context.t('otp_demo', {'otp': _demoOtp}),
              icon: Icons.sms_outlined, color: EkkoColors.green, bg: EkkoColors.greenSoft),
          const SizedBox(height: 14),
          TextField(
            controller: _otp,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w700),
            decoration: InputDecoration(labelText: context.t('otp_label')),
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: _busy ? null : _verify, child: Text(context.t('verify'))),
        ],
      ];

  List<Widget> _partnerForm(BuildContext context) => [
        TextField(
          controller: _pid,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: context.t('partner_id')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          decoration: InputDecoration(labelText: context.t('partner_pin')),
          onSubmitted: (_) => _partnerLogin(),
        ),
        const SizedBox(height: 14),
        FilledButton(onPressed: _busy ? null : _partnerLogin, child: Text(context.t('continue'))),
      ];
}
