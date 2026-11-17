import 'package:flutter/material.dart';

import '../widgets.dart';
import 'library_screen.dart';
import 'playlist_screen.dart';
import 'theme_lab_screen.dart';

/// アプリの骨組み。下のバーで3つの面を切り替え、その上にミニプレイヤーを
/// 常駐させる。ミニプレイヤーは bottomNavigationBar 側に置いてあるので、
/// 一覧の最後の行やボタンと重なることがない。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.library_music_outlined),
      selectedIcon: Icon(Icons.library_music_rounded),
      label: 'ライブラリ',
    ),
    NavigationDestination(
      icon: Icon(Icons.queue_music_outlined),
      selectedIcon: Icon(Icons.queue_music_rounded),
      label: 'プレイリスト',
    ),
    NavigationDestination(
      icon: Icon(Icons.palette_outlined),
      selectedIcon: Icon(Icons.palette_rounded),
      label: 'テーマ',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          LibraryScreen(),
          PlaylistsScreen(),
          ThemeLabScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: _destinations,
          ),
        ],
      ),
    );
  }
}
