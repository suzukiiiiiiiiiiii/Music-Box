import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'library_model.dart';
import 'models.dart';
import 'player_model.dart';
import 'screens/now_playing_screen.dart';
import 'settings_model.dart';

/// アートワーク。無い曲はタイトルから作った2色グラデーションで代用する。
/// 角の落とし方はテーマ工房の設定に従う。
class Artwork extends StatelessWidget {
  final Song? song;
  final double size;

  /// 角丸の半径。省略すると設定の丸みから決める。
  final double? radius;

  const Artwork({super.key, required this.song, this.size = 48, this.radius});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsModel>();
    final r = switch (settings.artworkShape) {
      ArtworkShape.circle => size / 2,
      ArtworkShape.square => 0.0,
      ArtworkShape.rounded => radius ?? settings.radius * 0.6,
    };

    final art = song?.artPath;
    final child = (art != null && File(art).existsSync())
        ? Image.file(File(art),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(context))
        : _fallback(context);

    return ClipRRect(borderRadius: BorderRadius.circular(r), child: child);
  }

  Widget _fallback(BuildContext context) {
    final seed = (song?.title ?? '?').hashCode;
    final hue = (seed % 360).toDouble();
    final a = HSLColor.fromAHSL(1, hue, 0.35, 0.42).toColor();
    final b = HSLColor.fromAHSL(1, (hue + 40) % 360, 0.35, 0.26).toColor();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [a, b],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.music_note_rounded,
          size: size * 0.42, color: Colors.white.withValues(alpha: 0.85)),
    );
  }
}

class SongTile extends StatelessWidget {
  final Song song;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  /// 並べ替えハンドルなど、右端に足したいもの。
  final Widget? trailing;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.active = false,
    this.onMore,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsModel>();
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      leading: settings.showArtInList
          ? Artwork(song: song, size: 46 * settings.density)
          : (active
              ? Icon(Icons.equalizer_rounded, color: scheme.primary)
              : null),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? scheme.primary : null,
        ),
      ),
      subtitle: Text(
        '${song.artist} · ${song.album}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatDuration(song.duration),
              style: Theme.of(context).textTheme.bodySmall),
          if (onMore != null)
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: onMore,
              tooltip: 'この曲の操作',
            ),
          ?trailing,
        ],
      ),
    );
  }
}

/// アルバム/アーティストをタイル状に並べるときの1枚。
class CoverCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Song? cover;
  final VoidCallback onTap;

  const CoverCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsModel>();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(settings.radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => Artwork(
                song: cover,
                size: box.maxWidth,
                radius: settings.radius,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// 画面の下に常駐する小さいプレイヤー。タップで全画面に上がる。
/// Scaffold の bottomNavigationBar 側に置くので、本文や FAB とは重ならない。
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerModel>();
    final settings = context.watch<SettingsModel>();
    final song = player.current;
    if (song == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(settings.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, snapshot) {
                  final pos = snapshot.data ?? Duration.zero;
                  final total = player.duration ?? Duration.zero;
                  final value = total.inMilliseconds == 0
                      ? 0.0
                      : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 2,
                    backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                    color: scheme.primary,
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Artwork(song: song, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(player.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                      iconSize: 30,
                      onPressed: player.togglePlay,
                      tooltip: player.isPlaying ? '一時停止' : '再生',
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded),
                      iconSize: 28,
                      onPressed: player.next,
                      tooltip: '次の曲',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 何も無い画面は、次にやることを1つだけ提示する。
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 曲の「…」から出すシート。ここで完結させたいので、プレイリストが
/// 1つも無くてもその場で作れるようにしてある。
Future<void> showSongMenu(BuildContext context, Song song) async {
  final library = context.read<LibraryModel>();
  final player = context.read<PlayerModel>();
  final messenger = ScaffoldMessenger.of(context);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: Artwork(song: song, size: 44),
            title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${song.artist} · ${song.album}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded),
            title: const Text('今すぐ再生'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              player.playQueue([song], 0, label: song.album);
            },
          ),
          ListTile(
            leading: const Icon(Icons.queue_play_next_rounded),
            title: const Text('次に再生'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              player.playNext(song, label: song.album);
              messenger.showSnackBar(
                const SnackBar(content: Text('次に再生します')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: const Text('キューの最後に追加'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              player.addToQueue(song, label: song.album);
              messenger.showSnackBar(
                const SnackBar(content: Text('キューに追加しました')),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.library_add_rounded),
            title: const Text('プレイリストに追加'),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await _addToPlaylistFlow(context, library, song, messenger);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('曲の情報'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _showSongInfo(context, song);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _addToPlaylistFlow(
  BuildContext context,
  LibraryModel library,
  Song song,
  ScaffoldMessengerState messenger,
) async {
  if (!context.mounted) return;
  final chosen = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('どのプレイリストに追加しますか')),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: const Text('新しいプレイリストを作る'),
            onTap: () => Navigator.of(sheetContext).pop(''),
          ),
          ...library.playlists.map(
            (pl) => ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: Text(pl.name),
              subtitle: Text('${pl.paths.length} 曲'),
              onTap: () => Navigator.of(sheetContext).pop(pl.name),
            ),
          ),
        ],
      ),
    ),
  );

  if (chosen == null || !context.mounted) return;

  var name = chosen;
  if (name.isEmpty) {
    final created = await promptPlaylistName(context);
    if (created == null) return;
    name = created;
  }
  await library.addToPlaylist(name, song.path);
  messenger.showSnackBar(SnackBar(content: Text('「$name」に追加しました')));
}

/// プレイリスト名を尋ねて作る。作れた名前を返す。
Future<String?> promptPlaylistName(BuildContext context) async {
  final library = context.read<LibraryModel>();
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('プレイリストを作る'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '例: 作業用、通学中'),
        onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
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
  if (name == null || name.trim().isEmpty) return null;
  return library.createPlaylist(name);
}

void _showSongInfo(BuildContext context, Song song) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('曲の情報'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow('曲名', song.title),
            _InfoRow('アーティスト', song.artist),
            _InfoRow('アルバム', song.album),
            _InfoRow('長さ', formatDuration(song.duration)),
            _InfoRow('場所', song.path),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          SelectableText(value),
        ],
      ),
    );
  }
}
