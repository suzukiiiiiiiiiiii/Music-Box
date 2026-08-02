import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import '../theme.dart';

/// 表示まわりの設定。すべて端末内に保存する。
class SettingsService extends ChangeNotifier {
  static const _kThemeMode = 'themeMode';
  static const _kSeed = 'seed';
  static const _kAmoled = 'amoled';
  static const _kSongSort = 'songSort';
  static const _kSongSortDesc = 'songSortDesc';
  static const _kOpenLyrics = 'openLyrics';

  ThemeMode themeMode = ThemeMode.dark;
  int seedIndex = 0;
  bool amoled = false;
  SongSort songSort = SongSort.title;
  bool songSortDescending = false;

  /// 再生画面を開いたとき、最初から歌詞の面を見せるか。
  bool openOnLyrics = false;

  Color get seedColor => accentChoices[seedIndex].color;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode =
        ThemeMode.values[prefs.getInt(_kThemeMode) ?? ThemeMode.dark.index];
    seedIndex = (prefs.getInt(_kSeed) ?? 0).clamp(0, accentChoices.length - 1);
    amoled = prefs.getBool(_kAmoled) ?? false;
    songSort = SongSort.values[prefs.getInt(_kSongSort) ?? 0];
    songSortDescending = prefs.getBool(_kSongSortDesc) ?? false;
    openOnLyrics = prefs.getBool(_kOpenLyrics) ?? false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _prefs((p) => p.setInt(_kThemeMode, mode.index));
  }

  Future<void> setSeedIndex(int index) async {
    seedIndex = index;
    notifyListeners();
    await _prefs((p) => p.setInt(_kSeed, index));
  }

  Future<void> setAmoled(bool value) async {
    amoled = value;
    notifyListeners();
    await _prefs((p) => p.setBool(_kAmoled, value));
  }

  Future<void> setSongSort(SongSort sort) async {
    songSort = sort;
    notifyListeners();
    await _prefs((p) => p.setInt(_kSongSort, sort.index));
  }

  Future<void> setSongSortDescending(bool value) async {
    songSortDescending = value;
    notifyListeners();
    await _prefs((p) => p.setBool(_kSongSortDesc, value));
  }

  Future<void> setOpenOnLyrics(bool value) async {
    openOnLyrics = value;
    notifyListeners();
    await _prefs((p) => p.setBool(_kOpenLyrics, value));
  }

  Future<void> _prefs(Future<void> Function(SharedPreferences) action) async {
    action(await SharedPreferences.getInstance());
  }
}
