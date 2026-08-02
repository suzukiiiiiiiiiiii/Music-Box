import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../services/library_controller.dart';
import '../services/settings_controller.dart';
import '../utils.dart';
import '../widgets/artwork.dart';
import 'song_list_screen.dart';

class AlbumsTab extends StatelessWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final settings = context.watch<SettingsController>();
    final albums = library.albums;

    void open(AlbumModel a) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SongListScreen(
            title: a.album,
            subtitle: prettyArtist(a.artist),
            artworkId: a.id,
            artworkType: ArtworkType.ALBUM,
            loader: () => library.songsOfAlbum(a.id),
          ),
        ),
      );
    }

    if (!settings.albumsAsGrid) {
      return ListView.builder(
        itemCount: albums.length,
        itemBuilder: (_, i) {
          final a = albums[i];
          return ListTile(
            leading: Artwork(id: a.id, type: ArtworkType.ALBUM, icon: Icons.album_rounded),
            title: Text(a.album, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${prettyArtist(a.artist)} · ${a.numOfSongs}曲',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => open(a),
          );
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisSpacing: 18,
        crossAxisSpacing: 14,
        childAspectRatio: 0.76,
      ),
      itemCount: albums.length,
      itemBuilder: (context, i) {
        final a = albums[i];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => open(a),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (_, c) => Artwork(
                    id: a.id,
                    type: ArtworkType.ALBUM,
                    size: c.maxWidth,
                    radius: 14,
                    icon: Icons.album_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                a.album,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              Text(
                prettyArtist(a.artist),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
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
