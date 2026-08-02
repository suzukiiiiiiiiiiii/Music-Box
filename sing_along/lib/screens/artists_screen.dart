import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../widgets/artwork.dart';
import '../widgets/song_actions.dart';
import 'song_list_screen.dart';

class ArtistsScreen extends StatelessWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final artists = library.artists();

    if (artists.isEmpty) {
      return const EmptyHint(icon: Icons.person_outline, text: 'アーティストがいません');
    }

    return ListView.builder(
      itemCount: artists.length,
      itemBuilder: (context, i) {
        final artist = artists[i];
        final cover = artist.songs.firstWhere(
          (s) => s.artPath != null,
          orElse: () => artist.songs.first,
        );

        return ListTile(
          leading: Artwork(song: cover, size: 48, radius: 24),
          title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${artist.songs.length}曲・${artist.albumCount}枚'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SongListScreen(
                title: artist.name,
                songs: artist.songs,
              ),
            ),
          ),
          onLongPress: () => showCollectionActions(
            context,
            title: artist.name,
            songs: artist.songs,
          ),
        );
      },
    );
  }
}
