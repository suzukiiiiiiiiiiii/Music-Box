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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(
              player.sleepAt == null
                  ? Icons.bedtime_outlined
                  : Icons.bedtime_rounded,
              color: player.sleepAt == null ? null : scheme.primary,
            ),
            tooltip: 'スリープタイマー',
            onPressed: () => _showSleepTimer(context),
          ),
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
                          ?.copyWith(
                              fontWeight: FontWeight.w700, letterSpacing: -0.5),
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
                    if (player.sleepRemaining != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'あと ${formatRemaining(player.sleepRemaining!)} で停止します',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.primary),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const _ProgressBar(),
                    const SizedBox(height: 8),
                    const _Controls(),
                    const SizedBox(height: 8),
                    const _SpeedRow(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSleepTimer(BuildContext context) {
    final player = context.read<PlayerModel>();
    const options = [15, 30, 45, 60, 90];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('スリープタイマー'),
              subtitle: Text('指定した時間が経つと再生を止めます'),
            ),
            const Divider(height: 1),
            if (player.sleepAt != null)
              ListTile(
                leading: const Icon(Icons.alarm_off_rounded),
                title: const Text('タイマーを解除'),
                onTap: () {
                  player.setSleepTimer(null);
                  Navigator.of(sheetContext).pop();
                },
              ),
            ...options.map(
              (m) => ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: Text('$m 分後'),
                onTap: () {
                  player.setSleepTimer(Duration(minutes: m));
                  Navigator.of(sheetContext).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scrollController) =>
            _QueueSheet(scrollController: scrollController),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerModel>();
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final total = player.duration ?? Duration.zero;
        final pos = snapshot.data ?? Duration.zero;
        final clamped = pos > total ? total : pos;
        return Column(
          children: [
            Slider(
              value: clamped.inMilliseconds.toDouble(),
              max: total.inMilliseconds.toDouble().clamp(1, double.infinity),
              onChanged: (v) => player.seek(Duration(milliseconds: v.round())),
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
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerModel>();
    final settings = context.watch<SettingsModel>();
    final scheme = Theme.of(context).colorScheme;

    return Row(
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
    );
  }
}

class _SpeedRow extends StatelessWidget {
  const _SpeedRow();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerModel>();
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

/// 再生キュー。並べ替えとその場での削除ができる。
class _QueueSheet extends StatelessWidget {
  final ScrollController scrollController;
  const _QueueSheet({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerModel>();
    final queue = player.queue;
    final ids = player.queueIds;
    final currentIndex = player.player.currentIndex;

    if (queue.isEmpty) {
      return const EmptyState(
        icon: Icons.queue_music_rounded,
        title: 'キューが空です',
        body: '曲を選ぶとここに並びます。',
      );
    }

    return ReorderableListView.builder(
      scrollController: scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: queue.length,
      onReorderItem: player.moveInQueue,
      itemBuilder: (context, i) {
        final song = queue[i];
        return Dismissible(
          key: ValueKey(ids[i]),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.remove_circle_outline_rounded),
          ),
          onDismissed: (_) => player.removeFromQueue(i),
          child: SongTile(
            song: song,
            active: currentIndex == i,
            onTap: () => player.player.seek(Duration.zero, index: i),
            trailing: ReorderableDragStartListener(
              index: i,
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.drag_handle_rounded),
              ),
            ),
          ),
        );
      },
    );
  }
}
