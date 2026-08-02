import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_controller.dart';
import '../services/settings_controller.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final library = context.read<LibraryController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          _sectionLabel(context, '見た目'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('端末に合わせる'),
                  icon: Icon(Icons.brightness_auto_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('ライト'),
                  icon: Icon(Icons.light_mode_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('ダーク'),
                  icon: Icon(Icons.dark_mode_rounded),
                ),
              ],
              selected: {settings.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
          ),
          SwitchListTile(
            value: settings.followArtwork,
            onChanged: settings.setFollowArtwork,
            title: const Text('ジャケットの色をアプリに反映する'),
            subtitle: const Text('再生中の曲に合わせて画面全体の色が変わります'),
          ),
          SwitchListTile(
            value: settings.amoled,
            onChanged: settings.setAmoled,
            title: const Text('背景を真っ黒にする'),
            subtitle: const Text('有機ELの画面で電池の減りを抑えられます'),
          ),
          SwitchListTile(
            value: settings.albumsAsGrid,
            onChanged: settings.setAlbumsAsGrid,
            title: const Text('アルバムをタイル表示にする'),
          ),
          _sectionLabel(context, 'テーマ色'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              settings.followArtwork
                  ? 'ジャケットから色が取れない曲のときに使います。'
                  : 'アプリ全体の基準になる色です。',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
            ),
          ),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: kSeedChoices.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final choice = kSeedChoices[i];
                final selected = settings.seedIndex == i;
                return GestureDetector(
                  onTap: () => settings.setSeedIndex(i),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: choice.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? scheme.onSurface : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(choice.name, style: const TextStyle(fontSize: 11.5)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          _sectionLabel(context, 'ライブラリ'),
          ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: const Text('曲を読み込み直す'),
            subtitle: const Text('端末に音楽を追加したあとに使ってください'),
            onTap: () async {
              await library.load();
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text('${library.songs.length}曲を読み込みました')),
                  );
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}
