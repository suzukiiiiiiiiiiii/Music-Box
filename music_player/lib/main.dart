import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/artwork_theme_controller.dart';
import 'services/library_controller.dart';
import 'services/player_controller.dart';
import 'services/playlist_controller.dart';
import 'services/settings_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // バックグラウンド再生と通知バーの操作を有効にする
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.music_player.audio',
    androidNotificationChannelName: '音楽の再生',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );

  final settings = SettingsController();
  final playlists = PlaylistController();
  await Future.wait([settings.load(), playlists.load()]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: playlists),
        ChangeNotifierProvider(create: (_) => LibraryController()..load()),
        ChangeNotifierProvider(create: (_) => PlayerController()),
        ChangeNotifierProvider(create: (_) => ArtworkThemeController()),
      ],
      child: const MusicPlayerApp(),
    ),
  );
}

class MusicPlayerApp extends StatefulWidget {
  const MusicPlayerApp({super.key});

  @override
  State<MusicPlayerApp> createState() => _MusicPlayerAppState();
}

class _MusicPlayerAppState extends State<MusicPlayerApp> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final artTheme = context.watch<ArtworkThemeController>();
    final player = context.watch<PlayerController>();

    // 曲が変わったらジャケットから配色を作り直す
    final albumId = player.currentSong?.albumId;
    if (settings.followArtwork) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        artTheme.updateFor(albumId);
      });
    }

    final useArt = settings.followArtwork;
    final lightScheme = (useArt ? artTheme.light : null) ??
        ColorScheme.fromSeed(seedColor: settings.seedColor);
    final darkScheme = (useArt ? artTheme.dark : null) ??
        ColorScheme.fromSeed(
          seedColor: settings.seedColor,
          brightness: Brightness.dark,
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: MaterialApp(
        title: 'Music Player',
        debugShowCheckedModeBanner: false,
        themeMode: settings.themeMode,
        theme: AppTheme.light(lightScheme),
        darkTheme: AppTheme.dark(darkScheme, amoled: settings.amoled),
        // 曲ごとの色移りを滑らかに見せる
        themeAnimationDuration: const Duration(milliseconds: 600),
        themeAnimationCurve: Curves.easeOutCubic,
        home: const HomeScreen(),
      ),
    );
  }
}
