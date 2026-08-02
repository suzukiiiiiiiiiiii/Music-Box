import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../services/playlist_service.dart';
import '../widgets/song_actions.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PlaylistService>();
    final library = context.watch<LibraryService>();
    final favorites = library.resolve(service.favorites);

    return Scaffold(
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.favorite),
            ),
            title: const Text('お気に入り'),
            subtitle: Text('${favorites.length}曲'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PlaylistDetailScreen.favorites(),
              ),
            ),
          ),
          const Divider(),
          if (service.playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: EmptyHint(
                icon: Icons.playlist_add,
                text: '右下の + からプレイリストを作れます',
              ),
            ),
          for (var i = 0; i < service.playlists.length; i++)
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text(service.playlists[i].name),
              subtitle: Text('${service.playlists[i].length}曲'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlaylistDetailScreen(index: i),
                ),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'rename') {
                    final name = await promptForName(
                      context,
                      title: '名前を変える',
                      initial: service.playlists[i].name,
                    );
                    if (name != null) await service.rename(i, name);
                  } else if (value == 'delete') {
                    await service.delete(i);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('名前を変える')),
                  PopupMenuItem(value: 'delete', child: Text('削除')),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await promptForName(context, title: '新しいプレイリスト');
          if (name != null) await service.create(name);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
