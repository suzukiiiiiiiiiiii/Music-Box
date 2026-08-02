import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final library = context.watch<LibraryService>();

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const _SectionTitle('見た目'),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('背景'),
            subtitle: Text(_themeLabel(settings.themeMode)),
            onTap: () async {
              final chosen = await showModalBottomSheet<ThemeMode>(
                context: context,
                showDragHandle: true,
                builder: (sheetContext) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final mode in ThemeMode.values)
                        RadioListTile<ThemeMode>(
                          value: mode,
                          groupValue: settings.themeMode,
                          title: Text(_themeLabel(mode)),
                          onChanged: (v) => Navigator.pop(sheetContext, v),
                        ),
                    ],
                  ),
                ),
              );
              if (chosen != null) await settings.setThemeMode(chosen);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.contrast),
            title: const Text('真っ黒の背景'),
            subtitle: const Text('有機ELだと消灯するぶん引き締まって見えます'),
            value: settings.amoled,
            onChanged: settings.setAmoled,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < accentChoices.length; i++)
                  GestureDetector(
                    onTap: () => settings.setSeedIndex(i),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accentChoices[i].color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: 3,
                          color: i == settings.seedIndex
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          const _SectionTitle('再生画面'),
          SwitchListTile(
            secondary: const Icon(Icons.lyrics_outlined),
            title: const Text('歌詞の面から開く'),
            subtitle: const Text('再生画面を開いたとき、最初から歌詞を出します'),
            value: settings.openOnLyrics,
            onChanged: settings.setOpenOnLyrics,
          ),
          const Divider(),
          const _SectionTitle('取り込み'),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('もう一度探す'),
            subtitle: Text(
              library.scanning
                  ? '${library.scanned} / ${library.scanTotal}'
                  : '${library.songs.length}曲を取り込み済み',
            ),
            onTap: library.scanning ? null : library.scan,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '探す場所',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          for (final root in LibraryService.defaultRoots)
            ListTile(
              dense: true,
              leading: const Icon(Icons.folder_outlined, size: 20),
              title: Text(root, style: const TextStyle(fontSize: 12)),
              subtitle: const Text('いつも見る場所', style: TextStyle(fontSize: 11)),
            ),
          for (final root in library.roots)
            ListTile(
              dense: true,
              leading: const Icon(Icons.folder_special_outlined, size: 20),
              title: Text(root, style: const TextStyle(fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => library.removeRoot(root),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Text(
              'フォルダの画面から「取り込んでいない曲があります」を押すと、\nその場所をここに足せます。',
              style: TextStyle(fontSize: 11, height: 1.5),
            ),
          ),
          const Divider(),
          const _SectionTitle('歌詞について'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Text(
              '曲と同じ名前の .lrc ファイルが隣にあれば、それを時刻つきの歌詞として'
              '読みます。無ければ曲のタグに入っている歌詞を使います。\n\n'
              '時刻つきの歌詞は再生に合わせて流れ、行をタップするとその位置に飛びます。',
              style: TextStyle(fontSize: 12, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '端末に合わせる';
      case ThemeMode.light:
        return 'ライト';
      case ThemeMode.dark:
        return 'ダーク';
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}
