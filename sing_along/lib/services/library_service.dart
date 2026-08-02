import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lyrics.dart';
import '../models/song.dart';

const audioExtensions = {
  '.mp3',
  '.m4a',
  '.aac',
  '.flac',
  '.ogg',
  '.opus',
  '.wav',
  '.wma',
};

/// アルバム1枚ぶん。曲から組み立てる。
class Album {
  Album(this.name, this.artist, this.songs);

  final String name;
  final String artist;
  final List<Song> songs;

  String? get artPath {
    for (final s in songs) {
      if (s.artPath != null) return s.artPath;
    }
    return null;
  }
}

/// アーティスト1人ぶん。
class Artist {
  Artist(this.name, this.songs);

  final String name;
  final List<Song> songs;

  int get albumCount => songs.map((s) => s.album).toSet().length;
}

/// 端末内の音楽ファイルを集めて持つ。
///
/// MediaStore ではなくファイルを直接歩く。muziki と同じ考え方で、
/// フォルダの構造をそのまま見せたいのと、`.lrc` が曲の隣に置いてあることが
/// 多いのが理由。
class LibraryService extends ChangeNotifier {
  List<Song> _songs = [];
  List<String> _roots = [];
  bool _scanning = false;
  int _scanned = 0;
  int _scanTotal = 0;
  String? _lastError;

  List<Song> get songs => _songs;
  List<String> get roots => _roots;
  bool get scanning => _scanning;
  int get scanned => _scanned;
  int get scanTotal => _scanTotal;
  String? get lastError => _lastError;
  bool get isEmpty => _songs.isEmpty;

  late Directory _appDir;
  late Directory _artDir;

  final Map<String, Song> _byPath = {};

  /// 読み込んだ歌詞の置き場。曲を切り替えるたびにファイルを読み直さない。
  final Map<String, Lyrics> _lyricsCache = {};

  /// 何も設定しなくても見に行く場所。
  static const defaultRoots = [
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Podcasts',
  ];

  /// フォルダ表示の入口。
  static const storageRoot = '/storage/emulated/0';

  Song? songAt(String path) => _byPath[path];

  List<Song> resolve(Iterable<String> paths) => [
        for (final path in paths)
          if (_byPath[path] != null) _byPath[path]!,
      ];

  /// テストから曲を差し込む。端末を読みに行かずに集計や絞り込みを試せる。
  @visibleForTesting
  void seed(List<Song> songs) {
    _songs = songs;
    _reindex();
    notifyListeners();
  }

  Future<void> load() async {
    _appDir = await getApplicationDocumentsDirectory();
    _artDir = Directory(p.join(_appDir.path, 'art'));
    if (!_artDir.existsSync()) _artDir.createSync(recursive: true);

    final prefs = await SharedPreferences.getInstance();
    _roots = prefs.getStringList('roots') ?? [];

    final index = File(p.join(_appDir.path, 'library.json'));
    if (index.existsSync()) {
      try {
        final raw = jsonDecode(await index.readAsString()) as List;
        _songs = raw
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .where((s) => File(s.path).existsSync())
            .toList();
      } catch (_) {
        // 壊れていたら作り直す
        _songs = [];
      }
    }
    _reindex();
    notifyListeners();
  }

  /// Android 13 以降は READ_MEDIA_AUDIO、それ以前は storage。
  Future<bool> requestPermission() async {
    if (await Permission.audio.isGranted) return true;
    if (await Permission.storage.isGranted) return true;
    if ((await Permission.audio.request()).isGranted) return true;
    return (await Permission.storage.request()).isGranted;
  }

  Future<void> addRoot(String path) async {
    if (_roots.contains(path)) return;
    _roots = [..._roots, path];
    await _saveRoots();
    notifyListeners();
  }

  Future<void> removeRoot(String path) async {
    _roots = _roots.where((r) => r != path).toList();
    await _saveRoots();
    notifyListeners();
  }

