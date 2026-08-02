import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/settings_service.dart';
import '../widgets/song_actions.dart';
import '../widgets/song_tile.dart';

/// 端末で見つかった曲の一覧。
class SongsScreen extends StatelessWidget {
  const SongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final settings = context.watch<SettingsService>();
    final player = context.read<PlayerService>();

    if (library.isEmpty) {
      return RefreshIndicator(
        onRefresh: library.scan,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: EmptyHint(
                icon: Icons.library_music_outlined,
                text: library.scanning
                    ? '曲を探しています…'
                    : library.lastError ?? 'まだ曲が見つかっていません',
                action: library.scanning
                    ? null
                    : FilledButton.icon(
                        onPressed: library.scan,
                        icon: const Icon(Icons.refresh),
                        label: const Text('端末を探す'),
                      ),
              ),
            ),
          ],
        ),
      );
    }

    final songs = sortSongs(
      library.songs,
      settings.songSort,
      descending: settings.songSortDescending,
    );

    return RefreshIndicator(
      onRefresh: library.scan,
      child: Column(
        children: [
          _SortBar(count: songs.length),
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

class _SortBar extends StatelessWidget {
  const _SortBar({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Text(
            '$count曲',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () async {
              final chosen = await showModalBottomSheet<SongSort>(
                context: context,
                showDragHandle: true,
                builder: (sheetContext) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final sort in SongSort.values)
                        RadioListTile<SongSort>(
                          value: sort,
                          groupValue: settings.songSort,
                          title: Text(sort.label),
                          onChanged: (v) => Navigator.pop(sheetContext, v),
                        ),
                    ],
                  ),
                ),
              );
              if (chosen != null) await settings.setSongSort(chosen);
            },
            icon: const Icon(Icons.sort, size: 18),
            label: Text(settings.songSort.label),
          ),
          IconButton(
            tooltip: settings.songSortDescending ? '逆順' : '順序',
            icon: Icon(
              settings.songSortDescending
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              size: 18,
            ),
            onPressed: () =>
                settings.setSongSortDescending(!settings.songSortDescending),
          ),
        ],
      ),
    );
  }
}
