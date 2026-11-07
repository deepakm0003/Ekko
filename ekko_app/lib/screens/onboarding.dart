import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class OnboardingScreen extends StatelessWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 20), children: [
          const EkkoLogo(size: 44),
          const SizedBox(height: 28),
          Text(context.t('intro_t'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.15, letterSpacing: -0.5)),
          const SizedBox(height: 18),
          TrustRow(Icons.chat_bubble_outline, context.t('intro_1')),
          TrustRow(Icons.currency_rupee, context.t('intro_2')),
          TrustRow(Icons.verified_user_outlined, context.t('intro_3')),
          const SizedBox(height: 28),
          Text(context.t('choose_language'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: [
              for (final e in S.languages.entries)
                _LangTile(
                  label: e.value,
                  selected: app.lang == e.key,
                  onTap: () => app.setLanguage(e.key),
                ),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () async {
              await app.setLanguage(app.lang);
              onDone();
            },
            child: Text(context.t('get_started')),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(context.t('tagline'), style: const TextStyle(color: EkkoColors.inkSoft, fontSize: 13)),
          ),
        ]),
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangTile({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: selected ? EkkoColors.redSoft : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? EkkoColors.red : EkkoColors.line, width: selected ? 1.8 : 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: selected ? EkkoColors.red : EkkoColors.ink)),
          ),
        ),
      );
}
