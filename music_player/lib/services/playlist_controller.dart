import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// アプリ内プレイリスト。楽曲IDの並びだけを端末に保存する。
class Playlist {
  Playlist({required this.name, required this.songIds});

  String name;
  List<int> songIds;

  Map<String, dynamic> toJson() => {'name': name, 'songIds': songIds};

  static Playlist fromJson(Map<String, dynamic> j) => Playlist(
        name: j['name'] as String,
        songIds: (j['songIds'] as List).map((e) => e as int).toList(),
      );
}

class PlaylistController extends ChangeNotifier {
  static const _kPlaylists = 'playlists_v1';
  static const _kFavorites = 'favorites_v1';

  late SharedPreferences _prefs;

  List<Playlist> playlists = [];
  Set<int> favorites = {};

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    final raw = _prefs.getString(_kPlaylists);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      playlists = list
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    favorites = (_prefs.getStringList(_kFavorites) ?? [])
        .map(int.parse)
        .toSet();

    notifyListeners();
  }

  // ---- お気に入り ----

  bool isFavorite(int songId) => favorites.contains(songId);

  Future<void> toggleFavorite(int songId) async {
    if (!favorites.remove(songId)) favorites.add(songId);
    notifyListeners();
    await _prefs.setStringList(
      _kFavorites,
      favorites.map((e) => e.toString()).toList(),
    );
  }

  // ---- プレイリスト ----

  bool nameExists(String name) =>
      playlists.any((p) => p.name.trim() == name.trim());

  Future<void> create(String name, [List<int> ids = const []]) async {
    playlists.add(Playlist(name: name.trim(), songIds: [...ids]));
    await _persist();
  }

  Future<void> rename(int index, String name) async {
    playlists[index].name = name.trim();
    await _persist();
  }

  Future<void> delete(int index) async {
    playlists.removeAt(index);
    await _persist();
  }

  Future<void> addSong(int index, int songId) async {
    final p = playlists[index];
    if (!p.songIds.contains(songId)) p.songIds.add(songId);
    await _persist();
  }

  Future<void> addSongs(int index, List<int> songIds) async {
    final p = playlists[index];
    for (final id in songIds) {
      if (!p.songIds.contains(id)) p.songIds.add(id);
    }
    await _persist();
  }

  Future<void> removeSongAt(int index, int songIndex) async {
    playlists[index].songIds.removeAt(songIndex);
    await _persist();
  }

  Future<void> reorder(int index, int oldIndex, int newIndex) async {
    final ids = playlists[index].songIds;
    if (newIndex > oldIndex) newIndex -= 1;
    ids.insert(newIndex, ids.removeAt(oldIndex));
    await _persist();
  }

  Future<void> _persist() async {
    notifyListeners();
    await _prefs.setString(
      _kPlaylists,
      jsonEncode(playlists.map((p) => p.toJson()).toList()),
    );
  }
}