  Future<void> _saveRoots() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('roots', _roots);
  }

  /// 対象フォルダを歩いて曲を集める。すでに読んだファイルはタグを読み直さない。
  Future<void> scan() async {
    if (_scanning) return;
    _scanning = true;
    _scanned = 0;
    _scanTotal = 0;
    _lastError = null;
    notifyListeners();

    try {
      if (!await requestPermission()) {
        _lastError = '音楽ファイルを読む権限がありません';
        return;
      }

      final files = <File>[];
      for (final root in {...defaultRoots, ..._roots}) {
        final dir = Directory(root);
        if (!dir.existsSync()) continue;
        try {
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is! File) continue;
            if (audioExtensions.contains(p.extension(entity.path).toLowerCase())) {
              files.add(entity);
            }
          }
        } catch (_) {
          // 読めないフォルダは黙って飛ばす
        }
      }

      _scanTotal = files.length;
      notifyListeners();

      final known = {for (final s in _songs) s.path: s};
      final result = <Song>[];
      for (final file in files) {
        result.add(known[file.path] ?? await _read(file));
        _scanned++;
        if (_scanned % 25 == 0) notifyListeners();
      }

      _songs = result;
      _reindex();
      await _saveIndex();
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  void _reindex() {
    _byPath
      ..clear()
      ..addEntries(_songs.map((s) => MapEntry(s.path, s)));
  }

  Future<void> _saveIndex() async {
    final file = File(p.join(_appDir.path, 'library.json'));
    await file.writeAsString(jsonEncode(_songs.map((s) => s.toJson()).toList()));
  }

  /// タグ読み取り。パッケージの API 変更に巻き込まれないよう dynamic 越しに触り、
  /// 失敗したらファイル名から組み立てた Song に落とす。
  Future<Song> _read(File file) async {
    DateTime? addedAt;
    try {
      addedAt = file.statSync().modified;
    } catch (_) {}

    try {
      final dynamic md = readMetadata(file, getImage: true);

      String? str(dynamic v) {
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      Duration? duration;
      try {
        final d = md.duration;
        if (d is Duration) duration = d;
      } catch (_) {}

      int? track;
      try {
        final t = md.trackNumber;
        if (t is int) track = t;
      } catch (_) {}

      // 埋め込み歌詞はここで拾っておく。曲を開いたときに読み直さずに済む。
      try {
        final l = str(md.lyrics);
        if (l != null) _lyricsCache[file.path] = Lyrics.parse(l);
      } catch (_) {}

      return Song(
        path: file.path,
        title: str(md.title) ?? p.basenameWithoutExtension(file.path),
        artist: str(md.artist) ?? Song.unknownArtist,
        album: str(md.album) ?? p.basename(p.dirname(file.path)),
        duration: duration,
        trackNumber: track,
        artPath: await _extractArt(file, md),
        addedAt: addedAt,
      );
    } catch (_) {
      return Song.fromPath(file.path, addedAt: addedAt);
    }
  }

  /// 埋め込みアートワークをファイルに切り出す。曲ごとに毎回デコードしないで済む。
  Future<String?> _extractArt(File file, dynamic md) async {
    try {
      final pictures = md.pictures;
      if (pictures is! List || pictures.isEmpty) return null;

      final dynamic first = pictures.first;
      final dynamic bytes = first.bytes;
      if (bytes is! List<int> || bytes.isEmpty) return null;

      final name = '${md5.convert(utf8.encode(file.path))}.img';
      final out = File(p.join(_artDir.path, name));
      if (!out.existsSync()) await out.writeAsBytes(bytes);
      return out.path;
    } catch (_) {
      return null;
    }
  }

  // ---- まとめ ----

  List<Album> albums() {
    final map = <String, List<Song>>{};
    for (final s in _songs) {
      map.putIfAbsent('${s.album} ${s.artist}', () => []).add(s);
    }
    final result = [
      for (final entry in map.entries)
        Album(
          entry.value.first.album,
          entry.value.first.artist,
          sortSongs(entry.value, SongSort.album),
        ),
    ];
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  List<Artist> artists() {
    final map = <String, List<Song>>{};
    for (final s in _songs) {
      map.putIfAbsent(s.artist, () => []).add(s);
    }
    final result = [
      for (final entry in map.entries)
        Artist(entry.key, sortSongs(entry.value, SongSort.album)),
    ];
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  /// そのフォルダの直下にある曲。
  List<Song> songsInFolder(String folder) {
    final list = _songs.where((s) => s.folder == folder).toList();
    return sortSongs(list, SongSort.title);
  }

  /// そのフォルダ以下すべての曲。フォルダごと再生するときに使う。
  List<Song> songsUnderFolder(String folder) {
    final prefix = folder.endsWith(p.separator) ? folder : '$folder${p.separator}';
    final list =
        _songs.where((s) => s.path.startsWith(prefix)).toList();
    return sortSongs(list, SongSort.album);
  }

  List<Song> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _songs.where((s) {
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q);
    }).toList();
  }

  // ---- 歌詞 ----

  /// 曲の歌詞を返す。曲と同じ名前の `.lrc` が隣にあればそちらを優先し、
  /// 無ければタグに埋め込まれたものを使う。
  Future<Lyrics> lyricsFor(Song song) async {
    final sidecar = await _readSidecar(song.path);
    if (sidecar != null && !sidecar.isEmpty) {
      _lyricsCache[song.path] = sidecar;
      return sidecar;
    }

    final cached = _lyricsCache[song.path];
    if (cached != null) return cached;

    // スキャン時に拾えていない場合(索引が古いときなど)は、その場で読む。
    try {
      final dynamic md = readMetadata(File(song.path), getImage: false);
      final text = md.lyrics;
      final lyrics = text is String ? Lyrics.parse(text) : Lyrics.empty;
      _lyricsCache[song.path] = lyrics;
      return lyrics;
    } catch (_) {
      _lyricsCache[song.path] = Lyrics.empty;
      return Lyrics.empty;
    }
  }

  Future<Lyrics?> _readSidecar(String songPath) async {
    final base = p.withoutExtension(songPath);
    for (final ext in ['.lrc', '.LRC', '.txt']) {
      final file = File('$base$ext');
      try {
        if (file.existsSync()) return Lyrics.parse(await file.readAsString());
      } catch (_) {
        // 文字コードが読めないなどはあきらめて次へ
      }
    }
    return null;
  }

  /// 歌詞を `.lrc` として曲の隣に保存する。書けなければ false。
  Future<bool> saveSidecar(Song song, String text) async {
    try {
      await File('${p.withoutExtension(song.path)}.lrc').writeAsString(text);
      _lyricsCache[song.path] = Lyrics.parse(text);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
