import 'package:flutter_test/flutter_test.dart';
import 'package:sing_along/models/play_queue.dart';
import 'package:sing_along/models/song.dart';
import 'package:sing_along/services/library_service.dart';

Song song(
  String path, {
  String? title,
  String artist = 'アーティストA',
  String album = 'アルバムA',
  int? track,
  int seconds = 200,
}) =>
    Song(
      path: path,
      title: title ?? path.split('/').last,
      artist: artist,
      album: album,
      trackNumber: track,
      duration: Duration(seconds: seconds),
    );

void main() {
  group('並べ替え', () {
    test('アルバム順は同じアルバムの中でトラック番号に従う', () {
      final sorted = sortSongs([
        song('/m/c.mp3', title: 'c', album: 'あ', track: 3),
        song('/m/a.mp3', title: 'a', album: 'あ', track: 1),
        song('/m/b.mp3', title: 'b', album: 'あ', track: 2),
      ], SongSort.album);

      expect(sorted.map((s) => s.title), ['a', 'b', 'c']);
    });

    test('トラック番号が無い曲は後ろに回る', () {
      final sorted = sortSongs([
        song('/m/x.mp3', title: 'x'),
        song('/m/y.mp3', title: 'y', track: 1),
      ], SongSort.album);

      expect(sorted.first.title, 'y');
    });

    test('逆順を指定すると並びが反転する', () {
      final sorted = sortSongs([
        song('/m/a.mp3', title: 'a'),
        song('/m/b.mp3', title: 'b'),
      ], SongSort.title, descending: true);

      expect(sorted.map((s) => s.title), ['b', 'a']);
    });
  });

  group('まとめと絞り込み', () {
    final library = LibraryService()
      ..seed([
        song('/m/rock/1.mp3', title: '雨', artist: '甲', album: '青'),
        song('/m/rock/2.mp3', title: '風', artist: '甲', album: '青'),
        song('/m/jazz/3.mp3', title: '雪', artist: '乙', album: '白'),
        song('/m/jazz/sub/4.mp3', title: '空', artist: '乙', album: '白'),
      ]);

    test('アルバムはアルバム名とアーティストの組でまとめる', () {
      final albums = library.albums();
      expect(albums.length, 2);
      expect(albums.map((a) => a.name).toSet(), {'青', '白'});
    });

    test('アーティストは持っているアルバムの枚数を数える', () {
      final artists = library.artists();
      expect(artists.length, 2);
      expect(artists.firstWhere((a) => a.name == '乙').albumCount, 1);
      expect(artists.firstWhere((a) => a.name == '乙').songs.length, 2);
    });

    test('フォルダ直下と、それ以下すべてを区別する', () {
      expect(library.songsInFolder('/m/jazz').length, 1);
      expect(library.songsUnderFolder('/m/jazz').length, 2);
    });

    test('検索は曲名・アーティスト・アルバムに掛かる', () {
      expect(library.search('雨').length, 1);
      expect(library.search('乙').length, 2);
      expect(library.search('青').length, 2);
      expect(library.search('  ').length, 0);
    });

    test('パスから曲を引ける。索引に無いものは落ちる', () {
      final resolved = library.resolve(['/m/rock/1.mp3', '/m/どこにもない.mp3']);
      expect(resolved.length, 1);
      expect(resolved.first.title, '雨');
    });
  });

  group('キューの保存と復元', () {
    test('往復しても中身が変わらない', () {
      final queue = PlayQueue(
        name: '通勤',
        paths: ['/m/1.mp3', '/m/2.mp3'],
        index: 1,
        positionMs: 42000,
      );

      final restored = PlayQueue.fromJson(queue.toJson());

      expect(restored.name, '通勤');
      expect(restored.paths, ['/m/1.mp3', '/m/2.mp3']);
      expect(restored.index, 1);
      expect(restored.positionMs, 42000);
    });

    test('壊れた値でも既定に落として読める', () {
      final restored = PlayQueue.fromJson(const {});

      expect(restored.name, 'キュー');
      expect(restored.paths, isEmpty);
      expect(restored.index, 0);
    });
  });
}
