import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Нейтральная графитовая шкала. Цвет несут акцент, аватар и данные, а не фон.
class AppColors {
  const AppColors._();

  static const deepest = Color(0xFF0F0F10);
  static const background = Color(0xFF141415);
  static const surface = Color(0xFF19191B);
  static const raised = Color(0xFF232325);
  static const textPrimary = Color(0xFFEDEDED);
  static const textSecondary = Color(0xFFA1A1A6);
  static const textMuted = Color(0xFF85858B);
  static const onAccent = Color(0xFF111111);
  static const hairline = Color(0x14EDEDED); // основной текст, 8%
}

/// Цвет интерфейса, который пользователь выбирает в профиле.
enum AccentOption {
  lime('Лайм', Color(0xFFC6FF3D)),
  ember('Раскалённый', Color(0xFFFF7A3D)),
  ice('Лёд', Color(0xFF3DDCFF)),
  violet('Сирень', Color(0xFFB79CFF));

  const AccentOption(this.label, this.color);

  final String label;
  final Color color;
}

class AppMotion {
  const AppMotion._();

  static const curve = Cubic(0.22, 1, 0.36, 1);
  static const fast = Duration(milliseconds: 160);
  static const enter = Duration(milliseconds: 400);
}

/// Крупные цифры (сила, уровни, опыт) набираются Unbounded.
TextStyle figureStyle({double size = 17, Color color = AppColors.textPrimary}) =>
    GoogleFonts.unbounded(
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

ThemeData buildTheme(Color accent) {
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark).copyWith(
    primary: accent,
    onPrimary: AppColors.onAccent,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.raised,
    outline: AppColors.hairline,
    outlineVariant: AppColors.hairline,
  );
  final baseText = ThemeData(brightness: Brightness.dark).textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      );

  return ThemeData(
    useMaterial3: true,
    // Классическая волна вместо «искр»: искрам на Android нужен шейдер,
    // который компилируется при первом нажатии и даёт рывок.
    splashFactory: InkRipple.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: GoogleFonts.inter().fontFamily,
    textTheme: baseText,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w500),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.hairline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.hairline),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.raised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.deepest,
      indicatorColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => GoogleFonts.inter(
          fontSize: 11,
          color: states.contains(WidgetState.selected)
              ? AppColors.textPrimary
              : AppColors.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 20,
          color: states.contains(WidgetState.selected)
              ? AppColors.textPrimary
              : AppColors.textMuted,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.hairline, thickness: 1),
  );
}
