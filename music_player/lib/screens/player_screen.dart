import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../services/player_controller.dart';
import '../services/playlist_controller.dart';
import '../utils.dart';
import '../widgets/artwork.dart';
import '../widgets/song_tile.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final playlists = context.watch<PlaylistController>();
    final scheme = Theme.of(context).colorScheme;
    final song = player.currentSong;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('再生中の曲はありません。')),
      );
    }

    final isFav = playlists.isFavorite(song.id);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ジャケットをぼかした背景。曲が変わるとここも入れ替わる。
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 48, sigmaY: 48),
            child: Opacity(
              opacity: 0.55,
              child: Artwork(id: song.id, size: 800, radius: 0),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface.withOpacity(0.55),
                  scheme.surface.withOpacity(0.92),
                  scheme.surface,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '閉じる',
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Text(
                      '再生中',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'キューを見る',
                      icon: const Icon(Icons.queue_music_rounded),
                      onPressed: () => _showQueue(context),
                    ),
                  ],
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: LayoutBuilder(
                    builder: (_, c) => Hero(
                      tag: 'artwork',
                      child: Artwork(id: song.id, size: c.maxWidth, radius: 24),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${prettyArtist(song.artist)} · ${prettyAlbum(song.album)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: isFav ? 'お気に入りから外す' : 'お気に入りに追加',
                        onPressed: () => playlists.toggleFavorite(song.id),
                        icon: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFav ? scheme.primary : null,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _Seekbar(player: player),
                const SizedBox(height: 4),
                _Controls(player: player),
                const SizedBox(height: 4),
                _ExtraControls(player: player),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQueue(BuildContext context) {
    final player = context.read<PlayerController>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (sheetContext, scrollController) => AnimatedBuilder(
          animation: player,
          builder: (_, __) {
            final queue = player.queue;
            final currentIndex = player.player.currentIndex;
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '再生キュー',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: queue.length,
                    itemBuilder: (_, i) => SongTile(
                      song: queue[i],
                      onTap: () => player.skipTo(i),
                      trailing: i == currentIndex
                          ? const Icon(Icons.graphic_eq_rounded, size: 20)
                          : IconButton(
                              tooltip: 'キューから外す',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => player.removeFromQueue(i),
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Seekbar extends StatefulWidget {
  const _Seekbar({required this.player});
  final PlayerController player;

  @override
  State<_Seekbar> createState() => _SeekbarState();
}

class _SeekbarState extends State<_Seekbar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<PositionData>(
      stream: widget.player.positionDataStream,
      builder: (context, snapshot) {
        final data = snapshot.data ??
            const PositionData(Duration.zero, Duration.zero, Duration.zero);
        final total = data.duration.inMilliseconds.toDouble();
        final pos = data.position.inMilliseconds
            .toDouble()
            .clamp(0.0, total == 0 ? 1.0 : total);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Slider(
                min: 0,
                max: total == 0 ? 1 : total,
                value: _dragValue ?? pos,
                onChanged: (v) => setState(() => _dragValue = v),
                onChangeEnd: (v) {
                  widget.player.seek(Duration(milliseconds: v.round()));
                  setState(() => _dragValue = null);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatDuration(
                        Duration(milliseconds: (_dragValue ?? pos).round()),
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      formatDuration(data.duration),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.player});
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    IconData repeatIcon() => switch (player.loopMode) {
          LoopMode.one => Icons.repeat_one_rounded,
          _ => Icons.repeat_rounded,
        };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'シャッフル',
          onPressed: player.toggleShuffle,
          icon: Icon(
            Icons.shuffle_rounded,
            color: player.shuffleEnabled ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: '前の曲',
          onPressed: player.previous,
          icon: const Icon(Icons.skip_previous_rounded, size: 40),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            tooltip: player.isPlaying ? '一時停止' : '再生',
            iconSize: 40,
            padding: const EdgeInsets.all(12),
            onPressed: player.togglePlay,
            icon: Icon(
              player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: scheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: '次の曲',
          onPressed: player.next,
          icon: const Icon(Icons.skip_next_rounded, size: 40),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: switch (player.loopMode) {
            LoopMode.off => 'リピートしない',
            LoopMode.all => 'キュー全体をリピート',
            LoopMode.one => '1曲をリピート',
          },
          onPressed: player.cycleRepeat,
          icon: Icon(
            repeatIcon(),
            color: player.loopMode == LoopMode.off
                ? scheme.onSurfaceVariant
                : scheme.primary,
          ),
        ),
      ],
    );
  }
}

class _ExtraControls extends StatelessWidget {
  const _ExtraControls({required this.player});
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sleeping = player.sleepAt != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: () => _showSpeedSheet(context),
          icon: const Icon(Icons.speed_rounded, size: 18),
          label: Text('${player.speed.toStringAsFixed(2)}x'),
          style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
        ),
        TextButton.icon(
          onPressed: () => _showSleepSheet(context),
          icon: Icon(
            sleeping ? Icons.bedtime_rounded : Icons.bedtime_outlined,
            size: 18,
          ),
          label: Text(sleeping ? '停止まで残り少し' : 'スリープ'),
          style: TextButton.styleFrom(
            foregroundColor: sleeping ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  void _showSpeedSheet(BuildContext context) {
    const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in speeds)
              ListTile(
                title: Text('${s.toStringAsFixed(2)}x'),
                trailing: (player.speed - s).abs() < 0.01
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  player.setSpeed(s);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSleepSheet(BuildContext context) {
    const minutes = [10, 20, 30, 45, 60];
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'スリープタイマー',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            for (final m in minutes)
              ListTile(
                title: Text('$m分で止める'),
                onTap: () {
                  player.startSleepTimer(Duration(minutes: m));
                  Navigator.pop(sheetContext);
                },
              ),
            if (player.sleepAt != null)
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: const Text('タイマーを解除する'),
                onTap: () {
                  player.cancelSleepTimer();
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }
}
