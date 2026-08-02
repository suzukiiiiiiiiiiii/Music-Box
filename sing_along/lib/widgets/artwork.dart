import 'dart:io';

import 'package:flutter/material.dart';

import '../models/song.dart';

/// ジャケット。無い曲は曲名から作った落ち着いた色で埋める。
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.song,
    this.size = 48,
    this.radius = 6,
  });

  final Song? song;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final art = song?.artPath;
    final child = art != null && File(art).existsSync()
        ? Image.file(
            File(art),
            width: size,
            height: size,
            fit: BoxFit.cover,
            // キャッシュが壊れていても落とさない
            errorBuilder: (_, __, ___) => _fallback(context),
          )
        : _fallback(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }

  Widget _fallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final seed = song?.title.hashCode ?? 0;
    final hue = (seed.abs() % 360).toDouble();
    final base = HSLColor.fromAHSL(1, hue, 0.32, 0.42).toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, Color.lerp(base, scheme.surface, 0.55)!],
        ),
      ),
      child: Icon(
        Icons.music_note,
        size: size * 0.42,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}
