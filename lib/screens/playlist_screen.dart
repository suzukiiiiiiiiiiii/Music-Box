import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../library_model.dart';
import '../player_model.dart';
import '../widgets.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('プレイリスト'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'プレイリストを作る',
            onPressed: () => promptPlaylistName(context),
          ),
        ],
      ),
      body: library.playlists.isEmpty
          ? EmptyState(
              icon: Icons.queue_music_rounded,
              title: 'プレイリストがありません',
              body: '気分ごとに曲をまとめておけます。\n作ったあと、曲の「…」から追加できます。',
              actionLabel: 'プレイリストを作る',
              onAction: () => promptPlaylistName(context),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
              itemCount: library.playlists.length,
              itemBuilder: (context, i) {
                final pl = library.playlists[i];
                final songs = library.songsOf(pl);
                return ListTile(
                  leading: songs.isEmpty
                      ? const SizedBox(
                          width: 46,
                          height: 46,
                          child: Icon(Icons.queue_music_rounded, size: 30),
                        )
                      : Artwork(song: songs.first, size: 46),
                  title: Text(pl.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${songs.length} 曲'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailScreen(name: pl.name),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class PlaylistDetailScreen extends StatelessWidget {
  final String name;
  const PlaylistDetailScreen({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();
    final player = context.watch<PlayerModel>();
    final matches = library.playlists.where((pl) => pl.name == name).toList();
    final playlist = matches.isEmpty ? null : matches.first;

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(title: Text(name)),
        body: const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'このプレイリストは削除されました',
          body: '前の画面に戻ってください。',
        ),
      );
    }

    final songs = library.songsOf(playlist);

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'このプレイリストを削除',
            onPressed: () => _confirmDelete(context, playlist.name),
          ),
        ],
      ),
      body: songs.isEmpty
          ? const EmptyState(
              icon: Icons.playlist_add_rounded,
              title: 'まだ曲が入っていません',
              body: 'ライブラリで曲の「…」を押して、\n「プレイリストに追加」から入れられます。',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${songs.length} 曲',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      FilledButton.icon(
                        onPressed: () =>
                            player.playQueue(songs, 0, label: playlist.name),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('再生'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => player.playQueue(
                            [...songs]..shuffle(), 0,
                            label: playlist.name),
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('シャッフル'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    itemCount: songs.length,
                    onReorderItem: (oldIndex, newIndex) =>
                        context.read<LibraryModel>().reorderPlaylist(
                              playlist.name,
                              oldIndex,
                              newIndex,
                              songs.map((s) => s.path).toList(),
                            ),
                    itemBuilder: (context, i) {
                      final song = songs[i];
                      return Dismissible(
                        key: ValueKey(song.path),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        onDismissed: (_) => context
                            .read<LibraryModel>()
                            .removeFromPlaylist(playlist.name, song.path),
                        child: SongTile(
                          song: song,
                          active: player.current?.path == song.path,
                          onTap: () =>
                              player.playQueue(songs, i, label: playlist.name),
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
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String playlistName) async {
    final library = context.read<LibraryModel>();
    final navigator = Navigator.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('「$playlistName」を削除しますか'),
        content: const Text('曲そのものは端末に残ります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await library.deletePlaylist(playlistName);
    navigator.pop();
  }
}
