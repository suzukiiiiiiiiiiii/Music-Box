import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../player_model.dart';
import '../settings_model.dart';
import '../widgets.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerModel>();
    final settings = context.watch<SettingsModel>();
    final scheme = Theme.of(context).colorScheme;
    final song = player.current;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.music_off_rounded,
          title: '再生中の曲がありません',
          body: '一覧から曲を選ぶとここに出ます。',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '閉じる',
        ),
        title: Text(
          player.queueLabel.isEmpty ? '再生中' : player.queueLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: '再生キュー',
            onPressed: () => _showQueue(context),
          ),
        ],
      ),
      body: SafeArea(
        // 横向きや小さい画面では操作部だけで画面が埋まる。ジャケットを高さからも
        // 絞ったうえで、それでも入らなければスクロールさせる。
        child: LayoutBuilder(
          builder: (context, box) {
            final artSize = [box.maxWidth - 48, box.maxHeight * 0.45, 360.0]
                .reduce((a, b) => a < b ? a : b)
                .clamp(0.0, 360.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Artwork(song: song, size: artSize, radius: settings.radius + 8),
                    const SizedBox(height: 28),
                    Text(
                      song.title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${song.artist} · ${song.album}',
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    StreamBuilder<Duration>(
                      stream: player.positionStream,
                      builder: (context, snapshot) {
                        final total = player.duration ?? Duration.zero;
                        final pos = (snapshot.data ?? Duration.zero);
                        final clamped = pos > total ? total : pos;
                        return Column(
                          children: [
                            Slider(
                              value: clamped.inMilliseconds.toDouble(),
                              max: total.inMilliseconds.toDouble().clamp(1, double.infinity),
                              onChanged: (v) =>
                                  player.seek(Duration(milliseconds: v.round())),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(formatDuration(clamped),
                                      style: Theme.of(context).textTheme.bodySmall),
                                  Text(formatDuration(total),
                                      style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(Icons.shuffle_rounded,
                              color: player.shuffleEnabled ? scheme.primary : null),
                          tooltip: 'シャッフル',
                          onPressed: player.toggleShuffle,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded),
                          iconSize: 40,
                          tooltip: '前の曲',
                          onPressed: player.previous,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(settings.radius + 6),
                          ),
                          child: IconButton(
                            icon: Icon(
                              player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: scheme.onPrimary,
                            ),
                            iconSize: 40,
                            padding: const EdgeInsets.all(12),
                            tooltip: player.isPlaying ? '一時停止' : '再生',
                            onPressed: player.togglePlay,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded),
                          iconSize: 40,
                          tooltip: '次の曲',
                          onPressed: player.next,
                        ),
                        IconButton(
                          icon: Icon(
                            player.loopMode == LoopMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            color: player.loopMode == LoopMode.off ? null : scheme.primary,
                          ),
                          tooltip: '繰り返し',
                          onPressed: player.cycleLoopMode,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _SpeedRow(player: player),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showQueue(BuildContext context) {
    final player = context.read<PlayerModel>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scrollController) => ListView.builder(
          controller: scrollController,
          itemCount: player.queue.length,
          itemBuilder: (context, i) {
            final song = player.queue[i];
            return SongTile(
              song: song,
              active: player.player.currentIndex == i,
              onTap: () {
                player.player.seek(Duration.zero, index: i);
                Navigator.of(sheetContext).pop();
              },
            );
          },
        ),
      ),
    );
  }
}

class _SpeedRow extends StatelessWidget {
  final PlayerModel player;
  const _SpeedRow({required this.player});

  @override
  Widget build(BuildContext context) {
    const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
    return Wrap(
      spacing: 8,
      alignment: WrapAlignment.center,
      children: speeds.map((s) {
        final selected = (player.player.speed - s).abs() < 0.01;
        return ChoiceChip(
          label: Text('${s}x'),
          selected: selected,
          onSelected: (_) => player.setSpeed(s),
        );
      }).toList(),
    );
  }
}
