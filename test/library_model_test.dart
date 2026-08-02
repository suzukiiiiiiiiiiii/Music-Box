import 'package:flutter_test/flutter_test.dart';
import 'package:music_box/library_model.dart';
import 'package:music_box/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

Song song(
  String title, {
  String artist = 'A',
  String album = 'X',
  DateTime? addedAt,
  String? path,
}) =>
    Song(
      path: path ?? '/music/$title.mp3',
      title: title,
      artist: artist,
      album: album,
      addedAt: addedAt,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('並べ替え', () {
    test('曲名は大文字小文字を無視して並ぶ', () {
      final lib = LibraryModel()..seedSongs([song('banana'), song('Apple')]);
      expect(
        lib.view(sort: SongSort.title).map((s) => s.title),
        ['Apple', 'banana'],
      );
    });

    test('新しい順。日時が無い曲は最後にまわす', () {
      final lib = LibraryModel()
        ..seedSongs([
          song('古い', addedAt: DateTime(2020)),
          song('日時なし'),
          song('新しい', addedAt: DateTime(2026)),
        ]);
      expect(
        lib.view(sort: SongSort.newest).map((s) => s.title),
        ['新しい', '古い', '日時なし'],
      );
    });

    test('アーティスト順は同着だと曲名で決める', () {
      final lib = LibraryModel()
        ..seedSongs([
          song('ざ', artist: 'B'),
          song('い', artist: 'A'),
          song('あ', artist: 'A'),
        ]);
      expect(
        lib.view(sort: SongSort.artist).map((s) => s.title),
        ['あ', 'い', 'ざ'],
      );
    });
  });

  group('検索', () {
    final lib = LibraryModel()
      ..seedSongs([
        song('海の歌', artist: '青井', album: '夏'),
        song('山の歌', artist: '緑川', album: '秋'),
      ]);

    test('曲名で当たる', () {
      expect(lib.search('海').map((s) => s.title), ['海の歌']);
    });

    test('アーティストで当たる', () {
      expect(lib.search('緑川').map((s) => s.title), ['山の歌']);
    });

    test('アルバム名で当たると、そのアルバムがまとめて残る', () {
      final groups = lib.groups((s) => s.album, query: '夏');
      expect(groups.keys, ['夏']);
      expect(groups['夏']!.map((s) => s.title), ['海の歌']);
    });

    test('空の検索語は全部返す', () {
      expect(lib.search('  ').length, 2);
    });
  });

  group('プレイリストの並べ替え', () {
    /// 画面に出ている並びと保存している paths がずれる状況を作る。
    /// b はファイルが見つからないので一覧から抜けている。
    Future<LibraryModel> withGap() async {
      final lib = LibraryModel()
        ..seedSongs([
          song('a', path: '/a.mp3'),
          song('c', path: '/c.mp3'),
          song('d', path: '/d.mp3'),
        ]);
      await lib.createPlaylist('p');
      for (final path in ['/a.mp3', '/b.mp3', '/c.mp3', '/d.mp3']) {
        await lib.addToPlaylist('p', path);
      }
      return lib;
    }

    test('見えている曲を動かしても、見えていない曲は消えない', () async {
      final lib = await withGap();
      // 画面上は [a, c, d]。a を末尾へ動かす。
      await lib.reorderPlaylist('p', 0, 2, ['/a.mp3', '/c.mp3', '/d.mp3']);

      final paths = lib.playlists.single.paths;
      expect(paths.contains('/b.mp3'), isTrue, reason: '欠けている曲を落としてはいけない');
      expect(paths.length, 4);
      expect(paths.indexOf('/a.mp3'), greaterThan(paths.indexOf('/d.mp3')));
    });

    test('動かす先が正しい。c を先頭へ', () async {
      final lib = await withGap();
      await lib.reorderPlaylist('p', 1, 0, ['/a.mp3', '/c.mp3', '/d.mp3']);

      final paths = lib.playlists.single.paths;
      expect(paths.indexOf('/c.mp3'), lessThan(paths.indexOf('/a.mp3')));
      expect(paths.length, 4);
    });

    test('同じ位置なら何も起きない', () async {
      final lib = await withGap();
      final before = [...lib.playlists.single.paths];
      await lib.reorderPlaylist('p', 1, 1, ['/a.mp3', '/c.mp3', '/d.mp3']);
      expect(lib.playlists.single.paths, before);
    });
  });

  group('プレイリストの作成', () {
    test('同じ名前は二重に作らない', () async {
      final lib = LibraryModel();
      await lib.createPlaylist('通学中');
      await lib.createPlaylist('通学中');
      expect(lib.playlists.length, 1);
    });

    test('空の名前は作らない', () async {
      final lib = LibraryModel();
      expect(await lib.createPlaylist('   '), isNull);
      expect(lib.playlists, isEmpty);
    });
  });
}
