import 'package:flutter/material.dart';

/// 既定のシード色。
/// 再生中のアルバムアートから配色を生成できない時のフォールバック。
const Color kDefaultSeed = Color(0xFFE0A458); // 真鍮色

/// 設定画面でユーザーが選べる固定シード色。
const List<({String name, Color color})> kSeedChoices = [
  (name: '真鍮', color: Color(0xFFE0A458)),
  (name: '深緑', color: Color(0xFF3F7D5B)),
  (name: '藍', color: Color(0xFF3D5A98)),
  (name: '梅', color: Color(0xFFB5546B)),
  (name: '墨', color: Color(0xFF6E7076)),
];

class AppTheme {
  static ThemeData light(ColorScheme scheme) => _base(scheme);

  static ThemeData dark(ColorScheme scheme, {bool amoled = false}) {
    final t = _base(scheme);
    if (!amoled) return t;
    // 有機ELの黒を活かすモード
    return t.copyWith(
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      colorScheme: scheme.copyWith(surface: Colors.black),
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        minVerticalPadding: 8,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.onSurface.withOpacity(0.15),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        clipBehavior: Clip.antiAlias,
      ),
    );
  }
}
