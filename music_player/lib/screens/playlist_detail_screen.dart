import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_controller.dart';
import '../services/player_controller.dart';
import '../services/playlist_controller.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';

/// プレイリスト（またはお気に入り）の中身。
class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({super.key, this.index, this.favorites = false});

  final int? index;
  final bool favorites;

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistController>();
    final library = context.watch<LibraryController>();
    final player = context.read<PlayerController>();
    final scheme = Theme.of(context).colorScheme;

    final name = favorites ? 'お気に入り' : playlists.playlists[index!].name;
    final ids = favorites
        ? playlists.favorites.toList()
        : playlists.playlists[index!].songIds;
    final songs = library.resolve(ids);

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          if (songs.isNotEmpty)
            IconButton(
              tooltip: 'シャッフル再生',
              icon: const Icon(Icons.shuffle_rounded),
              onPressed: () async {
                await player.playAll(songs);
                if (!player.shuffleEnabled) await player.toggleShuffle();
              },
            ),
        ],
      ),
      floatingActionButton: songs.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await player.playAll(songs);
                if (player.shuffleEnabled) await player.toggleShuffle();
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('再生'),
            ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: songs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          favorites
                              ? '曲を長押しして、お気に入りに追加してみてください。'
                              : 'まだ曲がありません。曲を長押しして、このプレイリストに追加してください。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            height: 1.6,
                          ),
                        ),
                      ),
                    )
                  : favorites
                      ? ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: songs.length,
                          itemBuilder: (_, i) => SongTile(
                            song: songs[i],
                            onTap: () => player.playAll(songs, startIndex: i),
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: songs.length,
                          onReorder: (oldIndex, newIndex) =>
                              playlists.reorder(index!, oldIndex, newIndex),
                          itemBuilder: (_, i) => Dismissible(
                            key: ValueKey(songs[i].id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              color: scheme.errorContainer,
                              child: Icon(
                                Icons.remove_circle_outline_rounded,
                                color: scheme.onErrorContainer,
                              ),
                            ),
                            onDismissed: (_) =>
                                playlists.removeSongAt(index!, i),
                            child: SongTile(
                              song: songs[i],
                              onTap: () => player.playAll(songs, startIndex: i),
                              trailing: ReorderableDragStartListener(
                                index: i,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle_rounded),
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }
}
