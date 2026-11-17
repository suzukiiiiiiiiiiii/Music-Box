import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../actions.dart';
import '../library_model.dart';
import 'equalizer_screen.dart';

/// 音楽の取り込みに関する設定。見た目の設定はテーマの面にあるので、
/// ここはフォルダとスキャンだけに絞ってある。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('音楽フォルダ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (library.scanning) ...[
            LinearProgressIndicator(
              value: library.scanTotal == 0
                  ? null
                  : library.scanned / library.scanTotal,
              minHeight: 3,
            ),
            const SizedBox(height: 8),
            Text(
              library.scanTotal == 0
                  ? 'フォルダを見ています'
                  : '${library.scanned} / ${library.scanTotal} 曲を読み込み中',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
          ],
          Text('${library.songs.length} 曲が入っています',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: library.scanning ? null : () => rescanLibrary(context),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('もう一度スキャンする'),
          ),
          if (library.lastError != null) ...[
            const SizedBox(height: 12),
            Text('前回のスキャンで問題が出ました: ${library.lastError}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 28),
          const _SectionTitle('いつも見ている場所'),
          ...LibraryModel.defaultFolders.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('・$f', style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('追加したフォルダ'),
          if (library.folders.isEmpty)
            Text('まだありません。',
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
            onPressed: () => pickFolderAndScan(context),
            icon: const Icon(Icons.create_new_folder_rounded),
            label: const Text('フォルダを追加'),
          ),
          const SizedBox(height: 36),
          const Divider(),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.graphic_eq_rounded),
            title: const Text('イコライザー'),
            subtitle: const Text('プリセットとバンドごとの調整'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EqualizerScreen()),
            ),
          ),
        ],
      ),
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
