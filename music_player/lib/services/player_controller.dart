import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:rxdart/rxdart.dart';

/// スライダー描画用に、位置・バッファ・長さをまとめたもの。
class PositionData {
  const PositionData(this.position, this.buffered, this.duration);
  final Duration position;
  final Duration buffered;
  final Duration duration;
}

class PlayerController extends ChangeNotifier {
  PlayerController() {
    _player.currentIndexStream.listen((_) => notifyListeners());
    _player.playerStateStream.listen((_) => notifyListeners());
    _player.shuffleModeEnabledStream.listen((_) => notifyListeners());
    _player.loopModeStream.listen((_) => notifyListeners());
    _player.speedStream.listen((_) => notifyListeners());
  }

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  List<SongModel> _queue = [];
  List<SongModel> get queue => List.unmodifiable(_queue);

  Timer? _sleepTimer;
  DateTime? _sleepAt;
  DateTime? get sleepAt => _sleepAt;

  bool get isPlaying => _player.playing;
  bool get shuffleEnabled => _player.shuffleModeEnabled;
  LoopMode get loopMode => _player.loopMode;
  double get speed => _player.speed;

  SongModel? get currentSong {
    final i = _player.currentIndex;
    if (i == null || i < 0 || i >= _queue.length) return null;
    return _queue[i];
  }

  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        (p, b, d) => PositionData(p, b, d ?? Duration.zero),
      );

  /// 曲一覧を丸ごとキューに入れて、指定の曲から再生を始める。
  Future<void> playAll(List<SongModel> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    _queue = List.of(songs);

    final source = ConcatenatingAudioSource(
      children: songs.map(_toAudioSource).toList(),
    );

    try {
      await _player.setAudioSource(
        source,
        initialIndex: startIndex.clamp(0, songs.length - 1),
        initialPosition: Duration.zero,
      );
      await _player.play();
    } catch (e) {
      debugPrint('再生の開始に失敗しました: $e');
    }
    notifyListeners();
  }

  /// 今のキューの次の位置に差し込む。
  Future<void> playNext(SongModel song) async {
    final source = _player.audioSource;
    if (source is! ConcatenatingAudioSource || _queue.isEmpty) {
      return playAll([song]);
    }
    final at = (_player.currentIndex ?? -1) + 1;
    await source.insert(at, _toAudioSource(song));
    _queue.insert(at, song);
    notifyListeners();
  }

  Future<void> addToQueue(SongModel song) async {
    final source = _player.audioSource;
    if (source is! ConcatenatingAudioSource || _queue.isEmpty) {
      return playAll([song]);
    }
    await source.add(_toAudioSource(song));
    _queue.add(song);
    notifyListeners();
  }

  Future<void> removeFromQueue(int index) async {
    final source = _player.audioSource;
    if (source is! ConcatenatingAudioSource) return;
    if (index == _player.currentIndex) return; // 再生中の曲は消さない
    await source.removeAt(index);
    _queue.removeAt(index);
    notifyListeners();
  }

  Future<void> skipTo(int index) async {
    await _player.seek(Duration.zero, index: index);
    await _player.play();
  }

  Future<void> togglePlay() =>
      _player.playing ? _player.pause() : _player.play();

  Future<void> next() => _player.hasNext ? _player.seekToNext() : Future.value();

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

  Future<void> setSpeed(double v) async {
    await _player.setSpeed(v);
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

  AudioSource _toAudioSource(SongModel s) {
    return AudioSource.uri(
      Uri.parse(s.uri!),
      tag: MediaItem(
        id: s.id.toString(),
        title: s.title,
        album: s.album ?? '不明なアルバム',
        artist: s.artist == '<unknown>' ? '不明なアーティスト' : (s.artist ?? '不明なアーティスト'),
        duration: Duration(milliseconds: s.duration ?? 0),
        // 通知バーのジャケットはMediaStoreのアルバムアートURIから読む
        artUri: Uri.parse('content://media/external/audio/albumart/${s.albumId}'),
      ),
    );
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}
