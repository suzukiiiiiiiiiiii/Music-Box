import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/player_service.dart';
import '../utils.dart';
import '../widgets/artwork.dart';
import '../widgets/song_actions.dart';
import '../widgets/song_tile.dart';

/// アルバム・アーティスト・フォルダ・プレイリストの中身を出す共通の画面。
class SongListScreen extends StatelessWidget {
  const SongListScreen({
    super.key,
    required this.title,
    required this.songs,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Song> songs;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerService>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              subtitle ?? describeSongs(songs.length, totalDuration(songs)),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          ...actions,
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () =>
                showCollectionActions(context, title: title, songs: songs),
          ),
        ],
      ),
      body: songs.isEmpty
          ? const EmptyHint(icon: Icons.music_off_outlined, text: 'まだ曲がありません')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => player.playAll(songs),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('再生'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final shuffled = [...songs]..shuffle();
                            player.playAll(shuffled);
                          },
                          icon: const Icon(Icons.shuffle),
                          label: const Text('シャッフル'),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: songs.length,
                    itemBuilder: (context, i) => SongTile(
                      song: songs[i],
                      onTap: () => player.playAll(songs, startIndex: i),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// アルバムなどの見出しに使う大きめのジャケット。
class CollectionHeader extends StatelessWidget {
  const CollectionHeader({super.key, required this.song, required this.title, this.subtitle});

  final Song? song;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Artwork(song: song, size: 92, radius: 10),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle!,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
