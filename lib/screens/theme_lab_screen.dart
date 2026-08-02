import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models.dart';
import '../settings_model.dart';
import '../widgets.dart';

/// このアプリの中心。プレビューは画面の上に貼り付いたままで、下のつまみを
/// どれだけ動かしても視界から消えない。
class ThemeLabScreen extends StatelessWidget {
  const ThemeLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('テーマ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: '見た目を初期状態に戻す',
            onPressed: s.resetToDefaults,
          ),
        ],
      ),
      body: Column(
        children: [
          // ここが貼り付く部分。スクロールしても動かない。
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: const _PreviewCard(),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                const _SectionTitle('背景'),
                SegmentedButton<SurfaceMode>(
                  segments: [
                    for (final m in SurfaceMode.values)
                      ButtonSegment(value: m, label: Text(m.label)),
                  ],
                  selected: {s.surface},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => s.surface = v.first,
                ),
                if (s.surface == SurfaceMode.amoled) ...[
                  const SizedBox(height: 8),
                  Text('有機ELの画面では真っ黒の部分が消灯するので、電池が長持ちします。',
                      style: Theme.of(context).textTheme.bodySmall),
                ],

                const SizedBox(height: 28),
                const _SectionTitle('アクセント色'),
                SwitchListTile(
                  value: s.accentFromArt,
                  onChanged: (v) => s.accentFromArt = v,
                  title: const Text('アルバムアートから色を取る'),
                  subtitle: const Text('曲が変わるたびにジャケットの色に合わせます'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 4),
                Opacity(
                  opacity: s.accentFromArt ? 0.4 : 1,
                  child: IgnorePointer(
                    ignoring: s.accentFromArt,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _AccentSwatches(),
                        const SizedBox(height: 16),
                        const _CustomAccentPicker(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),
                const _SectionTitle('形と間隔'),
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

                const SizedBox(height: 20),
                const _SectionTitle('ジャケット'),
                SegmentedButton<ArtworkShape>(
                  segments: [
                    for (final shape in ArtworkShape.values)
                      ButtonSegment(value: shape, label: Text(shape.label)),
                  ],
                  selected: {s.artworkShape},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => s.artworkShape = v.first,
                ),
                SwitchListTile(
                  value: s.showArtInList,
                  onChanged: (v) => s.showArtInList = v,
                  title: const Text('一覧にジャケットを出す'),
                  subtitle: const Text('切ると1画面に入る曲数が増えます'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: s.albumGrid,
                  onChanged: (v) => s.albumGrid = v,
                  title: const Text('アルバムをタイルで並べる'),
                  subtitle: const Text('切ると1行ずつの表示になります'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 実物と同じ部品で組んだプレビュー。つまみの結果がここに即座に出る。
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
              if (s.showArtInList) ...[
                Artwork(song: sample, size: 52 * s.density),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sample.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15 * s.textScale,
                        )),
                    Text('${sample.artist} · ${sample.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12 * s.textScale)),
                  ],
                ),
              ),
              Text(formatDuration(sample.duration),
                  style: TextStyle(fontSize: 12 * s.textScale)),
            ],
          ),
          const SizedBox(height: 10),
          Slider(value: 0.42, onChanged: (_) {}),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shuffle_rounded, size: 20),
              const SizedBox(width: 20),
              const Icon(Icons.skip_previous_rounded, size: 26),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(s.radius + 4),
                ),
                child: Icon(Icons.play_arrow_rounded,
                    size: 26, color: scheme.onPrimary),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.skip_next_rounded, size: 26),
              const SizedBox(width: 20),
              const Icon(Icons.repeat_rounded, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccentSwatches extends StatelessWidget {
  const _AccentSwatches();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsModel>();
    return Wrap(
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
                        size: 20, color: readableOn(e.value))
                    : null,
              ),
              const SizedBox(height: 4),
              Text(e.key, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// プリセットに無い色を自分で作る。色相・鮮やかさ・明るさの3本。
class _CustomAccentPicker extends StatelessWidget {
  const _CustomAccentPicker();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsModel>();
    final hsl = HSLColor.fromColor(s.accent);

    void apply({double? h, double? sat, double? l}) {
      s.accent = HSLColor.fromAHSL(
        1,
        h ?? hsl.hue,
        sat ?? hsl.saturation,
        l ?? hsl.lightness,
      ).toColor();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('自分で作る', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            if (s.accentIsCustom)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: s.accent,
                  borderRadius: BorderRadius.circular(s.radius * 0.5),
                ),
              ),
          ],
        ),
        _SliderRow(
          label: '色あい',
          value: hsl.hue,
          min: 0,
          max: 360,
          display: '${hsl.hue.round()}°',
          onChanged: (v) => apply(h: v),
        ),
        _SliderRow(
          label: '鮮やかさ',
          value: hsl.saturation,
          min: 0,
          max: 1,
          display: '${(hsl.saturation * 100).round()}%',
          onChanged: (v) => apply(sat: v),
        ),
        _SliderRow(
          label: '明るさ',
          value: hsl.lightness,
          min: 0.15,
          max: 0.85,
          display: '${(hsl.lightness * 100).round()}%',
          onChanged: (v) => apply(l: v),
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
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
