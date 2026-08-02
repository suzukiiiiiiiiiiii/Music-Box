import 'package:path/path.dart' as p;

/// 1曲ぶんの情報。ファイルのパスがそのまま ID を兼ねる。
class Song {
  const Song({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    this.duration,
    this.artPath,
    this.trackNumber,
    this.addedAt,
  });

  final String path;
  final String title;
  final String artist;
  final String album;
  final Duration? duration;

  /// 埋め込みアートワークを切り出してキャッシュした画像のパス。無ければ null。
  final String? artPath;
  final int? trackNumber;

  /// ファイルの更新日時。「追加が新しい順」の並べ替えに使う。
  final DateTime? addedAt;

  static const unknownArtist = '不明なアーティスト';
  static const unknownAlbum = '不明なアルバム';

  /// この曲が入っているフォルダ。フォルダ表示のまとめに使う。
  String get folder => p.dirname(path);

  String get fileName => p.basename(path);

  /// タグが読めなかったときの保険。ファイル名とフォルダ名から組み立てる。
  factory Song.fromPath(String path, {DateTime? addedAt}) => Song(
        path: path,
        title: p.basenameWithoutExtension(path),
        artist: unknownArtist,
        album: p.basename(p.dirname(path)),
        addedAt: addedAt,
      );

  Map<String, dynamic> toJson() => {
        'path': path,
        'title': title,
        'artist': artist,
        'album': album,
        'ms': duration?.inMilliseconds,
        'art': artPath,
        'track': trackNumber,
        'added': addedAt?.millisecondsSinceEpoch,
      };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        path: j['path'] as String,
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? unknownArtist,
        album: j['album'] as String? ?? unknownAlbum,
        duration: j['ms'] == null ? null : Duration(milliseconds: j['ms'] as int),
        artPath: j['art'] as String?,
        trackNumber: j['track'] as int?,
        addedAt: j['added'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(j['added'] as int),
      );
}

/// 曲の並べ替え方。
enum SongSort {
  title('曲名'),
  artist('アーティスト'),
  album('アルバム'),
  added('追加が新しい順'),
  duration('長さ');

  const SongSort(this.label);
  final String label;
}

List<Song> sortSongs(List<Song> songs, SongSort sort, {bool descending = false}) {
  final list = [...songs];
  int cmp(Song a, Song b) {
    switch (sort) {
      case SongSort.title:
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case SongSort.artist:
        final byArtist = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
        return byArtist != 0 ? byArtist : a.title.compareTo(b.title);
      case SongSort.album:
        final byAlbum = a.album.toLowerCase().compareTo(b.album.toLowerCase());
        if (byAlbum != 0) return byAlbum;
        // 同じアルバムの中はトラック番号順に見せたい
        final at = a.trackNumber ?? 1 << 20;
        final bt = b.trackNumber ?? 1 << 20;
        return at != bt ? at.compareTo(bt) : a.title.compareTo(b.title);
      case SongSort.added:
        final at = a.addedAt?.millisecondsSinceEpoch ?? 0;
        final bt = b.addedAt?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      case SongSort.duration:
        return (a.duration ?? Duration.zero).compareTo(b.duration ?? Duration.zero);
    }
  }

  list.sort(cmp);
  return descending ? list.reversed.toList() : list;
}
