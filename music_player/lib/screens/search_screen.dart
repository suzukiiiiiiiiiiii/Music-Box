import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../services/library_controller.dart';
import '../services/player_controller.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<SongModel> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryController>();
    final player = context.read<PlayerController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '曲名・アーティスト・アルバム',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          onChanged: (q) => setState(() => _results = library.search(q)),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: '入力を消す',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _controller.clear();
                _results = const [];
              }),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _controller.text.isEmpty
                  ? Center(
                      child: Text(
                        '聴きたい曲を入力してください。',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            '「${_controller.text}」に合う曲はありません。',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (_, i) => SongTile(
                            song: _results[i],
                            onTap: () =>
                                player.playAll(_results, startIndex: i),
                          ),
                        ),
            ),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }
}
