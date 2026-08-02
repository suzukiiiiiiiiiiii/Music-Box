/// LRC(時刻つき歌詞)の解析。
///
/// 対応している書き方:
///
///   [00:12.34]歌詞          ふつうの行
///   [00:12.34][01:20.5]歌詞  同じ行を複数の時刻に出す(サビの繰り返しなど)
///   [ti:曲名] [ar:歌手]      メタ情報。読み飛ばす
///   [offset:+500]            全体の時刻をずらす(ミリ秒)
///
/// 時刻タグが1つも無ければ、ただの歌詞テキストとして扱う。
library;

class LyricLine {
  const LyricLine(this.time, this.text);

  final Duration time;
  final String text;
}

class Lyrics {
  const Lyrics({this.lines = const [], this.plainLines = const []});

  /// 時刻つきの行。時刻の昇順。
  final List<LyricLine> lines;

  /// 時刻が無かったときの歌詞。
  final List<String> plainLines;

  bool get isSynced => lines.isNotEmpty;
  bool get isEmpty => lines.isEmpty && plainLines.isEmpty;

  static const empty = Lyrics();

  // [mm:ss] [mm:ss.xx] [mm:ss:xx] のどれでも拾う。
  static final _timeTag = RegExp(r'\[(\d{1,3}):([0-5]?\d)(?:[.:](\d{1,3}))?\]');
  // [ti:...] のようなメタ情報。数字で始まらないものだけをメタとみなす。
  static final _metaTag = RegExp(r'^\[([a-zA-Z]+):(.*)\]$');

  static Lyrics parse(String raw) {
    if (raw.trim().isEmpty) return empty;

    var offset = Duration.zero;
    final lines = <LyricLine>[];
    final plain = <String>[];

    for (final rawLine in raw.split(RegExp(r'\r\n|\r|\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        plain.add('');
        continue;
      }

      final meta = _metaTag.firstMatch(line);
      if (meta != null) {
        if (meta.group(1)!.toLowerCase() == 'offset') {
          offset = Duration(milliseconds: int.tryParse(meta.group(2)!.trim()) ?? 0);
        }
        // それ以外のメタ情報は表示に使わないので捨てる
        continue;
      }

      final matches = _timeTag.allMatches(line).toList();
      if (matches.isEmpty) {
        plain.add(line);
        continue;
      }

      // 時刻タグは行頭に固まっている。最後のタグより後ろが歌詞。
      final text = line.substring(matches.last.end).trim();
      for (final m in matches) {
        lines.add(LyricLine(_timeOf(m), text));
      }
    }

    if (lines.isEmpty) {
      // 空行だけが残ることがあるので落とす
      final body = plain.where((l) => l.isNotEmpty).toList();
      return body.isEmpty ? empty : Lyrics(plainLines: body);
    }

    // offset は「+ で歌詞が早く出る」向き。時刻から引く。
    final shifted = offset == Duration.zero
        ? lines
        : [
            for (final l in lines)
              LyricLine(_clampToZero(l.time - offset), l.text),
          ];
    shifted.sort((a, b) => a.time.compareTo(b.time));
    return Lyrics(lines: shifted);
  }

  static Duration _timeOf(RegExpMatch m) {
    final minutes = int.parse(m.group(1)!);
    final seconds = int.parse(m.group(2)!);
    final fraction = m.group(3);

    // .5 は 500ms、.55 は 550ms、.555 は 555ms。桁数で意味が変わる。
    var millis = 0;
    if (fraction != null) {
      millis = int.parse(fraction.padRight(3, '0').substring(0, 3));
    }
    return Duration(minutes: minutes, seconds: seconds, milliseconds: millis);
  }

  static Duration _clampToZero(Duration d) => d.isNegative ? Duration.zero : d;

  /// 今流れている行の位置。まだ最初の行に達していなければ -1。
  int indexAt(Duration position) {
    if (lines.isEmpty) return -1;

    var low = 0;
    var high = lines.length - 1;
    var found = -1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].time <= position) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }
}
