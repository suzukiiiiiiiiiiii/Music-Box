import 'package:flutter_test/flutter_test.dart';
import 'package:sing_along/models/lyrics.dart';

void main() {
  group('LRC の解析', () {
    test('時刻タグつきの行を読む', () {
      final lyrics = Lyrics.parse('''
[ti:テスト曲]
[ar:だれか]

[00:01.50]ひとつめ
[00:12.25]ふたつめ
[01:05.00]みっつめ
''');

      expect(lyrics.isSynced, isTrue);
      expect(lyrics.lines.length, 3);
      expect(lyrics.lines[0].time, const Duration(seconds: 1, milliseconds: 500));
      expect(lyrics.lines[0].text, 'ひとつめ');
      expect(lyrics.lines[2].time, const Duration(minutes: 1, seconds: 5));
    });

    test('小数部の桁数で意味が変わる', () {
      final lyrics = Lyrics.parse('[00:10.5]あ\n[00:11.05]い\n[00:12.005]う');

      expect(lyrics.lines[0].time.inMilliseconds, 10500);
      expect(lyrics.lines[1].time.inMilliseconds, 11050);
      expect(lyrics.lines[2].time.inMilliseconds, 12005);
    });

    test('1行に複数の時刻タグがあると、その回数ぶん行ができる', () {
      final lyrics = Lyrics.parse('[00:10.00][01:10.00][02:10.00]サビ');

      expect(lyrics.lines.length, 3);
      expect(lyrics.lines.map((l) => l.text).toSet(), {'サビ'});
      expect(lyrics.lines[1].time, const Duration(minutes: 1, seconds: 10));
    });

    test('offset は時刻から引かれ、負にはならない', () {
      final lyrics = Lyrics.parse('[offset:+500]\n[00:10.00]あ\n[00:00.20]い');

      // 10.0秒 - 0.5秒
      expect(lyrics.lines.last.time.inMilliseconds, 9500);
      // 0.2秒 - 0.5秒 は 0 で止める
      expect(lyrics.lines.first.time, Duration.zero);
    });

    test('時刻が無ければただの歌詞として扱う', () {
      final lyrics = Lyrics.parse('ふつうの歌詞\nもう1行');

      expect(lyrics.isSynced, isFalse);
      expect(lyrics.isEmpty, isFalse);
      expect(lyrics.plainLines, ['ふつうの歌詞', 'もう1行']);
    });

    test('空文字とメタ情報だけなら空になる', () {
      expect(Lyrics.parse('').isEmpty, isTrue);
      expect(Lyrics.parse('   \n\n').isEmpty, isTrue);
      expect(Lyrics.parse('[ti:曲名]\n[ar:歌手]').isEmpty, isTrue);
    });

    test('時刻の順に並べ替える', () {
      final lyrics = Lyrics.parse('[00:30.00]あと\n[00:10.00]さき');

      expect(lyrics.lines.first.text, 'さき');
      expect(lyrics.lines.last.text, 'あと');
    });
  });

  group('今の行を探す', () {
    final lyrics = Lyrics.parse('[00:10.00]あ\n[00:20.00]い\n[00:30.00]う');

    test('最初の行より前は -1', () {
      expect(lyrics.indexAt(const Duration(seconds: 5)), -1);
    });

    test('ちょうどその時刻ならその行', () {
      expect(lyrics.indexAt(const Duration(seconds: 10)), 0);
      expect(lyrics.indexAt(const Duration(seconds: 20)), 1);
    });

    test('次の行までの間は手前の行のまま', () {
      expect(lyrics.indexAt(const Duration(seconds: 19)), 0);
      expect(lyrics.indexAt(const Duration(seconds: 29)), 1);
    });

    test('最後の行を過ぎても最後の行を指す', () {
      expect(lyrics.indexAt(const Duration(minutes: 5)), 2);
    });

    test('歌詞が無ければ -1', () {
      expect(Lyrics.empty.indexAt(const Duration(seconds: 10)), -1);
    });
  });
}
