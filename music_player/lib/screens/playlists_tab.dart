import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_controller.dart';
import '../services/playlist_controller.dart';
import '../widgets/song_tile.dart';
import 'playlist_detail_screen.dart';

class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistController>();
    final library = context.watch<LibraryController>();
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            child: Icon(Icons.favorite_rounded, color: scheme.onPrimaryContainer),
          ),
          title: const Text('お気に入り'),
          subtitle: Text('${playlists.favorites.length}曲'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PlaylistDetailScreen(favorites: true),
            ),
          ),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: scheme.surfaceContainerHighest,
            child: const Icon(Icons.add_rounded),
          ),
          title: const Text('新しいプレイリストを作る'),
          onTap: () async {
            final name = await promptPlaylistName(context);
            if (name != null) await playlists.create(name);
          },
        ),
        if (playlists.playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
            child: Text(
              'まだプレイリストがありません。曲を長押しすると、ここに追加できます。',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.6),
            ),
          ),
        ...List.generate(playlists.playlists.length, (i) {
          final p = playlists.playlists[i];
          final count = library.resolve(p.songIds).length;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.surfaceContainerHighest,
              child: const Icon(Icons.queue_music_rounded),
            ),
            title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('$count曲'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'rename') {
                  final name = await promptPlaylistName(
                    context,
                    initial: p.name,
                    title: '名前を変える',
                  );
                  if (name != null) await playlists.rename(i, name);
                } else if (value == 'delete') {
                  final ok = await _confirmDelete(context, p.name);
                  if (ok) await playlists.delete(i);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('名前を変える')),
                PopupMenuItem(value: 'delete', child: Text('削除する')),
              ],
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlaylistDetailScreen(index: i),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('「$name」を削除しますか'),
        content: const Text('プレイリストだけが消えます。音楽ファイルは端末に残ります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
