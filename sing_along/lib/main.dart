import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/library_service.dart';
import 'services/player_service.dart';
import 'services/playlist_service.dart';
import 'services/settings_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 通知バーとロック画面からの操作を有効にする
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.sing_along.audio',
    androidNotificationChannelName: '再生中の曲',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );

  final settings = SettingsService();
  final library = LibraryService();
  final playlists = PlaylistService();
  await Future.wait([settings.load(), library.load(), playlists.load()]);

  final player = PlayerService(library);
  await player.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider.value(value: playlists),
        ChangeNotifierProvider.value(value: player),
      ],
      child: const SingAlongApp(),
    ),
  );

  // 索引が空の初回はそのまま探しに行く。権限の確認はこの中で出る。
  // 画面はもう出ているので、終わるのは待たない。
  if (library.isEmpty) unawaited(library.scan());
}

class SingAlongApp extends StatelessWidget {
  const SingAlongApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return MaterialApp(
      title: 'Sing Along',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: buildTheme(settings.seedColor, Brightness.light),
      darkTheme: buildTheme(
        settings.seedColor,
        Brightness.dark,
        amoled: settings.amoled,
      ),
      home: const HomeScreen(),
    );
  }
}
