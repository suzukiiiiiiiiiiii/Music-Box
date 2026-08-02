import 'package:flutter/material.dart';

import '../models/lyrics.dart';

/// 歌詞の表示。
///
/// 時刻つきなら、いま歌っている行を大きく出して自動でついていく。
/// 行をタップするとその時刻に飛ぶ。指で動かしている間は自動追従を止めて、
/// しばらく触らなければまた追いかけ直す。
class LyricsView extends StatefulWidget {
  const LyricsView({
    super.key,
    required this.lyrics,
    required this.position,
    required this.onSeek,
  });

  final Lyrics lyrics;
  final Duration position;
  final ValueChanged<Duration> onSeek;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final _controller = ScrollController();

  /// 行の高さは可変なので、実測した位置を覚えて真ん中に寄せる。
  final _lineKeys = <int, GlobalKey>{};

  int _current = -1;
  bool _following = true;
  DateTime? _lastTouch;

  static const _lineGap = 14.0;

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.lyrics.isSynced) return;

    // 触ってから5秒たったら追従に戻す
    final last = _lastTouch;
    if (!_following && last != null &&
        DateTime.now().difference(last) > const Duration(seconds: 5)) {
      _following = true;
    }

    final index = widget.lyrics.indexAt(widget.position);
    if (index != _current) {
      _current = index;
      if (_following) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(index));
      }
    }
  }

  void _scrollTo(int index) {
    if (!mounted || !_controller.hasClients) return;
    final key = _lineKeys[index];
    final box = key?.currentContext?.findRenderObject();
    if (box is! RenderBox) return;

    final viewport = _controller.position.viewportDimension;
    final offsetInList = _controller.offset +
        box.localToGlobal(Offset.zero, ancestor: context.findRenderObject()).dy;
    final target = offsetInList - viewport / 2 + box.size.height / 2;

    _controller.animateTo(
      target.clamp(
        _controller.position.minScrollExtent,
        _controller.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (widget.lyrics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lyrics_outlined, size: 44, color: scheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                'この曲の歌詞は見つかりませんでした',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(
                '曲と同じ名前の .lrc ファイルを隣に置くか、\nタグに歌詞を入れると出ます',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!widget.lyrics.isSynced) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: [
          for (final line in widget.lyrics.plainLines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                line,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
        ],
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          setState(() {
            _following = false;
            _lastTouch = DateTime.now();
          });
        }
        if (notification is ScrollEndNotification) {
          _lastTouch = DateTime.now();
        }
        return false;
      },
      child: ListView.builder(
        controller: _controller,
        // 最初と最後の行も画面の真ん中に来られるように上下を空ける
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 140),
        itemCount: widget.lyrics.lines.length,
        itemBuilder: (context, i) {
          final line = widget.lyrics.lines[i];
          final active = i == _current;
          final key = _lineKeys.putIfAbsent(i, GlobalKey.new);

          return InkWell(
            key: key,
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              widget.onSeek(line.time);
              setState(() {
                _following = true;
                _lastTouch = null;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: _lineGap / 2,
                horizontal: 8,
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: active ? 21 : 17,
                  height: 1.4,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.45),
                ),
                textAlign: TextAlign.center,
                child: Text(
                  line.text.isEmpty ? '♪' : line.text,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
