import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/playlist_service.dart';
import '../utils.dart';
import '../widgets/song_actions.dart';
import '../widgets/song_tile.dart';

/// プレイリスト1つの中身。並べ替えと削除ができる。
///
/// お気に入りは並べ替えの対象にしないので、[index] を null にして開く。
class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({super.key, required this.index});

  const PlaylistDetailScreen.favorites({super.key}) : index = null;

  final int? index;

  bool get _isFavorites => index == null;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PlaylistService>();
    final library = context.watch<LibraryService>();
    final player = context.read<PlayerService>();

    final name = _isFavorites ? 'お気に入り' : service.playlists[index!].name;
    final songs = _isFavorites
        ? library.resolve(service.favorites)
        : library.resolve(service.playlists[index!].paths);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name),
            Text(
              describeSongs(songs.length, totalDuration(songs)),
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () =>
                showCollectionActions(context, title: name, songs: songs),
          ),
        ],
      ),
      body: songs.isEmpty
          ? const EmptyHint(
              icon: Icons.playlist_add,
              text: '曲を長押しして「プレイリストに追加」から入れられます',
            )
          : _isFavorites
              ? ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, i) => SongTile(
                    song: songs[i],
                    onTap: () => player.playAll(songs, startIndex: i),
                  ),
                )
              : ReorderableListView.builder(
                  itemCount: songs.length,
                  onReorder: (oldIndex, newIndex) =>
                      service.reorder(index!, oldIndex, newIndex),
                  itemBuilder: (context, i) => Dismissible(
                    key: ValueKey(songs[i].path),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Theme.of(context).colorScheme.errorContainer,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete_outline),
                    ),
                    onDismissed: (_) => service.removeAt(index!, i),
                    child: SongTile(
                      song: songs[i],
                      onTap: () => player.playAll(songs, startIndex: i),
                      trailing: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle),
                      ),
                    ),
                  ),
                ),
    );
  }
}
