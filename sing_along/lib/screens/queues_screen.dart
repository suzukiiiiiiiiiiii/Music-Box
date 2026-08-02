import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../services/player_service.dart';
import '../utils.dart';
import '../widgets/song_actions.dart';
import '../widgets/song_tile.dart';

/// キューの一覧と中身。
///
/// キューは何本かあって、それぞれが自分の並びと「どこまで聴いたか」を持つ。
/// 上のタブで選んだキューが再生に載る。
class QueuesScreen extends StatefulWidget {
  const QueuesScreen({super.key});

  @override
  State<QueuesScreen> createState() => _QueuesScreenState();
}

class _QueuesScreenState extends State<QueuesScreen> {
  /// 見ているキュー。再生中のキューとは別で、覗くだけなら切り替わらない。
  late int _viewing = context.read<PlayerService>().activeIndex;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final library = context.watch<LibraryService>();

    final queue = player.queues[_viewing];
    final songs = library.resolve(queue.paths);
    final isActive = _viewing == player.activeIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text('キュー'),
        actions: [
          IconButton(
            tooltip: '名前を変える',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final name = await promptForName(
                context,
                title: 'キューの名前',
                initial: queue.name,
              );
              if (name != null) await player.renameQueue(_viewing, name);
            },
          ),
          IconButton(
            tooltip: '空にする',
            icon: const Icon(Icons.playlist_remove),
            onPressed: songs.isEmpty
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text('${queue.name} を空にしますか'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('やめる'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('空にする'),
                          ),
                        ],
                      ),
                    );
                    if (ok ?? false) await player.clearQueue(_viewing);
                  },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (var i = 0; i < player.queues.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      selected: i == _viewing,
                      onSelected: (_) => setState(() => _viewing = i),
                      avatar: i == player.activeIndex
                          ? const Icon(Icons.play_arrow, size: 16)
                          : null,
                      label: Text(
                        '${player.queues[i].name} (${player.queues[i].length})',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: songs.isEmpty
          ? const EmptyHint(
              icon: Icons.queue_music,
              text: 'このキューは空です\n曲を長押しして「別のキューに追加」から入れられます',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        describeSongs(songs.length, totalDuration(songs)),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      if (!isActive)
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            await player.switchQueue(_viewing);
                            if (context.mounted) {
                              notify(context, '${queue.name} に切り替えました');
                            }
                          },
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('このキューに切り替え'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: isActive
                      ? ReorderableListView.builder(
                          itemCount: songs.length,
                          onReorder: player.moveInQueue,
                          itemBuilder: (context, i) => SongTile(
                            key: ValueKey('${songs[i].path}#$i'),
                            song: songs[i],
                            dense: true,
                            onTap: () => player.skipTo(i),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => player.removeFromQueue(i),
                                ),
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Icon(Icons.drag_handle),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: songs.length,
                          itemBuilder: (context, i) => SongTile(
                            song: songs[i],
                            dense: true,
                            onTap: () async {
                              // 覗いているキューの曲を触ったら、そのキューに移る
                              player.queues[_viewing].index = i;
                              player.queues[_viewing].positionMs = 0;
                              await player.switchQueue(_viewing);
                              await player.skipTo(i);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
