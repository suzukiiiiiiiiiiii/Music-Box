import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/play_queue.dart';
import '../models/song.dart';
import 'library_service.dart';

/// 再生と、複数キューの持ち回り。
///
/// キューは [queueCount] 本あって、常にそのうち1本だけが再生エンジンに載っている。
/// 切り替えるときは、いま載っているキューの位置を控えてから差し替えるので、
/// 戻ってきたときに続きから聴ける。
class PlayerService extends ChangeNotifier {
  PlayerService(this._library) {
    _player.playerStateStream.listen((_) => notifyListeners());
    _player.shuffleModeEnabledStream.listen((_) => notifyListeners());
    _player.loopModeStream.listen((_) => notifyListeners());
    _player.speedStream.listen((_) => notifyListeners());
    _player.currentIndexStream.listen((i) {
      if (i != null) _active.index = i;
      notifyListeners();
      _scheduleSave();
    });
  }

  static const queueCount = 5;

  final LibraryService _library;
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  List<PlayQueue> _queues = [
    for (var i = 1; i <= queueCount; i++) PlayQueue(name: 'キュー$i'),
  ];
  int _activeIndex = 0;

  List<PlayQueue> get queues => List.unmodifiable(_queues);
  int get activeIndex => _activeIndex;
  PlayQueue get _active => _queues[_activeIndex];
  PlayQueue get activeQueue => _active;

  Timer? _saveTimer;
  Timer? _sleepTimer;
  DateTime? _sleepAt;
  DateTime? get sleepAt => _sleepAt;

  bool get isPlaying => _player.playing;
  bool get shuffleEnabled => _player.shuffleModeEnabled;
  LoopMode get loopMode => _player.loopMode;
  double get speed => _player.speed;
  Duration? get duration => _player.duration;
  Stream<Duration> get positionStream => _player.positionStream;

  /// 今のキューに並んでいる曲。索引から消えた曲は落とす。
  List<Song> get queueSongs => _library.resolve(_active.paths);

  Song? get current {
    final i = _player.currentIndex;
    final paths = _active.paths;
    if (i == null || i < 0 || i >= paths.length) return null;
    return _library.songAt(paths[i]);
  }

  int get currentIndex => _player.currentIndex ?? _active.index;

  // ---- 保存と復元 ----

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('queues');
    if (raw != null && raw.isNotEmpty) {
      final restored = <PlayQueue>[];
      for (final s in raw) {
        try {
          restored.add(PlayQueue.fromJson(jsonDecode(s) as Map<String, dynamic>));
        } catch (_) {
          // 壊れている分は捨てる
        }
      }
      // 本数が変わっても足りない分は作り足す
      while (restored.length < queueCount) {
        restored.add(PlayQueue(name: 'キュー${restored.length + 1}'));
      }
      _queues = restored.take(queueCount).toList();
    }
    _activeIndex = (prefs.getInt('activeQueue') ?? 0).clamp(0, queueCount - 1);

