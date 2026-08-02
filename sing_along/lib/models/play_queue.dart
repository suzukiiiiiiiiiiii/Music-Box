/// 独立した再生キュー。
///
/// Musicolet と同じで、キューを複数持てるのがこのアプリの中心。
/// 「通勤用」と「作業用」を別々に組んでおいて、途中まで聴いた位置を
/// それぞれ覚えたまま行き来できる。
class PlayQueue {
  PlayQueue({
    required this.name,
    List<String>? paths,
    this.index = 0,
    this.positionMs = 0,
  }) : paths = paths ?? [];

  String name;

  /// 曲のパス。曲そのものではなくパスで持つので、
  /// 再スキャンで曲が入れ替わっても並びは壊れない。
  List<String> paths;

  /// このキューで今いる位置。
  int index;

  /// その曲のどこまで聴いたか。キューを切り替えても頭に戻らないように覚えておく。
  int positionMs;

  bool get isEmpty => paths.isEmpty;
  int get length => paths.length;

  Map<String, dynamic> toJson() => {
        'name': name,
        'paths': paths,
        'index': index,
        'pos': positionMs,
      };

  factory PlayQueue.fromJson(Map<String, dynamic> j) => PlayQueue(
        name: j['name'] as String? ?? 'キュー',
        paths: (j['paths'] as List? ?? []).map((e) => e as String).toList(),
        index: j['index'] as int? ?? 0,
        positionMs: j['pos'] as int? ?? 0,
      );
}
