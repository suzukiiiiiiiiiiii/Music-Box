import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// ジャケット画像。無い曲は落ち着いたプレースホルダを出す。
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.id,
    this.type = ArtworkType.AUDIO,
    this.size = 52,
    this.radius = 10,
    this.icon = Icons.music_note_rounded,
  });

  final int id;
  final ArtworkType type;
  final double size;
  final double radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return QueryArtworkWidget(
      id: id,
      type: type,
      keepOldArtwork: true,
      quality: 100,
      size: size > 200 ? 600 : 200,
      artworkWidth: size,
      artworkHeight: size,
      artworkFit: BoxFit.cover,
      artworkBorder: BorderRadius.circular(radius),
      nullArtworkWidget: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surfaceContainerHighest,
              scheme.surfaceContainerHigh,
            ],
          ),
        ),
        child: Icon(
          icon,
          size: size * 0.42,
          color: scheme.onSurfaceVariant.withOpacity(0.55),
        ),
      ),
    );
  }
}
