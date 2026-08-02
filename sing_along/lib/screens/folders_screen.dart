import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../services/player_service.dart';
import '../widgets/song_actions.dart';
import '../widgets/song_tile.dart';

/// 端末のフォルダをそのまま辿る画面。
///
/// 曲の一覧は取り込み済みの索引から出す。索引に無い音楽ファイルが入って
/// いるフォルダでは「このフォルダを取り込む」を出して、探す場所に足せる。
class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  String _path = LibraryService.storageRoot;

  List<Directory> _subdirectories = [];
  bool _unreadable = false;

  /// 索引にはまだ入っていない音楽ファイルの数。
  int _unindexed = 0;

  @override
  void initState() {
    super.initState();
    _open(_path);
  }

  void _open(String path) {
    final dir = Directory(path);
    var unreadable = false;
    final dirs = <Directory>[];
    final files = <String>[];

    try {
      for (final entity in dir.listSync(followLinks: false)) {
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;
        if (entity is Directory) {
          dirs.add(entity);
        } else if (entity is File &&
            audioExtensions.contains(p.extension(entity.path).toLowerCase())) {
          files.add(entity.path);
        }
      }
      dirs.sort((a, b) => p.basename(a.path).toLowerCase().compareTo(
            p.basename(b.path).toLowerCase(),
          ));
    } catch (_) {
      unreadable = true;
    }

    final library = context.read<LibraryService>();
    final indexed = library.songsInFolder(path).map((s) => s.path).toSet();

    setState(() {
      _path = path;
      _subdirectories = dirs;
      _unreadable = unreadable;
      _unindexed = files.where((f) => !indexed.contains(f)).length;
    });
  }

  bool get _atRoot => _path == LibraryService.storageRoot;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final player = context.read<PlayerService>();
    final songs = library.songsInFolder(_path);

    return Column(
      children: [
        _Breadcrumb(
          path: _path,
          onUp: _atRoot ? null : () => _open(p.dirname(_path)),
          onHome: _atRoot ? null : () => _open(LibraryService.storageRoot),
        ),
        if (_unindexed > 0)
          Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.download_outlined),
              title: Text('取り込んでいない曲が$_unindexed件あります'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await library.addRoot(_path);
                await library.scan();
                if (mounted) _open(_path);
              },
            ),
          ),
        Expanded(
          child: _unreadable
              ? const EmptyHint(
                  icon: Icons.folder_off_outlined,
                  text: 'このフォルダは読めませんでした',
                )
              : ListView(
                  children: [
                    for (final dir in _subdirectories)
                      ListTile(
                        leading: const Icon(Icons.folder),
                        title: Text(
                          p.basename(dir.path),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _open(dir.path),
                        onLongPress: () {
                          final under = library.songsUnderFolder(dir.path);
                          if (under.isEmpty) return;
                          showCollectionActions(
                            context,
                            title: p.basename(dir.path),
                            songs: under,
                          );
                        },
                      ),
                    if (songs.isNotEmpty) ...[
                      const Divider(),
                      for (var i = 0; i < songs.length; i++)
                        SongTile(
                          song: songs[i],
                          onTap: () => player.playAll(songs, startIndex: i),
                        ),
                    ],
                    if (_subdirectories.isEmpty && songs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('このフォルダには何もありません')),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.path, this.onUp, this.onHome});

  final String path;
  final VoidCallback? onUp;
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // /storage/emulated/0/Music → 内部ストレージ/Music と読ませる
    final shown = path == LibraryService.storageRoot
        ? '内部ストレージ'
        : '内部ストレージ${path.substring(LibraryService.storageRoot.length)}';

    return Material(
      color: scheme.surfaceContainerHighest,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: '一つ上へ',
            onPressed: onUp,
          ),
          Expanded(
            child: Text(
              shown,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: '先頭へ',
            onPressed: onHome,
          ),
        ],
      ),
    );
  }
}
