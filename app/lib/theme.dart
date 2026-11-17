import 'package:flutter/material.dart';

/// Тёплая графитовая шкала стиля «Закат» (docs/REDESIGN.md) — общая для всех стилей:
/// стили меняют только акценты. Цвет несут акцент, аватар и данные, а не фон.
class AppColors {
  const AppColors._();

  static const deepest = Color(0xFF0C0809);
  static const background = Color(0xFF120D10);
  static const surface = Color(0xFF1E171A);
  static const raised = Color(0xFF2A2025);
  static const textPrimary = Color(0xFFF3EAEC);
  static const textSecondary = Color(0xFFBFB0B5);
  static const textMuted = Color(0xFF9F8F95);
  static const onAccent = Color(0xFF220806);
  static const hairline = Color(0x14F3EAEC); // основной текст, 8%

  /// Успех и пульс — одинаковые во всех стилях.
  static const success = Color(0xFF3CC6B4);
}

/// Стиль интерфейса (Настройки → «Стиль»): цвет кнопок, «магии» (ауры, уровни, сила)
/// и серии. «Закат» — основной; «Кузня» и «Аметист» — на выбор.
enum AccentOption {
  sunset(
    'Закат',
    'Коралловые кнопки, сиреневая магия',
    Color(0xFFFF6B5A),
    Color(0xFF220806),
    Color(0xFFB48CFF),
    Color(0xFFFFB547),
  ),
  forge(
    'Кузня',
    'Раскалённые кнопки, фиолетовая магия',
    Color(0xFFFF7A1A),
    Color(0xFF1A0B00),
    Color(0xFFA285FF),
    Color(0xFFFF9E3D),
  ),
  amethyst(
    'Аметист',
    'Фиолетовые кнопки, огненная серия',
    Color(0xFFA285FF),
    Color(0xFF120A2A),
    Color(0xFFC9B6FF),
    Color(0xFFFF8A3D),
  );

  const AccentOption(
    this.label,
    this.hint,
    this.color,
    this.onColor,
    this.magic,
    this.streak,
  );

  final String label;
  final String hint;

  /// Главные кнопки и выбранное.
  final Color color;
  final Color onColor;

  /// Ауры, уровни, сила (colorScheme.secondary).
  final Color magic;

  /// Серия и огонь (colorScheme.tertiary).
  final Color streak;

  /// Сохранённый стиль; прежние акценты (лайм, лёд и др., до 17.11.2026) —
  /// на основной «Закат»: «Кузню» и «Аметист» выбирают сами.
  static AccentOption fromSaved(String? name) =>
      values.asNameMap()[name] ?? sunset;
}

class AppMotion {
  const AppMotion._();

  static const curve = Cubic(0.22, 1, 0.36, 1);
  static const fast = Duration(milliseconds: 160);
  static const enter = Duration(milliseconds: 400);
}

/// Шрифт заголовков и крупных цифр (стиль «Закат»).
const displayFont = 'RussoOne';

/// Крупные цифры (сила, уровни, опыт) набираются Russo One.
TextStyle figureStyle({
  double size = 17,
  Color color = AppColors.textPrimary,
}) => TextStyle(
  fontFamily: displayFont,
  fontSize: size,
  fontWeight: FontWeight.w400,
  color: color,
  height: 1,
  fontFeatures: const [FontFeature.tabularFigures()],
);

const _inter = 'Inter';

ThemeData buildTheme(AccentOption style) {
  final accent = style.color;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: accent,
        onPrimary: style.onColor,
        secondary: style.magic,
        tertiary: style.streak,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.raised,
        outline: AppColors.hairline,
        outlineVariant: AppColors.hairline,
      );
  // Inter для всего текста: без fontFamily здесь textTheme остаётся на Roboto,
  // а Inter получают только кнопки и вкладки — шрифты на экране смешиваются.
  final baseText = ThemeData(brightness: Brightness.dark).textTheme.apply(
    fontFamily: _inter,
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
    fontFamily: _inter,
    textTheme: baseText,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: _inter,
        fontSize: 17,
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      // Без рамки (docs/REDESIGN.md): рамка у всего подряд стирала разницу между
      // кнопкой и текстом. Глубина — ступенью поверхности над фоном.
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        textStyle: TextStyle(
          fontFamily: _inter,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.hairline),
        textStyle: TextStyle(
          fontFamily: _inter,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    // Переключатели «Лестница / Друзья»: выбранное — ступень поверхности и
    // основной текст, без окраски из сгенерированной палитры (была мутно-коричневой).
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.raised
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.textPrimary
              : AppColors.textSecondary,
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.hairline),
        ),
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
        (states) => TextStyle(
          fontFamily: _inter,
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
    dividerTheme: const DividerThemeData(
      color: AppColors.hairline,
      thickness: 1,
    ),
  );
}
