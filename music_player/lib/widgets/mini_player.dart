import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/player_screen.dart';
import '../services/player_controller.dart';
import '../utils.dart';
import 'artwork.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final song = player.currentSong;
    final scheme = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        axisAlignment: -1,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: song == null
          ? const SizedBox.shrink(key: ValueKey('mini-empty'))
          : Padding(
              key: const ValueKey('mini-player'),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Material(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlayerScreen()),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Artwork(id: song.id, size: 44, radius: 12),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    prettyArtist(song.artist),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: player.isPlaying ? '一時停止' : '再生',
                              onPressed: player.togglePlay,
                              icon: Icon(
                                player.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 30,
                              ),
                            ),
                            IconButton(
                              tooltip: '次の曲',
                              onPressed: player.next,
                              icon: const Icon(Icons.skip_next_rounded, size: 26),
                            ),
                          ],
                        ),
                      ),
                      StreamBuilder<PositionData>(
                        stream: player.positionDataStream,
                        builder: (context, snapshot) {
                          final data = snapshot.data;
                          final total = data?.duration.inMilliseconds ?? 0;
                          final value = (total == 0)
                              ? 0.0
                              : (data!.position.inMilliseconds / total)
                                  .clamp(0.0, 1.0);
                          return LinearProgressIndicator(
                            value: value,
                            minHeight: 2.5,
                            backgroundColor: scheme.onSurface.withOpacity(0.10),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
