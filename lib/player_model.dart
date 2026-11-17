import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'models.dart';

/// just_audio を包んで、キューと再生状態をアプリ側の言葉で扱えるようにする。
class PlayerModel extends ChangeNotifier {
  final AndroidEqualizer equalizer = AndroidEqualizer();
  late final AudioPlayer player;

  List<Song> _queue = [];
  String _queueLabel = '';

  /// キューの各行に振る使い捨ての ID。同じ曲を2回入れても区別が付くので、
  /// 並べ替えできるリストの key に使える(パスだと重複して壊れる)。
  List<int> _queueIds = [];
  int _nextQueueId = 0;

  List<Song> get queue => _queue;
  List<int> get queueIds => _queueIds;
  String get queueLabel => _queueLabel;

  PlayerModel() {
    player = AudioPlayer(
      audioPipeline: AudioPipeline(androidAudioEffects: [equalizer]),
    );
    player.currentIndexStream.listen((_) => notifyListeners());
    player.playerStateStream.listen((_) => notifyListeners());
    player.shuffleModeEnabledStream.listen((_) => notifyListeners());
    player.loopModeStream.listen((_) => notifyListeners());
  }

  Song? get current {
    final i = player.currentIndex;
    if (i == null || i < 0 || i >= _queue.length) return null;
    return _queue[i];
  }

  bool get isPlaying => player.playing;
  bool get shuffleEnabled => player.shuffleModeEnabled;
  LoopMode get loopMode => player.loopMode;

  Stream<Duration> get positionStream => player.positionStream;
  Duration get position => player.position;
  Duration? get duration => player.duration;

  AudioSource _sourceFor(Song s) => AudioSource.file(
        s.path,
        tag: MediaItem(
          id: s.path,
          title: s.title,
          artist: s.artist,
          album: s.album,
          duration: s.duration,
          artUri: s.artPath == null ? null : Uri.file(s.artPath!),
        ),
      );

  /// 曲の並びを丸ごと差し替えて index 番から再生する。
  Future<void> playQueue(List<Song> songs, int index, {String label = ''}) async {
    if (songs.isEmpty) return;
    _queue = [...songs];
    _queueIds = [for (var i = 0; i < _queue.length; i++) _nextQueueId++];
    _queueLabel = label;
    notifyListeners();

    await player.setAudioSources(
      _queue.map(_sourceFor).toList(),
      initialIndex: index.clamp(0, _queue.length - 1),
      initialPosition: Duration.zero,
    );
    await player.play();
  }

  /// 今の曲の次に割り込ませる。何も鳴っていなければそのまま再生を始める。
  Future<void> playNext(Song song, {String label = ''}) async {
    if (_queue.isEmpty) return playQueue([song], 0, label: label);
    final at = (player.currentIndex ?? -1) + 1;
    _queue.insert(at, song);
    _queueIds.insert(at, _nextQueueId++);
    notifyListeners();
    await player.insertAudioSource(at, _sourceFor(song));
  }

  /// キューの最後に足す。
  Future<void> addToQueue(Song song, {String label = ''}) async {
    if (_queue.isEmpty) return playQueue([song], 0, label: label);
    _queue.add(song);
    _queueIds.add(_nextQueueId++);
    notifyListeners();
    await player.addAudioSource(_sourceFor(song));
  }

