import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'library_model.dart';
import 'player_model.dart';
import 'screens/home_screen.dart';
import 'settings_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 通知バーとロック画面の操作を有効にする。runApp より前に必ず呼ぶ。
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.music_box.audio',
    androidNotificationChannelName: '再生中',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );

  final settings = SettingsModel();
  final library = LibraryModel();
  await Future.wait([settings.load(), library.load()]);

  runApp(MusicBoxApp(settings: settings, library: library));
}

class MusicBoxApp extends StatelessWidget {
  final SettingsModel settings;
  final LibraryModel library;

  const MusicBoxApp({super.key, required this.settings, required this.library});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider(create: (_) => PlayerModel()),
      ],
      child: const _ThemedApp(),
    );
  }
}

/// アルバムアートから色を取る設定のとき、曲が変わるたびに配色を作り直す。
class _ThemedApp extends StatefulWidget {
  const _ThemedApp();

  @override
  State<_ThemedApp> createState() => _ThemedAppState();
}

class _ThemedAppState extends State<_ThemedApp> {
  Color? _artAccent;
  String? _artSourcePath;

  void _clearArtAccent() {
    if (_artAccent == null && _artSourcePath == null) return;
    if (!mounted) return;
    setState(() {
      _artAccent = null;
      _artSourcePath = null;
    });
  }

  Future<void> _updateArtAccent(String? artPath, Brightness brightness) async {
    if (artPath == null) {
      _clearArtAccent();
      return;
    }
    if (artPath == _artSourcePath) return;

    try {
      final file = File(artPath);
      // ファイルが無いときは _artSourcePath を進めない。あとで出来たら読み直す。
      if (!file.existsSync()) return;
      _artSourcePath = artPath;
      final scheme = await ColorScheme.fromImageProvider(
        provider: FileImage(file),
        brightness: brightness,
      );
      if (mounted) setState(() => _artAccent = scheme.primary);
    } catch (_) {
      // 読めない画像は無視して、選ばれている色のままにする
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsModel>();
    final player = context.watch<PlayerModel>();

    if (settings.accentFromArt) {
      final brightness =
          settings.surface == SurfaceMode.light ? Brightness.light : Brightness.dark;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateArtAccent(player.current?.artPath, brightness);
      });
    } else if (_artAccent != null || _artSourcePath != null) {
      // 設定を切ったら、次に入れ直したときに取り直せるよう覚えた色を捨てる。
      WidgetsBinding.instance.addPostFrameCallback((_) => _clearArtAccent());
    }

    return MaterialApp(
      title: 'Music Box',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(settings, artAccent: _artAccent),
      home: const HomeScreen(),
    );
  }
}
