import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_controller.dart';
import '../widgets/mini_player.dart';
import 'albums_tab.dart';
import 'artists_tab.dart';
import 'playlists_tab.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'songs_tab.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ライブラリ'),
          actions: [
            IconButton(
              tooltip: '曲を探す',
              icon: const Icon(Icons.search_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
            IconButton(
              tooltip: '設定',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
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
            Expanded(child: _body(context, library)),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, LibraryController library) {
    switch (library.state) {
      case LibraryState.loading:
        return const Center(child: CircularProgressIndicator());

      case LibraryState.noPermission:
        return _Notice(
          icon: Icons.folder_off_rounded,
          title: '音楽ファイルを読み取れません',
          body: '端末内の曲を一覧にするには、音楽とオーディオへのアクセスを許可してください。',
          actionLabel: '権限を許可する',
          onAction: () async {
            await library.load();
            if (library.state == LibraryState.noPermission) {
              await library.openSettings();
            }
          },
        );

      case LibraryState.empty:
        return _Notice(
          icon: Icons.library_music_outlined,
          title: '再生できる曲が見つかりません',
          body: '端末に音楽ファイルを入れてから、もう一度読み込んでください。',
          actionLabel: 'もう一度読み込む',
          onAction: library.load,
        );

      case LibraryState.ready:
        return const TabBarView(
          children: [SongsTab(), AlbumsTab(), ArtistsTab(), PlaylistsTab()],
        );
    }
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
