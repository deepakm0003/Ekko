import 'package:flutter/material.dart';

/// Ekko brand: white base, red accents, black text.
class EkkoColors {
  static const red = Color(0xFFE40000);
  static const redDark = Color(0xFFB30000);
  static const redSoft = Color(0xFFFFEBEB);
  static const ink = Color(0xFF111111);
  static const inkSoft = Color(0xFF5C5C5C);
  static const line = Color(0xFFE6E6E6);
  static const surface = Color(0xFFF7F7F7);
  static const white = Colors.white;
  static const green = Color(0xFF1B8A3A);
  static const greenSoft = Color(0xFFE7F5EB);
  static const amber = Color(0xFFB26A00);
  static const amberSoft = Color(0xFFFFF4E0);
}

ThemeData buildEkkoTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: EkkoColors.red,
    brightness: Brightness.light,
  ).copyWith(
    primary: EkkoColors.red,
    onPrimary: Colors.white,
    secondary: EkkoColors.ink,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: EkkoColors.ink,
    error: EkkoColors.redDark,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: Colors.white);
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: EkkoColors.ink, displayColor: EkkoColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: EkkoColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(color: EkkoColors.ink, fontSize: 18, fontWeight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: EkkoColors.red,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: EkkoColors.ink,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: EkkoColors.line, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: EkkoColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: EkkoColors.red, width: 1.6),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: EkkoColors.redSoft,
      side: const BorderSide(color: EkkoColors.line),
      labelStyle: const TextStyle(color: EkkoColors.ink, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: EkkoColors.line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: EkkoColors.line, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: EkkoColors.redSoft,
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(color: s.contains(WidgetState.selected) ? EkkoColors.red : EkkoColors.inkSoft)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? EkkoColors.red : EkkoColors.inkSoft)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? EkkoColors.red : null),
    ),
  );
}

/// The Ekko wordmark: a red rounded "e" badge + name. Our own mark, not a telco logo.
class EkkoLogo extends StatelessWidget {
  final double size;
  final bool showName;
  final Color nameColor;
  const EkkoLogo({super.key, this.size = 40, this.showName = true, this.nameColor = EkkoColors.ink});

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: EkkoColors.red, borderRadius: BorderRadius.circular(size * 0.3)),
      alignment: Alignment.center,
      child: Text('e',
          style: TextStyle(color: Colors.white, fontSize: size * 0.68, fontWeight: FontWeight.w900, height: 1.05)),
    );
    if (!showName) return badge;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      badge,
      SizedBox(width: size * 0.25),
      Text('ekko',
          style: TextStyle(
              color: nameColor, fontSize: size * 0.7, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
    ]);
  }
}
