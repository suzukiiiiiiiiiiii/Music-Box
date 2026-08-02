import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../widgets/song_actions.dart';
import '../widgets/song_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Song> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryService>();
    final player = context.read<PlayerService>();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '曲名・アーティスト・アルバム',
            border: InputBorder.none,
          ),
          onChanged: (value) =>
              setState(() => _results = library.search(value)),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _controller.clear();
                _results = const [];
              }),
            ),
        ],
      ),
      body: _controller.text.isEmpty
          ? const EmptyHint(icon: Icons.search, text: '探したい言葉を入れてください')
          : _results.isEmpty
              ? const EmptyHint(icon: Icons.search_off, text: '見つかりませんでした')
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, i) => SongTile(
                    song: _results[i],
                    onTap: () => player.playAll(_results, startIndex: i),
                  ),
                ),
    );
  }
}
