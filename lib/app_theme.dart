import 'package:flutter/material.dart';

import 'settings_model.dart';

/// 設定の値から ThemeData を組み立てる。画面側は色を直書きせず必ずここを通す。
ThemeData buildTheme(SettingsModel s, {Color? artAccent}) {
  final accent = (s.accentFromArt && artAccent != null) ? artAccent : s.accent;
  final isLight = s.surface == SurfaceMode.light;

  final Color background;
  final Color card;
  switch (s.surface) {
    case SurfaceMode.light:
      background = const Color(0xFFF7F6F3);
      card = Colors.white;
      break;
    case SurfaceMode.dark:
      background = const Color(0xFF14161A);
      card = const Color(0xFF1E2127);
      break;
    case SurfaceMode.amoled:
      background = Colors.black;
      card = const Color(0xFF0D0D0D);
      break;
  }

  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: isLight ? Brightness.light : Brightness.dark,
  ).copyWith(
    primary: accent,
    surface: background,
    surfaceContainerHighest: card,
  );

  final radius = BorderRadius.circular(s.radius);
  final base = isLight ? ThemeData.light() : ThemeData.dark();

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20 * s.textScale,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radius),
      margin: EdgeInsets.zero,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: radius),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: (s.density - 1.0) * 8,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.15),
      thumbColor: accent,
      trackHeight: 3,
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: _readableOn(accent),
        shape: RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: radius),
      side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.12)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.onSurface.withValues(alpha: 0.08),
      thickness: 1,
      space: 1,
    ),
    textTheme: base.textTheme.apply(fontSizeFactor: s.textScale),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(s.radius + 8)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      indicatorColor: accent.withValues(alpha: 0.22),
      elevation: 0,
      height: 64 * s.density,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11 * s.textScale,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder:
          OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
}

/// アクセント色の上に置く文字色。明るい色なら黒、暗い色なら白。
Color _readableOn(Color c) =>
    c.computeLuminance() > 0.5 ? Colors.black : Colors.white;

Color readableOn(Color c) => _readableOn(c);
