import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../services/auth_service.dart';
import '../services/db.dart';
import '../services/repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

final _fmt = DateFormat('d MMM yyyy, h:mm a');

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final u = app.user!;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('account_title'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: EkkoColors.redSoft,
              child: Icon(u.role == Role.partner ? Icons.storefront : Icons.person, color: EkkoColors.red),
            ),
            title: Text(u.label, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(u.role == Role.partner ? 'Accel partner' : 'Business owner'),
          ),
        ),
        SectionTitle(context.t('language')),
        Wrap(spacing: 8, children: [
          for (final e in S.languages.entries)
            ChoiceChip(label: Text(e.value), selected: app.lang == e.key, onSelected: (_) => app.setLanguage(e.key)),
        ]),
        SectionTitle(context.t('privacy_centre')),
        Card(
          child: Column(children: [
            SwitchListTile(
              value: app.appLock,
              onChanged: (v) async {
                final ok = await app.setAppLock(v);
                if (!ok && context.mounted) context.toast('Could not verify fingerprint / screen lock.');
              },
              title: Text(context.t('app_lock')),
              secondary: const Icon(Icons.fingerprint),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(context.t('my_consents')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _ConsentsScreen())),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(context.t('export_data')),
              onTap: () async {
                final json = await Db.exportUser(u.id);
                await Db.audit(u.id, 'data_exported');
                if (context.mounted) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ExportScreen(json: json)));
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text(context.t('audit_log')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AuditScreen())),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: EkkoColors.redDark),
              title: Text(context.t('erase_data'), style: const TextStyle(color: EkkoColors.redDark)),
              onTap: () => _confirmErase(context),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        const InfoBanner(
          'Security: database encrypted with SQLCipher (AES-256, key in Android Keystore) · identifiers masked · '
          'document photos never stored · screenshots blocked on KYC screens · HTTPS-only, no cloud backup.',
          icon: Icons.lock_outline,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            Navigator.of(context).popUntil((r) => r.isFirst);
            await app.logout();
          },
          icon: const Icon(Icons.logout),
          label: Text(context.t('logout')),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('Ekko 1.0 · Team Code Sync · Airtel Sync 2026',
              style: const TextStyle(color: EkkoColors.inkSoft, fontSize: 12)),
        ),
      ]),
    );
  }

  Future<void> _confirmErase(BuildContext context) async {
    final app = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(app.s.t('erase_data')),
        content: Text(app.s.t('erase_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(app.s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(app.s.t('erase'))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      await app.eraseEverything();
    }
  }
}

class _ConsentsScreen extends StatefulWidget {
  const _ConsentsScreen();
  @override
  State<_ConsentsScreen> createState() => _ConsentsScreenState();
}

class _ConsentsScreenState extends State<_ConsentsScreen> {
  late Future<Map<String, (bool, DateTime)>> _c = Repository.consents(context.read<AppState>().user!.id);

  static const _labels = {
    'kyc_verification': 'KYC verification for my orders',
    'marketing': 'Offers & tips on WhatsApp/SMS',
  };

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AppState>().user!.id;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('my_consents'))),
      body: FutureBuilder<Map<String, (bool, DateTime)>>(
        future: _c,
        builder: (context, snap) {
          final m = snap.data;
          if (m == null) return const Center(child: CircularProgressIndicator());
          if (m.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: InfoBanner('No consents given yet.'));
          return ListView(padding: const EdgeInsets.all(16), children: [
            for (final e in m.entries)
              Card(
                child: ListTile(
                  title: Text(_labels[e.key] ?? e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${e.value.$1 ? context.t('granted') : context.t('withdrawn')} · '
                      '${_fmt.format(e.value.$2)} · notice v${Repository.noticeVersion}'),
                  trailing: e.value.$1
                      ? TextButton(
                          onPressed: () async {
                            await Repository.recordConsent(uid, e.key, false);
                            setState(() => _c = Repository.consents(uid));
                          },
                          child: Text(context.t('withdraw')),
                        )
                      : const Icon(Icons.block, color: EkkoColors.inkSoft),
                ),
              ),
            const SizedBox(height: 8),
            const InfoBanner('Withdrawing KYC consent stops further processing; records the law requires us to keep '
                'are retained only for that period, then erased.'),
          ]);
        },
      ),
    );
  }
}

class _ExportScreen extends StatelessWidget {
  final String json;
  const _ExportScreen({required this.json});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.t('export_done'))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(json, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
      );
}

class _AuditScreen extends StatelessWidget {
  const _AuditScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.t('audit_log'))),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: Repository.auditLog(),
          builder: (context, snap) {
            final rows = snap.data;
            if (rows == null) return const Center(child: CircularProgressIndicator());
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final r = rows[i];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${r['action']}${r['detail'] == null ? '' : ' · ${r['detail']}'}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_fmt.format(DateTime.fromMillisecondsSinceEpoch(r['ts'] as int))),
                );
              },
            );
          },
        ),
      );
}
