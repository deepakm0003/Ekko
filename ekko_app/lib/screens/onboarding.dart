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
        child: ListView(padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.lg, Sp.xl, Sp.xl), children: [
          HeroPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const EkkoLogo(size: 38, inverted: true, nameColor: Colors.white),
              const Gap(Sp.xxl),
              Text(context.t('intro_t'), style: T.display.copyWith(color: Colors.white, fontSize: 28)),
              const Gap(Sp.md),
              Text(context.t('tagline'), style: T.body.copyWith(color: Colors.white.withValues(alpha: 0.85))),
              const Gap(Sp.xl),
              const _FlowStrip(),
            ]),
          ),
          const Gap(Sp.xl),
          TrustRow(Icons.forum_rounded, context.t('intro_1')),
          TrustRow(Icons.currency_rupee_rounded, context.t('intro_2')),
          TrustRow(Icons.verified_user_rounded, context.t('intro_3')),
          const Gap(Sp.xl),
          Text(context.t('choose_language'), style: T.h3),
          const Gap(Sp.md),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Sp.md,
            crossAxisSpacing: Sp.md,
            childAspectRatio: 2.7,
            children: [
              for (final e in S.languages.entries)
                _LangTile(label: e.value, selected: app.lang == e.key, onTap: () => app.setLanguage(e.key)),
            ],
          ),
          const Gap(Sp.xxl),
          FilledButton(
            onPressed: () async {
              await app.setLanguage(app.lang);
              onDone();
            },
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(context.t('get_started')),
              const Gap(Sp.sm),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Advise → Price → KYC → Live, as a compact visual strip.
class _FlowStrip extends StatelessWidget {
  const _FlowStrip();
  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.chat_bubble_rounded, 'Advise'),
      (Icons.receipt_long_rounded, 'Price'),
      (Icons.badge_rounded, 'KYC'),
      (Icons.rocket_launch_rounded, 'Live'),
    ];
    return Row(children: [
      for (var i = 0; i < steps.length; i++) ...[
        Expanded(
          child: Column(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
              child: Icon(steps[i].$1, color: Colors.white, size: 22),
            ),
            const Gap(6),
            Text(steps[i].$2, style: T.label.copyWith(color: Colors.white, letterSpacing: 0.2)),
          ]),
        ),
        if (i < steps.length - 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.6), size: 18),
          ),
      ],
    ]);
  }
}

class _LangTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangTile({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? EkkoColors.redSoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? EkkoColors.red : EkkoColors.line, width: selected ? 2 : 1.4),
          boxShadow: selected ? null : EkkoShadow.soft,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (selected) ...[const Icon(Icons.check_circle_rounded, color: EkkoColors.red, size: 18), const Gap(6)],
              Text(label, style: T.h3.copyWith(fontSize: 17, color: selected ? EkkoColors.red : EkkoColors.ink)),
            ]),
          ),
        ),
      );
}
