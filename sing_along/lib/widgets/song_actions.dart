import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/player_service.dart';
import '../services/playlist_service.dart';
import '../utils.dart';
import 'artwork.dart';

/// 曲を長押ししたときに出る操作の一覧。
Future<void> showSongActions(BuildContext context, Song song) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _SongActionsSheet(song: song),
  );
}

class _SongActionsSheet extends StatelessWidget {
  const _SongActionsSheet({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerService>();
    final playlists = context.watch<PlaylistService>();
    final favorite = playlists.isFavorite(song.path);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Artwork(song: song, size: 44),
              title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${song.artist} · ${formatDuration(song.duration)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('この曲だけ再生'),
              onTap: () {
                player.playAll([song]);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('次に再生'),
              onTap: () {
                player.enqueue([song], next: true);
                Navigator.pop(context);
                _toast(context, '次に再生します');
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('キューの最後に追加'),
              onTap: () {
                player.enqueue([song]);
                Navigator.pop(context);
                _toast(context, 'キューに追加しました');
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('別のキューに追加'),
              onTap: () async {
                Navigator.pop(context);
                await pickQueueAndEnqueue(context, [song]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.library_add),
              title: const Text('プレイリストに追加'),
              onTap: () async {
                Navigator.pop(context);
                await pickPlaylistAndAdd(context, [song.path]);
              },
            ),
            ListTile(
              leading: Icon(favorite ? Icons.favorite : Icons.favorite_border),
              title: Text(favorite ? 'お気に入りから外す' : 'お気に入りに入れる'),
              onTap: () {
                playlists.toggleFavorite(song.path);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('ファイルの場所'),
              subtitle: Text(song.path, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// 追加先のキューを選ばせてから足す。
Future<void> pickQueueAndEnqueue(BuildContext context, List<Song> songs) async {
  final player = context.read<PlayerService>();
  final selected = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('どのキューに追加しますか')),
          for (var i = 0; i < player.queues.length; i++)
            ListTile(
              leading: Icon(
                i == player.activeIndex ? Icons.play_circle : Icons.queue_music,
              ),
              title: Text(player.queues[i].name),
              subtitle: Text('${player.queues[i].length}曲'),
              onTap: () => Navigator.pop(sheetContext, i),
            ),
        ],
      ),
    ),
  );
  if (selected == null || !context.mounted) return;
  await player.enqueue(songs, queueIndex: selected);
  if (context.mounted) {
    _toast(context, '${player.queues[selected].name} に追加しました');
  }
}

/// 追加先のプレイリストを選ばせてから足す。その場で作ることもできる。
Future<void> pickPlaylistAndAdd(BuildContext context, List<String> paths) async {
  final service = context.read<PlaylistService>();
  final selected = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('新しいプレイリストを作る'),
            onTap: () => Navigator.pop(sheetContext, -1),
          ),
          const Divider(),
          if (service.playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('まだプレイリストがありません'),
            ),
          for (var i = 0; i < service.playlists.length; i++)
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text(service.playlists[i].name),
              subtitle: Text('${service.playlists[i].length}曲'),
              onTap: () => Navigator.pop(sheetContext, i),
            ),
        ],
      ),
    ),
  );

  if (selected == null || !context.mounted) return;

  if (selected == -1) {
    final name = await promptForName(context, title: '新しいプレイリスト');
    if (name == null || !context.mounted) return;
    await service.create(name, paths);
    if (context.mounted) _toast(context, '$name を作りました');
    return;
  }

  await service.addPaths(selected, paths);
  if (context.mounted) {
    _toast(context, '${service.playlists[selected].name} に追加しました');
  }
}

Future<String?> promptForName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '名前'),
        onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('やめる'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            Navigator.pop(dialogContext, value.isEmpty ? null : value);
          },
          child: const Text('決定'),
        ),
      ],
    ),
  );
}

/// 曲をまとめて操作するときの入口。アルバムやフォルダの「…」から呼ぶ。
Future<void> showCollectionActions(
  BuildContext context, {
  required String title,
  required List<Song> songs,
}) async {
  if (songs.isEmpty) return;
  final player = context.read<PlayerService>();

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              describeSongs(
                songs.length,
                songs.fold(Duration.zero, (sum, s) => sum + (s.duration ?? Duration.zero)),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('まとめて再生'),
            onTap: () {
              player.playAll(songs);
              Navigator.pop(sheetContext);
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_play),
            title: const Text('次に再生'),
            onTap: () {
              player.enqueue(songs, next: true);
              Navigator.pop(sheetContext);
            },
          ),
          ListTile(
            leading: const Icon(Icons.queue_music),
            title: const Text('別のキューに追加'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await pickQueueAndEnqueue(context, songs);
            },
          ),
          ListTile(
            leading: const Icon(Icons.library_add),
            title: const Text('プレイリストに追加'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await pickPlaylistAndAdd(context, songs.map((s) => s.path).toList());
            },
          ),
        ],
      ),
    ),
  );
}

/// 再スキャンを促すときなどの短い知らせ。
void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
}

void notify(BuildContext context, String message) => _toast(context, message);

/// 曲の一覧が空のときに出す案内。
class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// ライブラリ由来の一覧をまとめて扱うときの合計時間。
Duration totalDuration(List<Song> songs) =>
    songs.fold(Duration.zero, (sum, s) => sum + (s.duration ?? Duration.zero));
