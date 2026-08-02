/// アプリ内プレイリスト。曲のパスの並びだけを持つ。
class Playlist {
  Playlist({required this.name, List<String>? paths}) : paths = paths ?? [];

  String name;
  List<String> paths;

  int get length => paths.length;

  Map<String, dynamic> toJson() => {'name': name, 'paths': paths};

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        name: j['name'] as String? ?? '',
        paths: (j['paths'] as List? ?? []).map((e) => e as String).toList(),
      );
}
