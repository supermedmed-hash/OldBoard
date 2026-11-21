import 'package:flutter/material.dart';

/// État d'une valeur par rapport aux cotes constructeurs Audi A3 8L 1.6 AKL.
enum RangeStatus { unknown, low, normal, high }

/// Palette "Audi Sport OEM Pure" : lisibilité maximale, zéro flou, code couleur Bleu (trop bas) / Rouge (trop haut).
class Retro {
  static const bg = Color(0xFF070709);
  static const surface = Color(0xFF111216);
  static const surfaceHeader = Color(0xFF181920);
  static const surfaceElevated = Color(0xFF1E2028);
  static const border = Color(0xFF2C2E3A);
  static const borderSubtle = Color(0xFF20222B);

  static const white = Color(0xFFFFFFFF);
  static const titleWhite = Color(0xFFF4F4F6); // Titres ultra-lisibles
  static const silver = Color(0xFFD8D8E0);
  static const grey = Color(0xFFA0A4B4); // Sous-titres bien contrastés
  static const muted = Color(0xFF686C7E);

  static const red = Color(0xFFFF2438); // Trop haut (> cote max)
  static const blue = Color(0xFF2AB8FF); // Trop bas (< cote min)
  static const green = Color(0xFF10B981); // Dans les cotes
  static const amber = Color(0xFFF59E0B);

  // Compatibilité
  static const glow = red;
  static const face = surface;
  static const fisBg = surface;
  static const fisText = white;
  static const fisDim = border;

  static Color valueColor(RangeStatus s) => switch (s) {
        RangeStatus.low => blue,
        RangeStatus.high => red,
        RangeStatus.normal => white,
        RangeStatus.unknown => white,
      };

  static Color borderColor(RangeStatus s) => switch (s) {
        RangeStatus.low => blue,
        RangeStatus.high => red,
        RangeStatus.normal => border,
        RangeStatus.unknown => border,
      };

  static Color indicatorColor(RangeStatus s) => switch (s) {
        RangeStatus.low => blue,
        RangeStatus.high => red,
        RangeStatus.normal => green,
        RangeStatus.unknown => muted,
      };

  /// Typographie numérique ultra-nette à chasse fixe (sans aucun glow ni ombre).
  static TextStyle num(
    double size, {
    FontWeight w = FontWeight.w800,
    Color c = white,
    double letterSpacing = -0.8,
  }) =>
      TextStyle(
        fontSize: size,
        fontWeight: w,
        color: c,
        height: 1.0,
        letterSpacing: letterSpacing,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Titres de cases ultra-lisibles (blanc franc, gras, espacement net).
  static TextStyle title(double size, {Color c = titleWhite, FontWeight w = FontWeight.w800}) => TextStyle(
        fontSize: size,
        fontWeight: w,
        color: c,
        letterSpacing: 0.7,
        height: 1.15,
      );

  static TextStyle label(double size, {Color c = silver, FontWeight w = FontWeight.w700}) => TextStyle(
        fontSize: size,
        fontWeight: w,
        color: c,
        letterSpacing: 0.5,
        height: 1.1,
      );

  static TextStyle fis(double size, {FontWeight w = FontWeight.w700, Color c = white}) =>
      num(size, w: w, c: c, letterSpacing: -0.5);

  static ThemeData theme([Color accent = red]) => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.dark(
          primary: accent,
          secondary: blue,
          surface: surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          foregroundColor: white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: border, width: 1),
          ),
        ),
        useMaterial3: true,
      );
}
