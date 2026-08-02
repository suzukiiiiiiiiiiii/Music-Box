import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../services/library_controller.dart';
import '../utils.dart';
import '../widgets/artwork.dart';
import 'song_list_screen.dart';

class ArtistsTab extends StatelessWidget {
  const ArtistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final artists = library.artists;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: artists.length,
      itemBuilder: (context, i) {
        final a = artists[i];
        return ListTile(
          leading: ClipOval(
            child: Artwork(
              id: a.id,
              type: ArtworkType.ARTIST,
              radius: 40,
              icon: Icons.person_rounded,
            ),
          ),
          title: Text(
            prettyArtist(a.artist),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('${a.numberOfAlbums ?? 0}枚 · ${a.numberOfTracks ?? 0}曲'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SongListScreen(
                title: prettyArtist(a.artist),
                subtitle: '${a.numberOfTracks ?? 0}曲',
                artworkId: a.id,
                artworkType: ArtworkType.ARTIST,
                loader: () => library.songsOfArtist(a.id),
              ),
            ),
          ),
        );
      },
    );
  }
}
