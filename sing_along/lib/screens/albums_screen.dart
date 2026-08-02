import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../widgets/artwork.dart';
import '../widgets/song_actions.dart';
import 'song_list_screen.dart';

/// アルバムをタイルで並べる。
class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final albums = library.albums();

    if (albums.isEmpty) {
      return const EmptyHint(icon: Icons.album_outlined, text: 'アルバムがありません');
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 0.78,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: albums.length,
      itemBuilder: (context, i) {
        final album = albums[i];
        final cover = album.songs.firstWhere(
          (s) => s.artPath != null,
          orElse: () => album.songs.first,
        );

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SongListScreen(
                title: album.name,
                subtitle: album.artist,
                songs: album.songs,
              ),
            ),
          ),
          onLongPress: () => showCollectionActions(
            context,
            title: album.name,
            songs: album.songs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Artwork(
                    song: cover,
                    size: constraints.maxWidth,
                    radius: 10,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                album.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
