import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../actions.dart';
import '../library_model.dart';
import '../models.dart';
import '../player_model.dart';
import '../settings_model.dart';
import '../widgets.dart';
import 'settings_screen.dart';

enum _View { songs, albums, artists }

/// 曲・アルバム・アーティストをひとつの面にまとめる。検索欄は常に見えていて、
/// 3つのどの表示にも同じ絞り込みが掛かる。
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _View _view = _View.songs;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _play(List<Song> songs, int index, String label) {
    context.read<PlayerModel>().playQueue(songs, index, label: label);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();
    final settings = context.watch<SettingsModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ライブラリ'),
        actions: [
          if (_view == _View.songs)
            PopupMenuButton<SongSort>(
              icon: const Icon(Icons.swap_vert_rounded),
              tooltip: '並べ替え',
              initialValue: settings.songSort,
              onSelected: (v) => settings.songSort = v,
              itemBuilder: (context) => [
                for (final s in SongSort.values)
                  PopupMenuItem(value: s, child: Text(s.label)),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.folder_open_rounded),
            tooltip: '音楽フォルダとスキャン',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '曲名、アーティスト、アルバムで探す',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: '検索をやめる',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                          FocusScope.of(context).unfocus();
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_View>(
                segments: const [
                  ButtonSegment(value: _View.songs, label: Text('曲')),
                  ButtonSegment(value: _View.albums, label: Text('アルバム')),
                  ButtonSegment(value: _View.artists, label: Text('アーティスト')),
                ],
                selected: {_view},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _view = v.first),
              ),
            ),
          ),
          if (library.scanning) _ScanBar(library: library),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => rescanLibrary(context),
              child: _buildBody(library, settings),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(LibraryModel library, SettingsModel settings) {
    if (library.songs.isEmpty) {
      return _ScrollableEmpty(
        child: EmptyState(
          icon: Icons.library_music_rounded,
          title: library.scanning ? '探しています' : 'まだ曲がありません',
          body: library.scanning
              ? '端末の中を見ています。少し待ってください。'
              : '音楽が入っているフォルダを選ぶと、\nタグを読んで一覧に並べます。',
          actionLabel: library.scanning ? null : 'フォルダを選ぶ',
          onAction:
              library.scanning ? null : () => pickFolderAndScan(context),
        ),
      );
    }

    switch (_view) {
      case _View.songs:
        final songs = library.view(query: _query, sort: settings.songSort);
        if (songs.isEmpty) return const _NoMatch();
        return _SongList(songs: songs, query: _query, onPlay: _play);

      case _View.albums:
        return _GroupView(
          groups: library.groups((s) => s.album, query: _query),
          grid: settings.albumGrid,
          countLabel: (n) => '$n 曲',
          onPlay: _play,
        );

      case _View.artists:
        return _GroupView(
          groups: library.groups((s) => s.artist, query: _query),
          grid: settings.albumGrid,
          countLabel: (n) => '$n 曲',
          onPlay: _play,
        );
    }
  }
}

/// RefreshIndicator は必ずスクロールできる子を要る。
class _ScrollableEmpty extends StatelessWidget {
  final Widget child;
  const _ScrollableEmpty({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: child,
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch();

  @override
  Widget build(BuildContext context) {
    return const _ScrollableEmpty(
      child: EmptyState(
        icon: Icons.search_off_rounded,
        title: '一致するものがありません',
        body: '別の言葉で探してみてください。',
      ),
    );
  }
}

class _ScanBar extends StatelessWidget {
  final LibraryModel library;
  const _ScanBar({required this.library});

  @override
  Widget build(BuildContext context) {
    final total = library.scanTotal;
    final done = library.scanned;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(total == 0 ? 'フォルダを見ています' : '$done / $total 曲を読み込み中',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: total == 0 ? null : done / total,
            minHeight: 3,
          ),
        ],
      ),
    );
  }
}

class _SongList extends StatelessWidget {
  final List<Song> songs;
  final String query;
  final void Function(List<Song>, int, String) onPlay;

  const _SongList({
    required this.songs,
    required this.query,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerModel>();
    final label = query.isEmpty ? 'すべての曲' : '「$query」の検索結果';

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      itemCount: songs.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return _ShuffleAllBar(songs: songs, onPlay: onPlay, label: label);
        final song = songs[i - 1];
        return SongTile(
          song: song,
          active: player.current?.path == song.path,
          onTap: () => onPlay(songs, i - 1, label),
          onMore: () => showSongMenu(context, song),
        );
      },
    );
  }
}

class _ShuffleAllBar extends StatelessWidget {
  final List<Song> songs;
  final String label;
  final void Function(List<Song>, int, String) onPlay;

  const _ShuffleAllBar({
    required this.songs,
    required this.label,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text('${songs.length} 曲',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          TextButton.icon(
            onPressed: () => onPlay([...songs]..shuffle(), 0, label),
            icon: const Icon(Icons.shuffle_rounded, size: 18),
            label: const Text('シャッフル再生'),
          ),
        ],
      ),
    );
  }
}

/// アルバム / アーティストの一覧。テーマ設定でタイル表示と行表示を切り替える。
class _GroupView extends StatelessWidget {
  final Map<String, List<Song>> groups;
  final bool grid;
  final String Function(int) countLabel;
  final void Function(List<Song>, int, String) onPlay;

  const _GroupView({
    required this.groups,
    required this.grid,
    required this.countLabel,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final keys = groups.keys.toList()..sort();
    if (keys.isEmpty) return const _NoMatch();

    void open(String key) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupDetailScreen(
            title: key,
            songs: groups[key]!,
            onPlay: onPlay,
          ),
        ),
      );
    }

    if (!grid) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
        itemCount: keys.length,
        itemBuilder: (context, i) {
          final songs = groups[keys[i]]!;
          return ListTile(
            leading: Artwork(song: songs.first, size: 46),
            title: Text(keys[i], maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(countLabel(songs.length)),
            onTap: () => open(keys[i]),
          );
        },
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.76,
      ),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final songs = groups[keys[i]]!;
        return CoverCard(
          title: keys[i],
          subtitle: countLabel(songs.length),
          cover: songs.first,
          onTap: () => open(keys[i]),
        );
      },
    );
  }
}

/// アルバム/アーティストを開いた画面。
class GroupDetailScreen extends StatelessWidget {
  final String title;
  final List<Song> songs;
  final void Function(List<Song>, int, String) onPlay;

  const GroupDetailScreen({
    super.key,
    required this.title,
    required this.songs,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerModel>();
    final total = songs.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + (s.duration ?? Duration.zero),
    );

    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Artwork(song: songs.first, size: 88),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${songs.length} 曲',
                          style: Theme.of(context).textTheme.bodyMedium),
                      Text(formatDuration(total),
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () => onPlay(songs, 0, title),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('再生'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                onPlay([...songs]..shuffle(), 0, title),
                            icon: const Icon(Icons.shuffle_rounded),
                            label: const Text('シャッフル'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
              itemCount: songs.length,
              itemBuilder: (context, i) => SongTile(
                song: songs[i],
                active: player.current?.path == songs[i].path,
                onTap: () => onPlay(songs, i, title),
                onMore: () => showSongMenu(context, songs[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
