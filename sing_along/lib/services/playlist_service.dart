import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/playlist.dart';

/// プレイリストとお気に入りの保存。
class PlaylistService extends ChangeNotifier {
  static const _kPlaylists = 'playlists';
  static const _kFavorites = 'favorites';

  List<Playlist> _playlists = [];
  Set<String> _favorites = {};

  List<Playlist> get playlists => List.unmodifiable(_playlists);
  Set<String> get favorites => _favorites;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _playlists = (prefs.getStringList(_kPlaylists) ?? [])
        .map((s) {
          try {
            return Playlist.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Playlist>()
        .toList();
    _favorites = (prefs.getStringList(_kFavorites) ?? []).toSet();
    notifyListeners();
  }

  bool isFavorite(String path) => _favorites.contains(path);

  Future<void> toggleFavorite(String path) async {
    if (!_favorites.remove(path)) _favorites.add(path);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFavorites, _favorites.toList());
  }

  bool nameExists(String name) =>
      _playlists.any((p) => p.name.trim() == name.trim());

  Future<void> create(String name, [List<String> paths = const []]) async {
    _playlists.add(Playlist(name: name.trim(), paths: [...paths]));
    await _persist();
  }

  Future<void> rename(int index, String name) async {
    _playlists[index].name = name.trim();
    await _persist();
  }

  Future<void> delete(int index) async {
    _playlists.removeAt(index);
    await _persist();
  }

  Future<void> addPaths(int index, List<String> paths) async {
    final target = _playlists[index];
    for (final path in paths) {
      if (!target.paths.contains(path)) target.paths.add(path);
    }
    await _persist();
  }

  Future<void> removeAt(int index, int songIndex) async {
    _playlists[index].paths.removeAt(songIndex);
    await _persist();
  }

  Future<void> reorder(int index, int oldIndex, int newIndex) async {
    final paths = _playlists[index].paths;
    if (newIndex > oldIndex) newIndex -= 1;
    paths.insert(newIndex, paths.removeAt(oldIndex));
    await _persist();
  }

  Future<void> _persist() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kPlaylists,
      _playlists.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }
}
