import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../library_model.dart';
import '../models.dart';
import '../player_model.dart';
import '../widgets.dart';
import 'equalizer_screen.dart';
import 'playlist_screen.dart';
import 'theme_lab_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  final _searchController = TextEditingController();
  String _query = '';
  bool _searching = false;

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final library = context.read<LibraryModel>();
    final granted = await library.requestPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('音楽ファイルの読み取りが許可されていません。設定から許可してください。')),
      );
      return;
    }
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return;
    await library.addFolder(path);
    await library.scan();
  }

  Future<void> _rescan() async {
    final library = context.read<LibraryModel>();
    final granted = await library.requestPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('音楽ファイルの読み取りが許可されていません。設定から許可してください。')),
      );
      return;
    }
    await library.scan();
  }

  void _play(List<Song> songs, int index, String label) {
    context.read<PlayerModel>().playQueue(songs, index, label: label);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '曲名、アーティスト、アルバムで探す',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('Music Box'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _searching ? '検索をやめる' : '曲を探す',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _searchController.clear();
                _query = '';
              }
            }),
          ),
          IconButton(
            icon: const Icon(Icons.graphic_eq_rounded),
            tooltip: 'イコライザー',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EqualizerScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: '設定',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ThemeLabScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '曲'),
            Tab(text: 'アルバム'),
            Tab(text: 'アーティスト'),
            Tab(text: 'プレイリスト'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (library.scanning) _ScanBar(library: library),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _SongsTab(query: _query, onPlay: _play, onPickFolder: _pickFolder),
                _GroupTab(
                  groupKey: (s) => s.album,
                  emptyIcon: Icons.album_rounded,
                  onPlay: _play,
                ),
                _GroupTab(
                  groupKey: (s) => s.artist,
                  emptyIcon: Icons.person_rounded,
                  onPlay: _play,
                ),
                const PlaylistsTab(),
              ],
            ),
          ),
          const MiniPlayer(),
        ],
      ),
      floatingActionButton: library.scanning
          ? null
          : FloatingActionButton.extended(
              onPressed: _rescan,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('スキャン'),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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

class _SongsTab extends StatelessWidget {
  final String query;
  final void Function(List<Song>, int, String) onPlay;
  final VoidCallback onPickFolder;

  const _SongsTab({
    required this.query,
    required this.onPlay,
    required this.onPickFolder,
  });

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();
    final player = context.watch<PlayerModel>();
    final songs = library.search(query);

    if (library.songs.isEmpty && !library.scanning) {
      return EmptyState(
        icon: Icons.library_music_rounded,
        title: 'まだ曲がありません',
        body: '音楽が入っているフォルダを選ぶと、\nタグを読んで一覧に並べます。',
        actionLabel: 'フォルダを選ぶ',
        onAction: onPickFolder,
      );
    }

    if (songs.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: '一致する曲がありません',
        body: '別の言葉で探してみてください。',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 90),
      itemCount: songs.length,
      itemBuilder: (context, i) {
        final song = songs[i];
        return SongTile(
          song: song,
          active: player.current?.path == song.path,
          onTap: () => onPlay(songs, i, query.isEmpty ? 'すべての曲' : '検索結果'),
          onMore: () => showSongMenu(context, song),
        );
      },
    );
  }
}

/// アルバム / アーティストの一覧。開くと中の曲が出る。
class _GroupTab extends StatelessWidget {
  final String Function(Song) groupKey;
  final IconData emptyIcon;
  final void Function(List<Song>, int, String) onPlay;

  const _GroupTab({
    required this.groupKey,
    required this.emptyIcon,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();
    final groups = library.groupBy(groupKey);
    final keys = groups.keys.toList()..sort();

    if (keys.isEmpty) {
      return EmptyState(
        icon: emptyIcon,
        title: 'まだ何もありません',
        body: '曲を読み込むとここにまとまります。',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 90),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final key = keys[i];
        final songs = groups[key]!;
        return ListTile(
          leading: Artwork(song: songs.first, size: 46),
          title: Text(key, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${songs.length} 曲'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _GroupDetailScreen(title: key, songs: songs, onPlay: onPlay),
            ),
          ),
        );
      },
    );
  }
}

class _GroupDetailScreen extends StatelessWidget {
  final String title;
  final List<Song> songs;
  final void Function(List<Song>, int, String) onPlay;

  const _GroupDetailScreen({
    required this.title,
    required this.songs,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerModel>();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: () => onPlay(songs, 0, title),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('再生'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    final shuffled = [...songs]..shuffle();
                    onPlay(shuffled, 0, title);
                  },
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('シャッフル'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 90),
              itemCount: songs.length,
              itemBuilder: (context, i) => SongTile(
                song: songs[i],
                active: player.current?.path == songs[i].path,
                onTap: () => onPlay(songs, i, title),
                onMore: () => showSongMenu(context, songs[i]),
              ),
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}

/// 曲の「…」から出すシート。プレイリストへの追加はここから。
void showSongMenu(BuildContext context, Song song) {
  final library = context.read<LibraryModel>();
  showModalBottomSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Artwork(song: song, size: 44),
            title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Divider(),
          if (library.playlists.isEmpty)
            const ListTile(
              leading: Icon(Icons.playlist_add_rounded),
              title: Text('プレイリストがまだありません'),
              subtitle: Text('プレイリストのタブで作れます'),
            )
          else
            ...library.playlists.map(
              (pl) => ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: Text('「${pl.name}」に追加'),
                onTap: () async {
                  await library.addToPlaylist(pl.name, song.path);
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
              ),
            ),
        ],
      ),
    ),
  );
}
