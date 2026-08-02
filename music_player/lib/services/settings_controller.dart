import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// 表示まわりのユーザー設定。すべて端末内に保存する。
class SettingsController extends ChangeNotifier {
  static const _kThemeMode = 'theme_mode';
  static const _kSeedIndex = 'seed_index';
  static const _kAmoled = 'amoled';
  static const _kArtColor = 'art_color';
  static const _kGridAlbums = 'grid_albums';

  late SharedPreferences _prefs;

  ThemeMode themeMode = ThemeMode.dark;
  int seedIndex = 0;
  bool amoled = false;

  /// 再生中のアルバムアートから配色を生成するか。
  bool followArtwork = true;
  bool albumsAsGrid = true;

  Color get seedColor => kSeedChoices[seedIndex].color;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[_prefs.getInt(_kThemeMode) ?? ThemeMode.dark.index];
    seedIndex = (_prefs.getInt(_kSeedIndex) ?? 0).clamp(0, kSeedChoices.length - 1);
    amoled = _prefs.getBool(_kAmoled) ?? false;
    followArtwork = _prefs.getBool(_kArtColor) ?? true;
    albumsAsGrid = _prefs.getBool(_kGridAlbums) ?? true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _prefs.setInt(_kThemeMode, mode.index);
  }

  Future<void> setSeedIndex(int i) async {
    seedIndex = i;
    notifyListeners();
    await _prefs.setInt(_kSeedIndex, i);
  }

  Future<void> setAmoled(bool v) async {
    amoled = v;
    notifyListeners();
    await _prefs.setBool(_kAmoled, v);
  }

  Future<void> setFollowArtwork(bool v) async {
    followArtwork = v;
    notifyListeners();
    await _prefs.setBool(_kArtColor, v);
  }

  Future<void> setAlbumsAsGrid(bool v) async {
    albumsAsGrid = v;
    notifyListeners();
    await _prefs.setBool(_kGridAlbums, v);
  }
}
