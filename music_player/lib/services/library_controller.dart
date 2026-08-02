import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

enum LibraryState { loading, ready, noPermission, empty }

/// 端末内（MediaStore）の楽曲・アルバム・アーティストを読み込む。
class LibraryController extends ChangeNotifier {
  final OnAudioQuery _query = OnAudioQuery();

  LibraryState state = LibraryState.loading;
  List<SongModel> songs = [];
  List<AlbumModel> albums = [];
  List<ArtistModel> artists = [];

  /// 30秒未満のファイルは着信音や効果音のことが多いので除外する。
  static const int _minDurationMs = 30 * 1000;

  Future<void> load() async {
    state = LibraryState.loading;
    notifyListeners();

    if (!await _ensurePermission()) {
      state = LibraryState.noPermission;
      notifyListeners();
      return;
    }

    final all = await _query.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    songs = all
        .where((s) =>
            s.isMusic == true &&
            (s.duration ?? 0) >= _minDurationMs &&
            (s.uri?.isNotEmpty ?? false))
        .toList();

    albums = await _query.queryAlbums(
      sortType: AlbumSortType.ALBUM,
      orderType: OrderType.ASC_OR_SMALLER,
      ignoreCase: true,
    );

    artists = await _query.queryArtists(
      sortType: ArtistSortType.ARTIST,
      orderType: OrderType.ASC_OR_SMALLER,
      ignoreCase: true,
    );

    state = songs.isEmpty ? LibraryState.empty : LibraryState.ready;
    notifyListeners();
  }

  Future<List<SongModel>> songsOfAlbum(int albumId) => _byId(
        AudiosFromType.ALBUM_ID,
        albumId.toString(),
        SongSortType.TITLE,
      );

  Future<List<SongModel>> songsOfArtist(int artistId) => _byId(
        AudiosFromType.ARTIST_ID,
        artistId.toString(),
        SongSortType.ALBUM,
      );

  Future<List<SongModel>> _byId(
    AudiosFromType type,
    String where,
    SongSortType sort,
  ) async {
    final result = await _query.queryAudiosFrom(type, where, sortType: sort);
    return result
        .where((s) => s.isMusic == true && (s.duration ?? 0) >= _minDurationMs)
        .toList();
  }

  /// idの並び順を保ったまま SongModel に解決する（プレイリスト用）。
  List<SongModel> resolve(List<int> ids) {
    final map = {for (final s in songs) s.id: s};
    return [
      for (final id in ids)
        if (map[id] != null) map[id]!,
    ];
  }

  List<SongModel> search(String q) {
    final k = q.trim().toLowerCase();
    if (k.isEmpty) return const [];
    return songs.where((s) {
      return s.title.toLowerCase().contains(k) ||
          (s.artist ?? '').toLowerCase().contains(k) ||
          (s.album ?? '').toLowerCase().contains(k);
    }).toList();
  }

  /// Android 13以上は READ_MEDIA_AUDIO、それ未満は READ_EXTERNAL_STORAGE。
  Future<bool> _ensurePermission() async {
    if (await Permission.audio.isGranted) return true;
    if (await Permission.storage.isGranted) return true;

    if (await Permission.audio.request().isGranted) return true;
    if (await Permission.storage.request().isGranted) return true;
    return false;
  }

  Future<void> openSettings() => openAppSettings();
}
