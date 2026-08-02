import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

enum SurfaceMode {
  light('ライト'),
  dark('ダーク'),
  amoled('真っ黒');

  const SurfaceMode(this.label);
  final String label;
}

/// 見た目に関する設定をまとめて持つ。値が変わるたびに保存して通知する。
class SettingsModel extends ChangeNotifier {
  SharedPreferences? _prefs;

  SurfaceMode _surface = SurfaceMode.dark;
  Color _accent = defaultAccent;
  bool _accentFromArt = false;
  double _radius = 14;
  double _density = 1.0; // 0.85 = 詰める / 1.15 = ゆったり
  double _textScale = 1.0;
  bool _showArtInList = true;
  ArtworkShape _artworkShape = ArtworkShape.rounded;
  bool _albumGrid = true;
  SongSort _songSort = SongSort.title;

  SurfaceMode get surface => _surface;
  Color get accent => _accent;
  bool get accentFromArt => _accentFromArt;
  double get radius => _radius;
  double get density => _density;
  double get textScale => _textScale;
  bool get showArtInList => _showArtInList;
  ArtworkShape get artworkShape => _artworkShape;
  bool get albumGrid => _albumGrid;
  SongSort get songSort => _songSort;

  static const defaultAccent = Color(0xFF6FD3C7);

  /// 選べるアクセント色。名前は設定画面にそのまま出る。
  static const presetAccents = <String, Color>{
    'ミント': defaultAccent,
    'サンセット': Color(0xFFF2765A),
    'ラベンダー': Color(0xFF9B8CFF),
    'レモン': Color(0xFFE3C34A),
    'サクラ': Color(0xFFF08BB0),
    'アイス': Color(0xFF63A6F5),
    'モス': Color(0xFF8FB25B),
    'グレー': Color(0xFFA0A6AD),
  };

  /// プリセットのどれとも一致しない色なら、自分で作った色とみなす。
  bool get accentIsCustom => !presetAccents.values
      .any((c) => c.toARGB32() == _accent.toARGB32());

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;
    _surface = _readEnum(prefs.getInt('surface'), SurfaceMode.values, SurfaceMode.dark);
    _accent = Color(prefs.getInt('accent') ?? defaultAccent.toARGB32());
    _accentFromArt = prefs.getBool('accentFromArt') ?? false;
    _radius = prefs.getDouble('radius') ?? 14;
    _density = prefs.getDouble('density') ?? 1.0;
    _textScale = prefs.getDouble('textScale') ?? 1.0;
    _showArtInList = prefs.getBool('showArtInList') ?? true;
    _artworkShape =
        _readEnum(prefs.getInt('artShape'), ArtworkShape.values, ArtworkShape.rounded);
    _albumGrid = prefs.getBool('albumGrid') ?? true;
    _songSort = _readEnum(prefs.getInt('songSort'), SongSort.values, SongSort.title);
    notifyListeners();
  }

  /// 保存された添字が範囲外でも落ちないようにする。
  static T _readEnum<T>(int? index, List<T> values, T fallback) {
    if (index == null || index < 0 || index >= values.length) return fallback;
    return values[index];
  }

  void _save(void Function(SharedPreferences p) write) {
    final prefs = _prefs;
    if (prefs != null) write(prefs);
    notifyListeners();
  }

  set surface(SurfaceMode v) {
    _surface = v;
    _save((p) => p.setInt('surface', v.index));
  }

  set accent(Color v) {
    _accent = v;
    _save((p) => p.setInt('accent', v.toARGB32()));
  }

  set accentFromArt(bool v) {
    _accentFromArt = v;
    _save((p) => p.setBool('accentFromArt', v));
  }

  set radius(double v) {
    _radius = v;
    _save((p) => p.setDouble('radius', v));
  }

  set density(double v) {
    _density = v;
    _save((p) => p.setDouble('density', v));
  }

  set textScale(double v) {
    _textScale = v;
    _save((p) => p.setDouble('textScale', v));
  }

  set showArtInList(bool v) {
    _showArtInList = v;
    _save((p) => p.setBool('showArtInList', v));
  }

  set artworkShape(ArtworkShape v) {
    _artworkShape = v;
    _save((p) => p.setInt('artShape', v.index));
  }

  set albumGrid(bool v) {
    _albumGrid = v;
    _save((p) => p.setBool('albumGrid', v));
  }

  set songSort(SongSort v) {
    _songSort = v;
    _save((p) => p.setInt('songSort', v.index));
  }

  void resetToDefaults() {
    _surface = SurfaceMode.dark;
    _accent = defaultAccent;
    _accentFromArt = false;
    _radius = 14;
    _density = 1.0;
    _textScale = 1.0;
    _showArtInList = true;
    _artworkShape = ArtworkShape.rounded;
    _albumGrid = true;
    _save((p) {
      p.setInt('surface', _surface.index);
      p.setInt('accent', _accent.toARGB32());
      p.setBool('accentFromArt', _accentFromArt);
      p.setDouble('radius', _radius);
      p.setDouble('density', _density);
      p.setDouble('textScale', _textScale);
      p.setBool('showArtInList', _showArtInList);
      p.setInt('artShape', _artworkShape.index);
      p.setBool('albumGrid', _albumGrid);
    });
  }
}
