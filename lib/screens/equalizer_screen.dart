import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../player_model.dart';
import '../widgets.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  EqualizerController? _controller;

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final player = context.read<PlayerModel>();
    final controller = EqualizerController(player.equalizer);
    controller.addListener(_onControllerChanged);
    _controller = controller;
    controller.init();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('イコライザー')),
      body: Builder(
        builder: (context) {
          if (controller == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final params = controller.params;
          if (params == null) {
            return EmptyState(
              icon: Icons.graphic_eq_rounded,
              title: 'まだ調整できません',
              body: controller.error ??
                  'イコライザーは再生エンジンが動き出してから使えます。',
              actionLabel: 'もう一度試す',
              onAction: controller.init,
            );
          }

          final bands = params.bands;
          final min = params.minDecibels;
          final max = params.maxDecibels;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              SwitchListTile(
                value: controller.enabled,
                onChanged: controller.setEnabled,
                title: const Text('イコライザーを使う'),
                subtitle: const Text('切ると元の音のまま再生します'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              Text('プリセット', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: EqualizerController.presets.keys.map((name) {
                  return ActionChip(
                    label: Text(name),
                    onPressed: () => controller.applyPreset(name),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text('バンドごとの調整',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text('${min.round()} dB 〜 ${max.round()} dB',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: Row(
                  children: List.generate(bands.length, (i) {
                    final band = bands[i];
                    return Expanded(
                      child: Column(
                        children: [
                          Text(
                            band.gain.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: band.gain.abs() < 0.05
                                      ? null
                                      : scheme.primary,
                                ),
                          ),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Slider(
                                min: min,
                                max: max,
                                value: band.gain.clamp(min, max),
                                onChanged: controller.enabled
                                    ? (v) => controller.setGain(i, v)
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatHz(band.centerFrequency),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => controller.applyPreset('フラット'),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('すべて 0 dB に戻す'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatHz(double hz) {
    if (hz >= 1000) return '${(hz / 1000).toStringAsFixed(hz % 1000 == 0 ? 0 : 1)}k';
    return hz.round().toString();
  }
}
