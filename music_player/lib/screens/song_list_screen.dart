import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../services/player_controller.dart';
import '../utils.dart';
import '../widgets/artwork.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';

/// アルバム・アーティストなど、まとまった曲を並べる汎用画面。
class SongListScreen extends StatefulWidget {
  const SongListScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.loader,
    this.artworkId,
    this.artworkType = ArtworkType.ALBUM,
  });

  final String title;
  final String subtitle;
  final Future<List<SongModel>> Function() loader;
  final int? artworkId;
  final ArtworkType artworkType;

  @override
  State<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends State<SongListScreen> {
  late Future<List<SongModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<SongModel>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final songs = snapshot.data!;
                  return CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        expandedHeight: 260,
                        flexibleSpace: FlexibleSpaceBar(
                          background: _Header(
                            title: widget.title,
                            subtitle: '${widget.subtitle} · ${songs.length}曲',
                            artworkId: widget.artworkId,
                            artworkType: widget.artworkType,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Row(
                            children: [
                              FilledButton.icon(
                                onPressed: () async {
                                  await player.playAll(songs);
                                  if (player.shuffleEnabled) {
                                    await player.toggleShuffle();
                                  }
                                },
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('再生'),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  if (songs.isEmpty) return;
                                  await player.playAll(songs);
                                  if (!player.shuffleEnabled) {
                                    await player.toggleShuffle();
                                  }
                                },
                                icon: const Icon(Icons.shuffle_rounded),
                                label: const Text('シャッフル'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverList.builder(
                        itemCount: songs.length,
                        itemBuilder: (_, i) => SongTile(
                          song: songs[i],
                          showArtwork: false,
                          onTap: () => player.playAll(songs, startIndex: i),
                          trailing: Text(
                            formatMillis(songs[i].duration),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  );
                },
              ),
            ),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.artworkId,
    required this.artworkType,
  });

  final String title;
  final String subtitle;
  final int? artworkId;
  final ArtworkType artworkType;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (artworkId != null)
          Opacity(
            opacity: 0.35,
            child: Artwork(
              id: artworkId!,
              type: artworkType,
              size: 600,
              radius: 0,
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.surface.withOpacity(0.4),
                scheme.surface,
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
