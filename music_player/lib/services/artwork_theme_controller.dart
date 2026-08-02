import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// 再生中の曲のジャケットから ColorScheme を作る。
/// このアプリの見た目上の主役で、曲が変わるとUI全体の色が移り変わる。
class ArtworkThemeController extends ChangeNotifier {
  final OnAudioQuery _query = OnAudioQuery();

  int? _lastAlbumId;
  ColorScheme? light;
  ColorScheme? dark;

  final Map<int, (ColorScheme, ColorScheme)> _cache = {};

  Future<void> updateFor(int? albumId) async {
    if (albumId == null) {
      if (_lastAlbumId == null) return;
      _lastAlbumId = null;
      light = null;
      dark = null;
      notifyListeners();
      return;
    }
    if (albumId == _lastAlbumId) return;
    _lastAlbumId = albumId;

    final cached = _cache[albumId];
    if (cached != null) {
      light = cached.$1;
      dark = cached.$2;
      notifyListeners();
      return;
    }

    try {
      final bytes = await _query.queryArtwork(
        albumId,
        ArtworkType.ALBUM,
        size: 200,
        quality: 80,
      );
      if (bytes == null || bytes.isEmpty) {
        light = null;
        dark = null;
        notifyListeners();
        return;
      }

      final image = MemoryImage(bytes);
      final l = await ColorScheme.fromImageProvider(
        provider: image,
        brightness: Brightness.light,
      );
      final d = await ColorScheme.fromImageProvider(
        provider: image,
        brightness: Brightness.dark,
      );

      // 別の曲に切り替わっていたら破棄する
      if (_lastAlbumId != albumId) return;

      _cache[albumId] = (l, d);
      light = l;
      dark = d;
      notifyListeners();
    } catch (e) {
      debugPrint('ジャケットからの配色生成に失敗しました: $e');
      light = null;
      dark = null;
      notifyListeners();
    }
  }
}
