String formatDuration(Duration? d) {
  if (d == null) return '--:--';
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  final mm = hours > 0
      ? minutes.toString().padLeft(2, '0')
      : minutes.toString();
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

/// 「12曲・48分」のような添え書き。
String describeSongs(int count, Duration total) {
  final minutes = total.inMinutes;
  if (minutes <= 0) return '$count曲';
  if (minutes < 60) return '$count曲・$minutes分';
  final hours = minutes ~/ 60;
  return '$count曲・$hours時間${minutes % 60}分';
}
