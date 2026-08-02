import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_controller.dart';
import '../services/player_controller.dart';
import '../widgets/song_tile.dart';

class SongsTab extends StatelessWidget {
  const SongsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final player = context.read<PlayerController>();
    final songs = library.songs;

    return RefreshIndicator(
      onRefresh: library.load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: songs.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      await player.playAll(songs);
                      if (player.shuffleEnabled) await player.toggleShuffle();
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('すべて再生'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (songs.isEmpty) return;
                      await player.playAll(songs);
                      if (!player.shuffleEnabled) await player.toggleShuffle();
                    },
                    icon: const Icon(Icons.shuffle_rounded),
                    label: const Text('シャッフル'),
                  ),
                  const Spacer(),
                  Text(
                    '${songs.length}曲',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            );
          }

          final i = index - 1;
          return SongTile(
            song: songs[i],
            onTap: () => player.playAll(songs, startIndex: i),
          );
        },
      ),
    );
  }
}
