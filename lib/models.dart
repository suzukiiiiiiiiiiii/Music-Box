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

  const Song({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    this.duration,
    this.artPath,
  });

  /// タグが読めなかったときの保険。ファイル名とフォルダ名から組み立てる。
  factory Song.fromPath(String path) {
    final name = p.basenameWithoutExtension(path);
    final folder = p.basename(p.dirname(path));
    return Song(
      path: path,
      title: name,
      artist: '不明なアーティスト',
      album: folder,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'title': title,
        'artist': artist,
        'album': album,
        'ms': duration?.inMilliseconds,
        'art': artPath,
      };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        path: j['path'] as String,
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? '不明なアーティスト',
        album: j['album'] as String? ?? '不明なアルバム',
        duration:
            j['ms'] == null ? null : Duration(milliseconds: j['ms'] as int),
        artPath: j['art'] as String?,
      );
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
