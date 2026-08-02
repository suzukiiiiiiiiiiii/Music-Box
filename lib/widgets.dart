import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'player_model.dart';
import 'screens/now_playing_screen.dart';
import 'settings_model.dart';

/// アートワーク。無い曲はタイトルから作った2色グラデーションで代用する。
class Artwork extends StatelessWidget {
  final Song? song;
  final double size;
  final double radius;

  const Artwork({super.key, required this.song, this.size = 48, this.radius = 10});

  @override
  Widget build(BuildContext context) {
    final art = song?.artPath;
    final child = (art != null && File(art).existsSync())
        ? Image.file(File(art), width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(context))
        : _fallback(context);

    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
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

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.active = false,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsModel>();
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      leading: settings.showArtInList
          ? Artwork(song: song, size: 46 * settings.density, radius: settings.radius * 0.6)
          : null,
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
        ],
      ),
    );
  }
}

/// 画面の下に常駐する小さいプレイヤー。タップで全画面に上がる。
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
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
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
                    Artwork(song: song, size: 44, radius: settings.radius * 0.6),
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
      child: Padding(
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