    // 前回の続きを載せておく。再生は始めない。
    if (_active.paths.isNotEmpty) {
      await _loadActiveIntoPlayer(autoPlay: false);
    }
    notifyListeners();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _save);
  }

  Future<void> _save() async {
    _active.positionMs = _player.position.inMilliseconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'queues',
      _queues.map((q) => jsonEncode(q.toJson())).toList(),
    );
    await prefs.setInt('activeQueue', _activeIndex);
  }

  // ---- キューの切り替え ----

  Future<void> switchQueue(int index) async {
    if (index == _activeIndex || index < 0 || index >= _queues.length) return;

    // いま聴いている位置を控えてから入れ替える
    _active.index = _player.currentIndex ?? _active.index;
    _active.positionMs = _player.position.inMilliseconds;

    _activeIndex = index;
    if (_active.paths.isEmpty) {
      await _player.stop();
      await _player.clearAudioSources();
    } else {
      await _loadActiveIntoPlayer(autoPlay: false);
    }
    notifyListeners();
    await _save();
  }

  Future<void> renameQueue(int index, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _queues[index].name = trimmed;
    notifyListeners();
    await _save();
  }

  Future<void> clearQueue(int index) async {
    _queues[index]
      ..paths = []
      ..index = 0
      ..positionMs = 0;
    if (index == _activeIndex) {
      await _player.stop();
      await _player.clearAudioSources();
    }
    notifyListeners();
    await _save();
  }

  // ---- 再生 ----

  /// 一覧をまるごと今のキューに入れ替えて、指定の曲から流す。
  Future<void> playAll(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    _active
      ..paths = songs.map((s) => s.path).toList()
      ..index = startIndex.clamp(0, songs.length - 1)
      ..positionMs = 0;
    await _loadActiveIntoPlayer(autoPlay: true);
    notifyListeners();
    await _save();
  }

  /// 指定したキューに足す。今のキューでなければ再生は動かさない。
  Future<void> enqueue(List<Song> songs, {int? queueIndex, bool next = false}) async {
    if (songs.isEmpty) return;
    final target = queueIndex ?? _activeIndex;
    final queue = _queues[target];
    final paths = songs.map((s) => s.path).toList();

    if (target != _activeIndex || queue.paths.isEmpty) {
      // 載っていないキューは並びをいじるだけ
      final wasEmpty = queue.paths.isEmpty;
      if (next && !wasEmpty) {
        queue.paths.insertAll((queue.index + 1).clamp(0, queue.paths.length), paths);
      } else {
        queue.paths.addAll(paths);
      }
      if (target == _activeIndex && wasEmpty) {
        await _loadActiveIntoPlayer(autoPlay: true);
      }
      notifyListeners();
      await _save();
      return;
    }

    final at = next
        ? ((_player.currentIndex ?? 0) + 1).clamp(0, queue.paths.length)
        : queue.paths.length;
    queue.paths.insertAll(at, paths);
    await _player.insertAudioSources(at, [for (final s in songs) _sourceOf(s)]);
    notifyListeners();
    await _save();
  }

  Future<void> removeFromQueue(int index) async {
    final queue = _active;
    if (index < 0 || index >= queue.paths.length) return;
    if (index == _player.currentIndex) return; // 再生中の曲は消さない

    queue.paths.removeAt(index);
    await _player.removeAudioSourceAt(index);
    notifyListeners();
    await _save();
  }

  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    final queue = _active;
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    queue.paths.insert(newIndex, queue.paths.removeAt(oldIndex));
    await _player.moveAudioSource(oldIndex, newIndex);
    notifyListeners();
    await _save();
  }

  Future<void> skipTo(int index) async {
    await _player.seek(Duration.zero, index: index);
    await _player.play();
  }

  Future<void> togglePlay() =>
      _player.playing ? _player.pause() : _player.play();

  Future<void> next() async {
    if (_player.hasNext) await _player.seekToNext();
  }

  /// 3秒より後なら曲の頭に戻し、それ以前なら前の曲へ。
  Future<void> previous() async {
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      await _player.seek(Duration.zero);
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> toggleShuffle() async {
    final enable = !_player.shuffleModeEnabled;
    if (enable) await _player.shuffle();
    await _player.setShuffleModeEnabled(enable);
    notifyListeners();
  }

  Future<void> cycleRepeat() async {
    const order = [LoopMode.off, LoopMode.all, LoopMode.one];
    final next = order[(order.indexOf(_player.loopMode) + 1) % order.length];
    await _player.setLoopMode(next);
    notifyListeners();
  }

  Future<void> setSpeed(double value) async {
    await _player.setSpeed(value);
    notifyListeners();
  }

  // ---- スリープタイマー ----

  void startSleepTimer(Duration d) {
    _sleepTimer?.cancel();
    _sleepAt = DateTime.now().add(d);
    _sleepTimer = Timer(d, () async {
      await _player.pause();
      _sleepAt = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepAt = null;
    notifyListeners();
  }

  // ---- 中身 ----

  Future<void> _loadActiveIntoPlayer({required bool autoPlay}) async {
    final songs = _library.resolve(_active.paths);
    if (songs.isEmpty) {
      await _player.stop();
      await _player.clearAudioSources();
      return;
    }

    // 索引から消えた曲があるとキューと並びがずれるので、実在するぶんに揃える
    _active.paths = songs.map((s) => s.path).toList();
    final index = _active.index.clamp(0, songs.length - 1);

    try {
      await _player.setAudioSources(
        [for (final s in songs) _sourceOf(s)],
        initialIndex: index,
        initialPosition: Duration(milliseconds: _active.positionMs),
      );
      if (autoPlay) await _player.play();
    } catch (e) {
      debugPrint('再生の開始に失敗しました: $e');
    }
  }

  AudioSource _sourceOf(Song song) => AudioSource.file(
        song.path,
        tag: MediaItem(
          id: song.path,
          title: song.title,
          album: song.album,
          artist: song.artist,
          duration: song.duration,
          artUri: song.artPath == null ? null : Uri.file(song.artPath!),
        ),
      );

  @override
  void dispose() {
    _saveTimer?.cancel();
    _sleepTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}
