import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../library_model.dart';
import '../models.dart';
import '../settings_model.dart';
import '../widgets.dart';

/// このアプリの中心。上のプレビューが下のつまみに合わせて即座に変わる。
class ThemeLabScreen extends StatelessWidget {
  const ThemeLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const _PreviewCard(),
          const SizedBox(height: 28),

          _SectionTitle('背景'),
          SegmentedButton<SurfaceMode>(
            segments: const [
              ButtonSegment(value: SurfaceMode.light, label: Text('ライト')),
              ButtonSegment(value: SurfaceMode.dark, label: Text('ダーク')),
              ButtonSegment(value: SurfaceMode.amoled, label: Text('真っ黒')),
            ],
            selected: {s.surface},
            onSelectionChanged: (v) => s.surface = v.first,
          ),
          const SizedBox(height: 8),
          if (s.surface == SurfaceMode.amoled)
            Text('有機ELの画面では真っ黒の部分が消灯するので、電池が長持ちします。',
                style: Theme.of(context).textTheme.bodySmall),

          const SizedBox(height: 24),
          _SectionTitle('アクセント色'),
          SwitchListTile(
            value: s.accentFromArt,
            onChanged: (v) => s.accentFromArt = v,
            title: const Text('アルバムアートから色を取る'),
            subtitle: const Text('曲が変わるたびにジャケットの色に合わせます'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: s.accentFromArt ? 0.4 : 1,
            child: IgnorePointer(
              ignoring: s.accentFromArt,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: SettingsModel.presetAccents.entries.map((e) {
                  final selected = s.accent.toARGB32() == e.value.toARGB32();
                  return GestureDetector(
                    onTap: () => s.accent = e.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: e.value,
                            borderRadius: BorderRadius.circular(s.radius * 0.8),
                            border: selected
                                ? Border.all(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    width: 2.5)
                                : null,
                          ),
                          child: selected
                              ? Icon(Icons.check_rounded,
                                  size: 20, color: _onColor(e.value))
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(e.key, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 24),
          _SectionTitle('形と間隔'),
          _SliderRow(
            label: '角の丸み',
            value: s.radius,
            min: 0,
            max: 28,
            display: '${s.radius.round()}',
            onChanged: (v) => s.radius = v,
          ),
          _SliderRow(
            label: '行の高さ',
            value: s.density,
            min: 0.85,
            max: 1.2,
            display: s.density < 0.95
                ? '詰める'
                : (s.density > 1.08 ? 'ゆったり' : 'ふつう'),
            onChanged: (v) => s.density = v,
          ),
          _SliderRow(
            label: '文字の大きさ',
            value: s.textScale,
            min: 0.85,
            max: 1.3,
            display: '${(s.textScale * 100).round()}%',
            onChanged: (v) => s.textScale = v,
          ),
          SwitchListTile(
            value: s.showArtInList,
            onChanged: (v) => s.showArtInList = v,
            title: const Text('一覧にジャケットを出す'),
            subtitle: const Text('切ると1画面に入る曲数が増えます'),
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: s.resetToDefaults,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('見た目を初期状態に戻す'),
          ),

          const SizedBox(height: 36),
          const Divider(),
          const SizedBox(height: 20),
          _SectionTitle('音楽フォルダ'),
          const _FolderSection(),
        ],
      ),
    );
  }

  static Color _onColor(Color c) =>
      c.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

/// つまみを動かした結果がその場で見えるように、実物と同じ部品で組む。
class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsModel>();
    final scheme = Theme.of(context).colorScheme;

    const sample = Song(
      path: '/preview',
      title: 'プレビュー用の曲',
      artist: 'サンプル',
      album: 'テーマ工房',
      duration: Duration(minutes: 3, seconds: 42),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(s.radius),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Artwork(song: sample, size: 52 * s.density, radius: s.radius * 0.6),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sample.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15 * s.textScale,
                        )),
                    Text('${sample.artist} · ${sample.album}',
                        style: TextStyle(fontSize: 12 * s.textScale)),
                  ],
                ),
              ),
              Text(formatDuration(sample.duration),
                  style: TextStyle(fontSize: 12 * s.textScale)),
            ],
          ),
          const SizedBox(height: 14),
          Slider(value: 0.42, onChanged: (_) {}),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shuffle_rounded, size: 20),
              const SizedBox(width: 20),
              const Icon(Icons.skip_previous_rounded, size: 28),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(s.radius + 4),
                ),
                child: Icon(Icons.play_arrow_rounded,
                    size: 28, color: scheme.onPrimary),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.skip_next_rounded, size: 28),
              const SizedBox(width: 20),
              const Icon(Icons.repeat_rounded, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}

class _FolderSection extends StatelessWidget {
  const _FolderSection();

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('これらの場所を自動で見ています:',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        ...LibraryModel.defaultFolders.map(
          (f) => Text('・$f', style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(height: 16),
        if (library.folders.isEmpty)
          Text('追加したフォルダはありません。',
              style: Theme.of(context).textTheme.bodyMedium)
        else
          ...library.folders.map(
            (f) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_rounded),
              title: Text(f, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded),
                tooltip: 'このフォルダを外す',
                onPressed: () => library.removeFolder(f),
              ),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final granted = await library.requestPermission();
            if (!granted) return;
            final path = await FilePicker.getDirectoryPath();
            if (path == null) return;
            await library.addFolder(path);
            await library.scan();
          },
          icon: const Icon(Icons.create_new_folder_rounded),
          label: const Text('フォルダを追加'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final String display;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.display,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(display, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
