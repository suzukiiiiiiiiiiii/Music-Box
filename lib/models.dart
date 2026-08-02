import 'package:path/path.dart' as p;

/// 1曲ぶんの情報。path がそのまま ID を兼ねる。
class Song {
  final String path;
  final String title;
  final String artist;
  final String album;
  final Duration? duration;

  /// 埋め込みアートワークを切り出してキャッシュした画像のパス。無ければ null。
  final String? artPath;

  /// ファイルの更新日時。「新しい順」の並べ替えに使う。
  final DateTime? addedAt;

  const Song({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    this.duration,
    this.artPath,
    this.addedAt,
  });

  /// タグが読めなかったときの保険。ファイル名とフォルダ名から組み立てる。
  factory Song.fromPath(String path, {DateTime? addedAt}) {
    final name = p.basenameWithoutExtension(path);
    final folder = p.basename(p.dirname(path));
    return Song(
      path: path,
      title: name,
      artist: unknownArtist,
      album: folder,
      addedAt: addedAt,
    );
  }

  static const unknownArtist = '不明なアーティスト';
  static const unknownAlbum = '不明なアルバム';

  Map<String, dynamic> toJson() => {
        'path': path,
        'title': title,
        'artist': artist,
        'album': album,
        'ms': duration?.inMilliseconds,
        'art': artPath,
        'added': addedAt?.millisecondsSinceEpoch,
      };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        path: j['path'] as String,
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? unknownArtist,
        album: j['album'] as String? ?? unknownAlbum,
        duration:
            j['ms'] == null ? null : Duration(milliseconds: j['ms'] as int),
        artPath: j['art'] as String?,
        addedAt: j['added'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(j['added'] as int),
      );
}

/// 曲一覧の並び順。設定に保存して次回起動でも保つ。
enum SongSort {
  title('曲名'),
  artist('アーティスト'),
  album('アルバム'),
  newest('新しい順');

  const SongSort(this.label);
  final String label;
}

/// ジャケットの角の落とし方。テーマ工房で選ぶ。
enum ArtworkShape {
  rounded('角丸'),
  circle('丸'),
  square('四角');

  const ArtworkShape(this.label);
  final String label;
}

/// ユーザーが作るプレイリスト。曲はパスの並びで持つ。
class PlaylistData {
  final String name;
  final List<String> paths;

  const PlaylistData({required this.name, required this.paths});

  Map<String, dynamic> toJson() => {'name': name, 'paths': paths};

  factory PlaylistData.fromJson(Map<String, dynamic> j) => PlaylistData(
        name: j['name'] as String,
        paths: (j['paths'] as List).cast<String>(),
      );
}

String formatDuration(Duration? d) {
  if (d == null) return '--:--';
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// スリープタイマーの残り時間など、ざっくり出したいところ用。
String formatRemaining(Duration d) {
  if (d.inHours > 0) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours}時間$m分';
  }
  if (d.inMinutes > 0) return '${d.inMinutes}分';
  return '${d.inSeconds}秒';
}
