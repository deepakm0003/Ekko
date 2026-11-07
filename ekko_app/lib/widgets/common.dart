import 'dart:math';

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
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16)));
}

/// White rounded surface with a soft shadow — the base of every card.
class EkkoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Border? border;
  const EkkoCard({super.key, required this.child, this.padding = const EdgeInsets.all(Sp.lg), this.onTap, this.color = Colors.white, this.border});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20), boxShadow: EkkoShadow.soft, border: border),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final String? subtitle;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.subtitle, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, Sp.xxl, 4, Sp.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(text, style: T.h3),
              if (subtitle != null) ...[const Gap(2), Text(subtitle!, style: T.small)],
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Rounded-square icon tile tinted in a brand colour.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final double size;
  const IconBadge(this.icon, {super.key, this.color = EkkoColors.red, this.bg = EkkoColors.redSoft, this.size = 40});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.32)),
        child: Icon(icon, color: color, size: size * 0.52),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(40)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const Gap(4)],
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Jakarta', color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final Color bg;
  const InfoBanner(this.text, {super.key, this.icon = Icons.info_outline_rounded, this.color = EkkoColors.inkSoft, this.bg = Colors.white});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: bg == Colors.white ? Border.all(color: EkkoColors.line, width: 1.3) : null,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 19, color: color),
          const Gap(10),
          Expanded(child: Text(text, style: TextStyle(fontFamily: 'Jakarta', color: color, fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w600))),
        ]),
      );
}

class TrustRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const TrustRow(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          IconBadge(icon, size: 36),
          const Gap(Sp.md),
          Expanded(child: Text(text, style: T.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600))),
        ]),
      );
}

class ModeBadge extends StatelessWidget {
  const ModeBadge({super.key});
  @override
  Widget build(BuildContext context) {
    final online = context.watch<AppState>().backend.online;
    return Pill(online ? context.t('badge_online') : context.t('badge_offline'),
        icon: online ? Icons.auto_awesome : Icons.bolt_rounded,
        color: online ? EkkoColors.green : EkkoColors.inkSoft,
        bg: online ? EkkoColors.greenSoft : Colors.white);
  }
}

/// Sticky bottom action area.
class BottomBar extends StatelessWidget {
  final List<Widget> children;
  const BottomBar({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Color(0x140F1115), blurRadius: 24, offset: Offset(0, -6))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.lg, Sp.xl, Sp.md),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      );
}

/// Label/value row used in summaries.
class KV extends StatelessWidget {
  final String k;
  final String v;
  final bool bold;
  final Color color;
  const KV(this.k, this.v, {super.key, this.bold = false, this.color = EkkoColors.ink});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(k, style: T.bodySoft.copyWith(color: color.withValues(alpha: 0.75), fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
          Text(v, style: T.body.copyWith(color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w700)),
        ]),
      );
}

/// Circular score gauge (0–100) with an optional "before" ghost arc.
class ScoreRing extends StatelessWidget {
  final int score;
  final int? before;
  final double size;
  final String caption;
  const ScoreRing({super.key, required this.score, this.before, this.size = 120, this.caption = ''});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: (before ?? 0).toDouble(), end: score.toDouble()),
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(v / 100, before == null ? null : before! / 100),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${v.round()}', style: TextStyle(fontFamily: 'Jakarta', fontSize: size * 0.3, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1)),
                if (caption.isNotEmpty) Text(caption, style: T.label.copyWith(fontSize: size * 0.085)),
              ]),
            ),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double value;
  final double? before;
  _RingPainter(this.value, this.before);
  @override
  void paint(Canvas canvas, Size s) {
    final stroke = s.width * 0.09;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, s.width - stroke, s.height - stroke);
    final track = Paint()
      ..color = EkkoColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi / 2, 2 * pi, false, track);
    if (before != null) {
      canvas.drawArc(rect, -pi / 2, 2 * pi * before!, false, track..color = const Color(0xFFD5D8DD));
    }
    final arc = Paint()
      ..shader = const SweepGradient(colors: [Color(0xFFFF5A5A), EkkoColors.red, EkkoColors.redDark], startAngle: 0, endAngle: 2 * pi, transform: GradientRotation(-pi / 2))
          .createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi / 2, 2 * pi * value.clamp(0.001, 1), false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.value != value || o.before != before;
}

