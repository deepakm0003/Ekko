import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'kyc.dart';

/// DPDP Act 2023 notice: itemised data, specific purpose, retention, rights,
/// and separate (unbundled) consent for KYC vs marketing.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});
  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _kyc = false;
  bool _marketing = false;

  Future<void> _agree() async {
    final app = context.read<AppState>();
    final uid = app.user!.id;
    await Repository.recordConsent(uid, 'kyc_verification', true);
    await Repository.recordConsent(uid, 'marketing', _marketing);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const KycScreen()));
  }

  @override
  Widget build(BuildContext context) {
    Widget block(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: EkkoColors.redSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: EkkoColors.red),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(height: 1.4, color: EkkoColors.inkSoft)),
              ]),
            ),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: Text(context.t('consent_title'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(context.t('consent_intro'), style: const TextStyle(fontSize: 15, height: 1.4)),
        const SizedBox(height: 18),
        block(Icons.list_alt, context.t('consent_what_t'), context.t('consent_what')),
        block(Icons.flag_outlined, context.t('consent_why_t'), context.t('consent_why')),
        block(Icons.timer_outlined, context.t('consent_keep_t'), context.t('consent_keep')),
        block(Icons.gavel_outlined, context.t('consent_rights_t'), context.t('consent_rights')),
        const Divider(height: 24),
        CheckboxListTile(
          value: _kyc,
          onChanged: (v) => setState(() => _kyc = v ?? false),
          activeColor: EkkoColors.red,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(context.t('consent_kyc'), style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        CheckboxListTile(
          value: _marketing,
          onChanged: (v) => setState(() => _marketing = v ?? false),
          activeColor: EkkoColors.red,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(context.t('consent_marketing')),
        ),
        const SizedBox(height: 8),
        Text(context.t('consent_version', {'v': Repository.noticeVersion}),
            style: const TextStyle(fontSize: 12, color: EkkoColors.inkSoft)),
      ]),
      bottomNavigationBar: BottomBar(children: [
        FilledButton(onPressed: _kyc ? _agree : null, child: Text(context.t('consent_agree'))),
      ]),
    );
  }
}
