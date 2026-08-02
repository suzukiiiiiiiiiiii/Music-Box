import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../services/player_controller.dart';
import '../services/playlist_controller.dart';
import '../utils.dart';
import 'artwork.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.trailing,
    this.showArtwork = true,
  });

  final SongModel song;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showArtwork;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = context.select<PlayerController, int?>(
      (p) => p.currentSong?.id,
    );
    final isCurrent = current == song.id;
    final isFav = context.select<PlaylistController, bool>(
      (p) => p.isFavorite(song.id),
    );

    return ListTile(
      onTap: onTap,
      onLongPress: () => showSongActions(context, song),
      leading: showArtwork ? Artwork(id: song.id) : null,
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
          color: isCurrent ? scheme.primary : scheme.onSurface,
        ),
      ),
      subtitle: Text(
        '${prettyArtist(song.artist)} · ${formatMillis(song.duration)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
      ),
      trailing: trailing ??
          (isFav
              ? Icon(Icons.favorite_rounded, size: 18, color: scheme.primary)
              : null),
    );
  }
}

/// 曲の長押しメニュー。
Future<void> showSongActions(BuildContext context, SongModel song) async {
  final player = context.read<PlayerController>();
  final playlists = context.read<PlaylistController>();

  await showModalBottomSheet(
    context: context,
    builder: (sheetContext) {
      final isFav = playlists.isFavorite(song.id);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Artwork(id: song.id, size: 44),
              title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(prettyArtist(song.artist), maxLines: 1),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(isFav
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded),
              title: Text(isFav ? 'お気に入りから外す' : 'お気に入りに追加'),
              onTap: () {
                playlists.toggleFavorite(song.id);
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_play_rounded),
              title: const Text('次に再生'),
              onTap: () {
                player.playNext(song);
                Navigator.pop(sheetContext);
                _toast(context, '次に再生します');
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('キューの最後に追加'),
              onTap: () {
                player.addToQueue(song);
                Navigator.pop(sheetContext);
                _toast(context, 'キューに追加しました');
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('プレイリストに追加'),
              onTap: () {
                Navigator.pop(sheetContext);
                showAddToPlaylist(context, [song.id]);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// プレイリスト選択シート。新規作成もここから。
Future<void> showAddToPlaylist(BuildContext context, List<int> songIds) async {
  final playlists = context.read<PlaylistController>();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: AnimatedBuilder(
          animation: playlists,
          builder: (_, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'プレイリストに追加',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: const Text('新しいプレイリストを作る'),
                onTap: () async {
                  final name = await promptPlaylistName(context);
                  if (name == null) return;
                  await playlists.create(name, songIds);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (context.mounted) _toast(context, '$name に追加しました');
                },
              ),
              if (playlists.playlists.isNotEmpty) const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.playlists.length,
                  itemBuilder: (_, i) {
                    final p = playlists.playlists[i];
                    return ListTile(
                      leading: const Icon(Icons.queue_music_rounded),
                      title: Text(p.name),
                      subtitle: Text('${p.songIds.length}曲'),
                      onTap: () async {
                        await playlists.addSongs(i, songIds);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (context.mounted) _toast(context, '${p.name} に追加しました');
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

/// プレイリスト名の入力ダイアログ。
Future<String?> promptPlaylistName(
  BuildContext context, {
  String initial = '',
  String title = 'プレイリスト名',
}) async {
  final controller = TextEditingController(text: initial);
  final playlists = context.read<PlaylistController>();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      String? error;
      return StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '例: 作業用',
              errorText: error,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  setState(() => error = '名前を入力してください');
                  return;
                }
                if (name != initial && playlists.nameExists(name)) {
                  setState(() => error = '同じ名前のプレイリストがあります');
                  return;
                }
                Navigator.pop(dialogContext, name);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      );
    },
  );
}

void _toast(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
