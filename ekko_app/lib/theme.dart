import 'dart:math';

import 'package:flutter/material.dart';

/// Ekko design tokens: white/red/black brand on a soft grey canvas.
class EkkoColors {
  static const red = Color(0xFFE40000);
  static const redDark = Color(0xFFA30000);
  static const redSoft = Color(0xFFFFEEEE);
  static const redTint = Color(0xFFFFF6F6);
  static const ink = Color(0xFF0F1115);
  static const inkSoft = Color(0xFF4A4F57);
  static const muted = Color(0xFF8A9099);
  static const line = Color(0xFFECEEF1);
  static const canvas = Color(0xFFF5F6F8);
  static const surface = Color(0xFFF5F6F8);
  static const white = Colors.white;
  static const green = Color(0xFF14804A);
  static const greenSoft = Color(0xFFE6F6ED);
  static const amber = Color(0xFFA35F00);
  static const amberSoft = Color(0xFFFFF3DF);
  static const blue = Color(0xFF2456D8);
  static const blueSoft = Color(0xFFEAF0FF);
}

/// 4-pt spacing scale.
class Sp {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 20.0, xxl = 24.0, xxxl = 32.0;
}

class Gap extends StatelessWidget {
  final double size;
  const Gap(this.size, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}

class EkkoShadow {
  static const soft = [BoxShadow(color: Color(0x0F0F1115), blurRadius: 24, offset: Offset(0, 8))];
  static const lift = [BoxShadow(color: Color(0x1F0F1115), blurRadius: 30, offset: Offset(0, 12))];
  static const red = [BoxShadow(color: Color(0x40E40000), blurRadius: 24, offset: Offset(0, 10))];
}

class T {
  static const _f = 'Jakarta';
  static const display = TextStyle(fontFamily: _f, fontSize: 30, height: 1.12, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: EkkoColors.ink);
  static const h1 = TextStyle(fontFamily: _f, fontSize: 24, height: 1.2, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: EkkoColors.ink);
  static const h2 = TextStyle(fontFamily: _f, fontSize: 19, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: EkkoColors.ink);
  static const h3 = TextStyle(fontFamily: _f, fontSize: 16, height: 1.3, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: EkkoColors.ink);
  static const body = TextStyle(fontFamily: _f, fontSize: 15, height: 1.45, fontWeight: FontWeight.w500, color: EkkoColors.ink);
  static const bodySoft = TextStyle(fontFamily: _f, fontSize: 14, height: 1.45, fontWeight: FontWeight.w500, color: EkkoColors.inkSoft);
  static const small = TextStyle(fontFamily: _f, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w500, color: EkkoColors.muted);
  static const label = TextStyle(fontFamily: _f, fontSize: 12, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: EkkoColors.muted);
  static const money = TextStyle(fontFamily: _f, fontSize: 40, height: 1, fontWeight: FontWeight.w800, letterSpacing: -1.2, color: Colors.white);
}

ThemeData buildEkkoTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: EkkoColors.red, brightness: Brightness.light).copyWith(
    primary: EkkoColors.red,
    onPrimary: Colors.white,
    secondary: EkkoColors.ink,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: EkkoColors.ink,
    error: EkkoColors.redDark,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Jakarta',
    scaffoldBackgroundColor: EkkoColors.canvas,
    // InkRipple rather than InkSparkle: no runtime shader, so it is safe on
    // low-end GPUs and software-rendered emulators.
    splashFactory: InkRipple.splashFactory,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Jakarta', bodyColor: EkkoColors.ink, displayColor: EkkoColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: EkkoColors.canvas,
      foregroundColor: EkkoColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 4,
      titleTextStyle: TextStyle(fontFamily: 'Jakarta', color: EkkoColors.ink, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: EkkoColors.red,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE9C7C7),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: shape,
        elevation: 0,
        textStyle: const TextStyle(fontFamily: 'Jakarta', fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.1),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: EkkoColors.ink,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: EkkoColors.line, width: 1.5),
        shape: shape,
        textStyle: const TextStyle(fontFamily: 'Jakarta', fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: EkkoColors.red,
        textStyle: const TextStyle(fontFamily: 'Jakarta', fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: const TextStyle(color: EkkoColors.muted, fontWeight: FontWeight.w500),
      labelStyle: const TextStyle(color: EkkoColors.inkSoft, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: EkkoColors.line, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: EkkoColors.line, width: 1.5)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: EkkoColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: EkkoColors.red, width: 1.8)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: EkkoColors.redSoft,
      side: const BorderSide(color: EkkoColors.line, width: 1.3),
      labelStyle: const TextStyle(fontFamily: 'Jakarta', color: EkkoColors.ink, fontWeight: FontWeight.w600, fontSize: 14),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: const DividerThemeData(color: EkkoColors.line, space: 1, thickness: 1),
    listTileTheme: const ListTileThemeData(
      titleTextStyle: TextStyle(fontFamily: 'Jakarta', fontSize: 15, fontWeight: FontWeight.w600, color: EkkoColors.ink),
      subtitleTextStyle: TextStyle(fontFamily: 'Jakarta', fontSize: 13, fontWeight: FontWeight.w500, color: EkkoColors.muted),
      iconColor: EkkoColors.inkSoft,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      height: 70,
      indicatorColor: EkkoColors.redSoft,
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(color: s.contains(WidgetState.selected) ? EkkoColors.red : EkkoColors.muted, size: 24)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontFamily: 'Jakarta',
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          color: s.contains(WidgetState.selected) ? EkkoColors.red : EkkoColors.muted)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? EkkoColors.red : null),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? EkkoColors.red : EkkoColors.line),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: EkkoColors.muted, width: 1.6),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: EkkoColors.ink,
      contentTextStyle: const TextStyle(fontFamily: 'Jakarta', color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}

/// The Ekko mark: a red squircle with a white "e" and a signal arc.
class EkkoLogo extends StatelessWidget {
  final double size;
  final bool showName;
  final Color nameColor;
  final bool inverted;
  const EkkoLogo({super.key, this.size = 40, this.showName = true, this.nameColor = EkkoColors.ink, this.inverted = false});

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: inverted
            ? null
            : const LinearGradient(colors: [Color(0xFFFF2A2A), EkkoColors.red, EkkoColors.redDark],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
        color: inverted ? Colors.white : null,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: CustomPaint(painter: _MarkPainter(inverted ? EkkoColors.red : Colors.white)),
    );
    if (!showName) return badge;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      badge,
      SizedBox(width: size * 0.28),
      Text('ekko',
          style: TextStyle(fontFamily: 'Jakarta', color: nameColor, fontSize: size * 0.72, fontWeight: FontWeight.w800, letterSpacing: -1)),
    ]);
  }
}

class _MarkPainter extends CustomPainter {
  final Color color;
  _MarkPainter(this.color);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s.width * 0.11;
    final c = Offset(s.width * 0.47, s.height * 0.53);
    final r = s.width * 0.22;
    // "e": horizontal bar + open ring.
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), p);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), 0, pi * 1.72, false, p);
    // signal arc (top-right) = connectivity
    final p2 = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s.width * 0.075;
    canvas.drawArc(Rect.fromCircle(center: Offset(s.width * 0.47, s.height * 0.53), radius: s.width * 0.36), -pi * 0.42, pi * 0.32, false, p2);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) => old.color != color;
}
