import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models/lyrics.dart';
import '../models/song.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/playlist_service.dart';
import '../services/settings_service.dart';
import '../utils.dart';
import '../widgets/artwork.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/song_actions.dart';
import 'queues_screen.dart';

/// 再生画面。ジャケットと歌詞を裏返して行き来する。
class PlayingScreen extends StatefulWidget {
  const PlayingScreen({super.key});

  @override
  State<PlayingScreen> createState() => _PlayingScreenState();
}

class _PlayingScreenState extends State<PlayingScreen> {
  bool _showLyrics = false;

  /// 歌詞を読んだ曲のパス。曲が変わったら読み直す。
  String? _loadedFor;
  Lyrics _lyrics = Lyrics.empty;

  /// スライダーを掴んでいる間の値。離すまで再生位置には従わない。
  double? _dragging;

  @override
  void initState() {
    super.initState();
    _showLyrics = context.read<SettingsService>().openOnLyrics;
    _loadLyrics();
  }

  Future<void> _loadLyrics() async {
    final song = context.read<PlayerService>().current;
    if (song == null || song.path == _loadedFor) return;
    _loadedFor = song.path;

    final lyrics = await context.read<LibraryService>().lyricsFor(song);
    if (mounted && _loadedFor == song.path) {
      setState(() => _lyrics = lyrics);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final song = player.current;

    // 曲が変わっていたら歌詞を読み直す
    if (song != null && song.path != _loadedFor) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLyrics());
    }

    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyHint(icon: Icons.music_note, text: '再生中の曲がありません'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              player.activeQueue.name,
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              '${player.currentIndex + 1} / ${player.activeQueue.length}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'キュー',
            icon: const Icon(Icons.queue_music),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const QueuesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => showSongActions(context, song),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _face(context, song)),
            _title(context, song),
            _progress(context, player),
            _controls(context, player),
            _extras(context, player),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 表(ジャケット)と裏(歌詞)。タップで裏返す。
  Widget _face(BuildContext context, Song song) {
    return GestureDetector(
      onTap: () => setState(() => _showLyrics = !_showLyrics),
      behavior: HitTestBehavior.opaque,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: _showLyrics
            ? _LyricsFace(
                key: const ValueKey('lyrics'),
                lyrics: _lyrics,
                player: context.read<PlayerService>(),
              )
            : Padding(
                key: const ValueKey('art'),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = constraints.biggest.shortestSide;
                      return Artwork(song: song, size: side, radius: 16);
                    },
                  ),
                ),
              ),
      ),
    );
  }

  Widget _title(BuildContext context, Song song) {
    final scheme = Theme.of(context).colorScheme;
    final playlists = context.watch<PlaylistService>();
    final favorite = playlists.isFavorite(song.path);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${song.artist} · ${song.album}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              favorite ? Icons.favorite : Icons.favorite_border,
              color: favorite ? scheme.primary : null,
            ),
            onPressed: () => playlists.toggleFavorite(song.path),
          ),
          IconButton(
            tooltip: _showLyrics ? 'ジャケット' : '歌詞',
            icon: Icon(_showLyrics ? Icons.image_outlined : Icons.lyrics_outlined),
            onPressed: () => setState(() => _showLyrics = !_showLyrics),
          ),
        ],
      ),
    );
  }

  Widget _progress(BuildContext context, PlayerService player) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final total = player.duration ?? Duration.zero;
        final position = snapshot.data ?? Duration.zero;
        final maxMs = total.inMilliseconds.toDouble();
        final value = _dragging ??
            position.inMilliseconds.toDouble().clamp(0, maxMs <= 0 ? 1 : maxMs);

        return Column(
          children: [
            Slider(
              value: maxMs <= 0 ? 0 : value.clamp(0, maxMs),
              max: maxMs <= 0 ? 1 : maxMs,
              onChanged: maxMs <= 0
                  ? null
                  : (v) => setState(() => _dragging = v),
              onChangeEnd: (v) {
                player.seek(Duration(milliseconds: v.round()));
                setState(() => _dragging = null);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDuration(
                      Duration(milliseconds: (_dragging ?? value).round()),
                    ),
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                  Text(
                    formatDuration(total),
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _controls(BuildContext context, PlayerService player) {
    final scheme = Theme.of(context).colorScheme;

    IconData repeatIcon() {
      switch (player.loopMode) {
        case LoopMode.off:
          return Icons.repeat;
        case LoopMode.all:
          return Icons.repeat;
        case LoopMode.one:
          return Icons.repeat_one;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              Icons.shuffle,
              color: player.shuffleEnabled ? scheme.primary : null,
            ),
            onPressed: player.toggleShuffle,
          ),
          IconButton(
            iconSize: 34,
            icon: const Icon(Icons.skip_previous),
            onPressed: player.previous,
          ),
          IconButton.filled(
            iconSize: 34,
            icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: player.togglePlay,
          ),
          IconButton(
            iconSize: 34,
            icon: const Icon(Icons.skip_next),
            onPressed: player.next,
          ),
          IconButton(
            icon: Icon(
              repeatIcon(),
              color: player.loopMode == LoopMode.off ? null : scheme.primary,
            ),
            onPressed: player.cycleRepeat,
          ),
        ],
      ),
    );
  }

  Widget _extras(BuildContext context, PlayerService player) {
    final sleepAt = player.sleepAt;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.speed, size: 18),
          label: Text('${player.speed.toStringAsFixed(2)}倍'),
          onPressed: () => _pickSpeed(context, player),
        ),
        TextButton.icon(
          icon: Icon(
            Icons.bedtime_outlined,
            size: 18,
            color: sleepAt == null ? null : Theme.of(context).colorScheme.primary,
          ),
          label: Text(sleepAt == null ? 'タイマー' : '停止まで${_remaining(sleepAt)}'),
          onPressed: () => _pickSleep(context, player),
        ),
      ],
    );
  }

  String _remaining(DateTime at) {
    final left = at.difference(DateTime.now());
    return left.isNegative ? '0分' : '${left.inMinutes + 1}分';
  }

  Future<void> _pickSpeed(BuildContext context, PlayerService player) async {
    const choices = [0.75, 1.0, 1.25, 1.5, 2.0];
    final chosen = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final speed in choices)
              RadioListTile<double>(
                value: speed,
                groupValue: player.speed,
                title: Text('${speed.toStringAsFixed(2)}倍'),
                onChanged: (v) => Navigator.pop(sheetContext, v),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) await player.setSpeed(chosen);
  }

  Future<void> _pickSleep(BuildContext context, PlayerService player) async {
    const minutes = [15, 30, 45, 60, 90];
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (player.sleepAt != null)
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('タイマーを解除'),
                onTap: () => Navigator.pop(sheetContext, 0),
              ),
            for (final m in minutes)
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: Text('$m分後に止める'),
                onTap: () => Navigator.pop(sheetContext, m),
              ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    if (chosen == 0) {
      player.cancelSleepTimer();
    } else {
      player.startSleepTimer(Duration(minutes: chosen));
    }
  }
}

/// 歌詞の面。再生位置が動くたびに作り直す。
class _LyricsFace extends StatelessWidget {
  const _LyricsFace({super.key, required this.lyrics, required this.player});

  final Lyrics lyrics;
  final PlayerService player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) => LyricsView(
        lyrics: lyrics,
        position: snapshot.data ?? Duration.zero,
        onSeek: player.seek,
      ),
    );
  }
}
