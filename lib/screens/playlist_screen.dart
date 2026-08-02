import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../library_model.dart';
import '../player_model.dart';
import '../widgets.dart';

class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key});

  Future<void> _create(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('プレイリストを作る'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例: 作業用、通学中'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('作る'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty && context.mounted) {
      await context.read<LibraryModel>().createPlaylist(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();

    if (library.playlists.isEmpty) {
      return EmptyState(
        icon: Icons.queue_music_rounded,
        title: 'プレイリストがありません',
        body: '気分ごとに曲をまとめておけます。',
        actionLabel: 'プレイリストを作る',
        onAction: () => _create(context),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 90),
      children: [
        ...library.playlists.map((pl) {
          final songs = library.songsOf(pl);
          return ListTile(
            leading: songs.isEmpty
                ? const Icon(Icons.queue_music_rounded, size: 40)
                : Artwork(song: songs.first, size: 46),
            title: Text(pl.name),
            subtitle: Text('${songs.length} 曲'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PlaylistDetailScreen(name: pl.name)),
            ),
          );
        }),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: OutlinedButton.icon(
            onPressed: () => _create(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('プレイリストを作る'),
          ),
        ),
      ],
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
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'このプレイリストを削除',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text('「${playlist.name}」を削除しますか'),
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
              if (ok == true && context.mounted) {
                await context.read<LibraryModel>().deletePlaylist(playlist.name);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: songs.isEmpty
          ? const EmptyState(
              icon: Icons.playlist_add_rounded,
              title: 'まだ曲が入っていません',
              body: '曲の一覧で「…」を押すと、ここに追加できます。',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () => player.playQueue(songs, 0, label: playlist.name),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('再生'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          final shuffled = [...songs]..shuffle();
                          player.playQueue(shuffled, 0, label: playlist.name);
                        },
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('シャッフル'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 90),
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
                          onTap: () => player.playQueue(songs, i, label: playlist.name),
                        ),
                      );
                    },
                  ),
                ),
                const MiniPlayer(),
              ],
            ),
    );
  }
}