  /// キューから 1 曲外す。再生中の曲を外すと just_audio が次の曲へ送る。
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    _queueIds.removeAt(index);
    notifyListeners();
    await player.removeAudioSourceAt(index);
  }

  /// キューの並べ替え。[newIndex] は動かした曲を抜いたあとの位置
  /// (ReorderableListView の onReorderItem がくれる値) を想定している。
  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex >= _queue.length) return;
    // just_audio の moveAudioSource も insert(newIndex, removeAt(oldIndex))
    // なので、同じ数え方で揃えておけばずれない。
    _queue.insert(newIndex, _queue.removeAt(oldIndex));
    _queueIds.insert(newIndex, _queueIds.removeAt(oldIndex));
    notifyListeners();
    await player.moveAudioSource(oldIndex, newIndex);
  }

  Future<void> togglePlay() async {
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> next() => player.seekToNext();
  Future<void> previous() async {
    // 3秒より後なら頭出し、それより前なら本当に前の曲へ。
    if (player.position > const Duration(seconds: 3)) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> seek(Duration to) => player.seek(to);

  Future<void> toggleShuffle() async {
    final next = !player.shuffleModeEnabled;
    if (next) await player.shuffle();
    await player.setShuffleModeEnabled(next);
  }

  Future<void> cycleLoopMode() async {
    const order = [LoopMode.off, LoopMode.all, LoopMode.one];
    final i = order.indexOf(player.loopMode);
    await player.setLoopMode(order[(i + 1) % order.length]);
  }

  Future<void> setSpeed(double v) async {
    await player.setSpeed(v);
    // 速度は playerStateStream に乗ってこないので、ここで自分で知らせる。
    notifyListeners();
  }

  // --- スリープタイマー ---

  Timer? _sleepTimer;
  DateTime? _sleepAt;

  /// 眠りに落ちる時刻。設定されていなければ null。
  DateTime? get sleepAt => _sleepAt;

  Duration? get sleepRemaining {
    final at = _sleepAt;
    if (at == null) return null;
    final left = at.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// [d] が null ならタイマーを解除する。
  void setSleepTimer(Duration? d) {
    _sleepTimer?.cancel();
    if (d == null) {
      _sleepTimer = null;
      _sleepAt = null;
      notifyListeners();
      return;
    }
    _sleepAt = DateTime.now().add(d);
    _sleepTimer = Timer(d, () async {
      await player.pause();
      _sleepTimer = null;
      _sleepAt = null;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    player.dispose();
    super.dispose();
  }
}

/// イコライザーの状態。バンドは再生が始まって初めて取れるので、遅延して読む。
class EqualizerController extends ChangeNotifier {
  final AndroidEqualizer equalizer;
  AndroidEqualizerParameters? _params;
  bool _enabled = false;
  String? _error;

  EqualizerController(this.equalizer);

  AndroidEqualizerParameters? get params => _params;
  bool get enabled => _enabled;
  String? get error => _error;

  /// [equalizer.parameters] は再生エンジンが起動するまで完了しない Future なので、
  /// そのまま await すると永久に待ち続ける。待ち時間を区切って諦める。
  Future<void> init() async {
    try {
      _params = await equalizer.parameters.timeout(const Duration(seconds: 3));
      _enabled = equalizer.enabled;
      _error = null;
    } catch (_) {
      _params = null;
      _error = '曲を1曲再生してから開くと調整できます。';
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool v) async {
    await equalizer.setEnabled(v);
    _enabled = v;
    notifyListeners();
  }

  Future<void> setGain(int bandIndex, double gain) async {
    final bands = _params?.bands;
    if (bands == null || bandIndex >= bands.length) return;
    await bands[bandIndex].setGain(gain);
    notifyListeners();
  }

  /// よく使う形を1タップで作れるようにしておく。
  static const presets = <String, List<double>>{
    'フラット': [0, 0, 0, 0, 0],
    '低音強め': [6, 3, 0, 0, 2],
    'ボーカル': [-2, 0, 4, 3, 0],
    '高音強め': [0, 0, 1, 4, 6],
    'ラジオ風': [-4, 2, 5, 2, -3],
  };

  Future<void> applyPreset(String name) async {
    final values = presets[name];
    final bands = _params?.bands;
    if (values == null || bands == null) return;
    for (var i = 0; i < bands.length; i++) {
      // バンド数が5と違う機種でも崩れないよう、比率で対応付ける
      final v = values[(i * values.length ~/ bands.length).clamp(0, values.length - 1)];
      final clamped = v.clamp(_params!.minDecibels, _params!.maxDecibels).toDouble();
      await bands[i].setGain(clamped);
    }
    notifyListeners();
  }
}
