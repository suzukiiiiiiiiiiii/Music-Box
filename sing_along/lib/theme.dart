import 'package:flutter/material.dart';

class AccentChoice {
  const AccentChoice(this.name, this.color);

  final String name;
  final Color color;
}

const accentChoices = <AccentChoice>[
  AccentChoice('あお', Color(0xFF4A7DFF)),
  AccentChoice('みどり', Color(0xFF3FA96B)),
  AccentChoice('むらさき', Color(0xFF8B5CF6)),
  AccentChoice('だいだい', Color(0xFFF08C3A)),
  AccentChoice('あか', Color(0xFFE0524A)),
  AccentChoice('ももいろ', Color(0xFFE060A0)),
  AccentChoice('みずいろ', Color(0xFF39B3C7)),
  AccentChoice('きいろ', Color(0xFFD9A521)),
];

ThemeData buildTheme(Color seed, Brightness brightness, {bool amoled = false}) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final isDark = brightness == Brightness.dark;
  // 真っ黒背景は有機ELで消灯するぶん見た目が締まる。文字色はそのまま使う。
  final surface = isDark && amoled ? Colors.black : scheme.surface;

  return ThemeData(
    colorScheme: scheme.copyWith(surface: surface),
    useMaterial3: true,
    scaffoldBackgroundColor: surface,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
      height: 62,
    ),
    listTileTheme: const ListTileThemeData(
      horizontalTitleGap: 12,
      minVerticalPadding: 8,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      overlayShape: SliderComponentShape.noOverlay,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.15),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.onSurface.withValues(alpha: 0.08),
      space: 1,
      thickness: 1,
    ),
  );
}
