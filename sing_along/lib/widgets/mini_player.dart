import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/playing_screen.dart';
import '../services/player_service.dart';
import 'artwork.dart';

/// 一覧の上に常駐する小さいプレイヤー。タップで再生画面へ。
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final song = player.current;
    if (song == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PlayingScreen()),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 再生位置。細い線だけ出す。
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snapshot) {
                final total = player.duration?.inMilliseconds ?? 0;
                final position = snapshot.data?.inMilliseconds ?? 0;
                final value = total == 0 ? 0.0 : (position / total).clamp(0.0, 1.0);
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Artwork(song: song, size: 42),
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
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: player.previous,
                  ),
                  IconButton(
                    icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: player.togglePlay,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: player.next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
