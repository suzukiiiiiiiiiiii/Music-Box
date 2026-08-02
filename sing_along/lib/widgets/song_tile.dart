import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/player_service.dart';
import '../services/playlist_service.dart';
import '../utils.dart';
import 'artwork.dart';
import 'song_actions.dart';

/// 一覧に並ぶ曲1行。再生中の曲は色が変わる。
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.trailing,
    this.showArtwork = true,
    this.dense = false,
  });

  final Song song;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showArtwork;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playing = context.select<PlayerService, bool>(
      (p) => p.current?.path == song.path,
    );
    final favorite = context.select<PlaylistService, bool>(
      (p) => p.isFavorite(song.path),
    );

    return ListTile(
      dense: dense,
      leading: showArtwork ? Artwork(song: song, size: dense ? 40 : 48) : null,
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: playing ? scheme.primary : null,
          fontWeight: playing ? FontWeight.w600 : null,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (favorite)
                Icon(Icons.favorite, size: 14, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                formatDuration(song.duration),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
      onTap: onTap,
      onLongPress: () => showSongActions(context, song),
    );
  }
}