/// Thin labelled progress bar.
class MeterBar extends StatelessWidget {
  final String label;
  final double value;
  final double? before;
  final String trailing;
  const MeterBar({super.key, required this.label, required this.value, this.before, this.trailing = ''});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label, style: T.bodySoft.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: EkkoColors.ink))),
            Text(trailing, style: T.small.copyWith(fontWeight: FontWeight.w700, color: EkkoColors.inkSoft)),
          ]),
          const Gap(6),
          LayoutBuilder(builder: (_, c) {
            return Stack(children: [
              Container(height: 8, decoration: BoxDecoration(color: EkkoColors.line, borderRadius: BorderRadius.circular(8))),
              if (before != null)
                Container(height: 8, width: c.maxWidth * before!.clamp(0, 1), decoration: BoxDecoration(color: const Color(0xFFCDD1D7), borderRadius: BorderRadius.circular(8))),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: before ?? 0, end: value.clamp(0, 1)),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Container(
                  height: 8,
                  width: c.maxWidth * v,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF4D4D), EkkoColors.red]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ]);
          }),
        ]),
      );
}

/// Red gradient hero surface with decorative circles.
class HeroPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const HeroPanel({super.key, required this.child, this.padding = const EdgeInsets.all(Sp.xxl)});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(colors: [Color(0xFFFF2B2B), EkkoColors.red, Color(0xFF9E0000)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: EkkoShadow.red,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(children: [
            Positioned(right: -40, top: -50, child: _circle(170, 0.10)),
            Positioned(right: 40, bottom: -70, child: _circle(140, 0.07)),
            Positioned(left: -30, bottom: -40, child: _circle(90, 0.06)),
            Padding(padding: padding, child: child),
          ]),
        ),
      );

  Widget _circle(double d, double a) =>
      Container(width: d, height: d, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: a)));
}

/// Dark summary surface (price cards).
class InkPanel extends StatelessWidget {
  final Widget child;
  const InkPanel({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(colors: [Color(0xFF1C1F26), EkkoColors.ink], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: EkkoShadow.lift,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(children: [
            Positioned(
              right: -60,
              top: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(shape: BoxShape.circle, color: EkkoColors.red.withValues(alpha: 0.22)),
              ),
            ),
            Padding(padding: const EdgeInsets.all(Sp.xl), child: child),
          ]),
        ),
      );
}

/// Category → icon, used for product rows.
IconData categoryIcon(String category) => switch (category) {
      'Connectivity' => Icons.wifi_rounded,
      'Communication' => Icons.forum_rounded,
      'Cloud & Productivity' => Icons.cloud_rounded,
      'Security' => Icons.shield_rounded,
      _ => Icons.videocam_rounded,
    };

IconData productIcon(String id) => const {
      'P01': Icons.wifi_rounded, 'P02': Icons.wifi_rounded, 'P03': Icons.network_check_rounded,
      'P04': Icons.cell_tower_rounded, 'P05': Icons.lan_rounded, 'P06': Icons.lan_rounded,
      'P07': Icons.sim_card_rounded, 'P08': Icons.sim_card_rounded, 'P09': Icons.sync_alt_rounded,
      'P10': Icons.hub_rounded, 'P11': Icons.pin_rounded, 'P12': Icons.support_agent_rounded,
      'P13': Icons.phone_in_talk_rounded, 'P14': Icons.sms_rounded, 'P15': Icons.chat_rounded,
      'P16': Icons.mail_rounded, 'P17': Icons.backup_rounded, 'P18': Icons.language_rounded,
      'P19': Icons.point_of_sale_rounded, 'P20': Icons.security_rounded, 'P21': Icons.local_fire_department_rounded,
      'P22': Icons.router_rounded, 'P23': Icons.videocam_rounded, 'P24': Icons.precision_manufacturing_rounded,
      'P25': Icons.local_shipping_rounded,
    }[id] ??
    Icons.widgets_rounded;
