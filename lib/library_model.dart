import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const _audioExtensions = {'.mp3', '.m4a', '.aac', '.flac', '.ogg', '.opus', '.wav'};

/// 端末を探して見つかった曲を保持する。結果は JSON に保存して次回起動を速くする。
class LibraryModel extends ChangeNotifier {
  List<Song> _songs = [];
  List<String> _folders = [];
  List<PlaylistData> _playlists = [];

  bool _scanning = false;
  int _scanned = 0;
  int _scanTotal = 0;
  String? _lastError;

  List<Song> get songs => _songs;
  List<String> get folders => _folders;
  List<PlaylistData> get playlists => _playlists;
  bool get scanning => _scanning;
  int get scanned => _scanned;
  int get scanTotal => _scanTotal;
  String? get lastError => _lastError;

  late Directory _appDir;
  late Directory _artDir;

  /// Android が既定で音楽を置く場所。ユーザーが何も足さなくてもここは見に行く。
  static const defaultFolders = [
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Podcasts',
  ];

  Future<void> load() async {
    _appDir = await getApplicationDocumentsDirectory();
    _artDir = Directory(p.join(_appDir.path, 'art'));
    if (!_artDir.existsSync()) _artDir.createSync(recursive: true);

    final prefs = await SharedPreferences.getInstance();
    _folders = prefs.getStringList('folders') ?? [];
    _playlists = (prefs.getStringList('playlists') ?? [])
        .map((s) => PlaylistData.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();

    final indexFile = File(p.join(_appDir.path, 'library.json'));
    if (indexFile.existsSync()) {
      try {
        final raw = jsonDecode(await indexFile.readAsString()) as List;
        _songs = raw
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .where((s) => File(s.path).existsSync())
            .toList();
      } catch (_) {
        _songs = [];
      }
    }
    notifyListeners();
  }

  Future<bool> requestPermission() async {
    // Android 13 以降は READ_MEDIA_AUDIO、それ以前は storage。両方試して片方通ればよい。
    final audio = await Permission.audio.request();
    if (audio.isGranted) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  Future<void> addFolder(String path) async {
    if (_folders.contains(path)) return;
    _folders = [..._folders, path];
    await _saveFolders();
    notifyListeners();
  }

  Future<void> removeFolder(String path) async {
    _folders = _folders.where((f) => f != path).toList();
    await _saveFolders();
    notifyListeners();
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('folders', _folders);
  }

  /// 対象フォルダを歩いて音楽ファイルを集め、タグを読む。
  Future<void> scan() async {
    if (_scanning) return;
    _scanning = true;
    _scanned = 0;
    _scanTotal = 0;
    _lastError = null;
    notifyListeners();

    try {
      final targets = <String>{...defaultFolders, ..._folders};
      final files = <File>[];

      for (final dirPath in targets) {
        final dir = Directory(dirPath);
        if (!dir.existsSync()) continue;
        try {
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is! File) continue;
            final ext = p.extension(entity.path).toLowerCase();
            if (_audioExtensions.contains(ext)) files.add(entity);
          }
        } catch (_) {
          // 読めないフォルダは黙って飛ばす
        }
      }

      _scanTotal = files.length;
      notifyListeners();

      // 既に読んだ曲はタグを読み直さない
      final known = {for (final s in _songs) s.path: s};
      final result = <Song>[];

      for (final file in files) {
        final cached = known[file.path];
        if (cached != null) {
          result.add(cached);
        } else {
          result.add(await _readSong(file));
        }
        _scanned++;
        if (_scanned % 25 == 0) notifyListeners();
      }

      result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      _songs = result;
      await _saveIndex();
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  /// タグ読み取り。パッケージの API 変更に巻き込まれないよう dynamic 越しに触り、
  /// 失敗したらファイル名から組み立てた Song に落とす。
  Future<Song> _readSong(File file) async {
    try {
      // readMetadata は同期関数。曲数が多いと一瞬引っかかるが、
      // ネイティブ実装を挟まないぶん機種差で壊れにくい。
      final dynamic md = readMetadata(file, getImage: true);

      String? str(dynamic v) {
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      final title = str(md.title) ?? p.basenameWithoutExtension(file.path);
      final artist = str(md.artist) ?? '不明なアーティスト';
      final album = str(md.album) ?? p.basename(p.dirname(file.path));
      Duration? duration;
      try {
        final d = md.duration;
        if (d is Duration) duration = d;
      } catch (_) {}

      final artPath = await _extractArt(file, md);

      return Song(
        path: file.path,
        title: title,
        artist: artist,
        album: album,
        duration: duration,
        artPath: artPath,
      );
    } catch (_) {
      return Song.fromPath(file.path);
    }
  }

  Future<String?> _extractArt(File file, dynamic md) async {
    try {
      final pics = md.pictures as List?;
      if (pics == null || pics.isEmpty) return null;
      final dynamic first = pics.first;
      final bytes = first.bytes as Uint8List?;
      if (bytes == null || bytes.isEmpty) return null;

      final name = '${md5.convert(utf8.encode(file.path))}.img';
      final out = File(p.join(_artDir.path, name));
      if (!out.existsSync()) await out.writeAsBytes(bytes);
      return out.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveIndex() async {
    final indexFile = File(p.join(_appDir.path, 'library.json'));
    await indexFile.writeAsString(jsonEncode(_songs.map((s) => s.toJson()).toList()));
  }

  // --- プレイリスト ---

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'playlists',
      _playlists.map((pl) => jsonEncode(pl.toJson())).toList(),
    );
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    if (name.trim().isEmpty) return;
    _playlists = [..._playlists, PlaylistData(name: name.trim(), paths: [])];
    await _savePlaylists();
  }

  Future<void> deletePlaylist(String name) async {
    _playlists = _playlists.where((pl) => pl.name != name).toList();
    await _savePlaylists();
  }

  Future<void> addToPlaylist(String name, String songPath) async {
    _playlists = _playlists.map((pl) {
      if (pl.name != name || pl.paths.contains(songPath)) return pl;
      return PlaylistData(name: pl.name, paths: [...pl.paths, songPath]);
    }).toList();
    await _savePlaylists();
  }

  Future<void> removeFromPlaylist(String name, String songPath) async {
    _playlists = _playlists.map((pl) {
      if (pl.name != name) return pl;
      return PlaylistData(
        name: pl.name,
        paths: pl.paths.where((s) => s != songPath).toList(),
      );
    }).toList();
    await _savePlaylists();
  }

  /// 並べ替え。[visiblePaths] は画面に出ている順のパス一覧で、[oldIndex] と
  /// [newIndex] はその上での位置。ファイルが消えた曲は一覧から抜けているため、
  /// 保存している paths の添字とは一致しない。パスを手がかりに突き合わせる。
  ///
  /// [newIndex] は ReorderableListView の onReorderItem が渡す、動かした曲を
  /// 抜いたあとの並びでの位置。呼ぶ側で -1 する必要はない。
  Future<void> reorderPlaylist(
    String name,
    int oldIndex,
    int newIndex,
    List<String> visiblePaths,
  ) async {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= visiblePaths.length) return;

    final moved = visiblePaths[oldIndex];
    // 動かした曲を抜いた並びで newIndex 番に来る曲。この曲の直前に差し込む。
    final rest = [...visiblePaths]..removeAt(oldIndex);
    final anchor = newIndex < rest.length ? rest[newIndex] : null;

    _playlists = _playlists.map((pl) {
      if (pl.name != name) return pl;
      final paths = [...pl.paths];
      final from = paths.indexOf(moved);
      if (from < 0) return pl;
      paths.removeAt(from);
      final to = anchor == null ? -1 : paths.indexOf(anchor);
      paths.insert(to < 0 ? paths.length : to, moved);
      return PlaylistData(name: pl.name, paths: paths);
    }).toList();
    await _savePlaylists();
  }

  /// プレイリストの中身を Song に解決する。消えたファイルは落とす。
  List<Song> songsOf(PlaylistData playlist) {
    final byPath = {for (final s in _songs) s.path: s};
    return playlist.paths
        .map((path) => byPath[path])
        .whereType<Song>()
        .toList();
  }

  List<Song> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _songs;
    return _songs.where((s) {
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q);
    }).toList();
  }

  Map<String, List<Song>> groupBy(String Function(Song) key) {
    final map = <String, List<Song>>{};
    for (final s in _songs) {
      map.putIfAbsent(key(s), () => []).add(s);
    }
    return map;
  }
}
