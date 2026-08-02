String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

String formatMillis(int? ms) =>
    formatDuration(Duration(milliseconds: ms ?? 0));

/// MediaStoreは不明なアーティストを `<unknown>` で返すことがある。
String prettyArtist(String? artist) {
  if (artist == null || artist.isEmpty || artist == '<unknown>') {
    return '不明なアーティスト';
  }
  return artist;
}

String prettyAlbum(String? album) {
  if (album == null || album.isEmpty) return '不明なアルバム';
  return album;
}
