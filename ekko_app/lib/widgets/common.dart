import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

final _inr = NumberFormat.decimalPattern('en_IN');
String rupees(num v) => '₹${_inr.format(v.round())}';

extension Ctx on BuildContext {
  AppState get app => read<AppState>();
  String t(String key, [Map<String, Object?> args = const {}]) => watch<AppState>().s.t(key, args);
  String tr(String key, [Map<String, Object?> args = const {}]) => read<AppState>().s.t(key, args);
  void toast(String msg) => ScaffoldMessenger.of(this)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;
  final IconData? icon;
  const Pill(this.text, {super.key, this.color = EkkoColors.red, this.bg = EkkoColors.redSoft, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final Color bg;
  const InfoBanner(this.text,
      {super.key, this.icon = Icons.info_outline, this.color = EkkoColors.inkSoft, this.bg = EkkoColors.surface});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13, height: 1.35))),
        ]),
      );
}

class TrustRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const TrustRow(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(color: EkkoColors.redSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: EkkoColors.red),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ]),
      );
}

class ModeBadge extends StatelessWidget {
  const ModeBadge({super.key});
  @override
  Widget build(BuildContext context) {
    final online = context.watch<AppState>().backend.online;
    return Pill(online ? context.t('badge_online') : context.t('badge_offline'),
        icon: online ? Icons.auto_awesome : Icons.offline_bolt_outlined,
        color: online ? EkkoColors.green : EkkoColors.inkSoft,
        bg: online ? EkkoColors.greenSoft : EkkoColors.surface);
  }
}

/// Bottom action area that respects the system navigation inset.
class BottomBar extends StatelessWidget {
  final List<Widget> children;
  const BottomBar({super.key, required this.children});
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: EkkoColors.line))),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      );
}
