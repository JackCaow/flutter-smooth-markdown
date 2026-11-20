import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

import 'l10n/app_localizations.dart';

/// A local, replayable stream of Markdown chunks.
class StreamingMarkdownDemo extends StatefulWidget {
  const StreamingMarkdownDemo({super.key, this.styleSheet});

  final MarkdownStyleSheet? styleSheet;

  @override
  State<StreamingMarkdownDemo> createState() => _StreamingMarkdownDemoState();
}

enum _Playback { idle, playing, paused, finished }

class _StreamingMarkdownDemoState extends State<StreamingMarkdownDemo> {
  static const _en = [
    '# Rendering a response\n\n',
    'A Markdown stream can deliver ',
    '**one phrase at a time**. ',
    'The reader keeps the earlier text as each new chunk arrives.\n\n',
    '## Connect the stream\n\n',
    '```dart\n',
    'StreamMarkdown(\n',
    '  stream: responseStream,\n',
    '  useEnhancedComponents: true,\n',
    ')\n',
    '```\n\n',
    '## What to watch\n\n',
    '- A heading appears on its own line.\n',
    '- The code block closes when its fence arrives.\n',
    '- The table takes shape as its rows arrive.\n\n',
    '| Block | Markdown |\n',
    '| --- | --- |\n',
    '| Heading | `##` |\n',
    '| List | `-` |\n\n',
    '> Pause the stream to read a partial response. ',
    'Resume to keep reading from the same place.\n',
  ];
  static const _zh = [
    '# 渲染一段回复\n\n',
    'Markdown 可以',
    '**逐段传入**。',
    '每次收到新片段，',
    '阅读器都会保留已有的内容。\n\n',
    '## 连接内容流\n\n',
    '```dart\n',
    'StreamMarkdown(\n',
    '  stream: responseStream,\n',
    '  useEnhancedComponents: true,\n',
    ')\n',
    '```\n\n',
    '## 观察这些变化\n\n',
    '- 标题从单独的一行开始。\n',
    '- 闭合标记到达后，代码块就完整了。\n',
    '- 表格会随着每一行内容逐渐成形。\n\n',
    '| 区块 | Markdown |\n',
    '| --- | --- |\n',
    '| 标题 | `##` |\n',
    '| 列表 | `-` |\n\n',
    '> 可以暂停阅读当前内容，',
    '再从刚才的位置继续播放。\n',
  ];

  _Playback _playback = _Playback.idle;
  StreamController<String>? _controller;
  Timer? _timer;
  List<String> _chunks = const [];
  final _position = ValueNotifier<int>(0);

  void _play(bool chinese) {
    if (_playback == _Playback.playing) {
      _timer?.cancel();
      setState(() => _playback = _Playback.paused);
      return;
    }
    if (_playback != _Playback.paused) {
      _controller = StreamController<String>();
      _chunks = chinese ? _zh : _en;
      _position.value = 0;
    }
    setState(() => _playback = _Playback.playing);
    _emitChunk();
    if (_playback == _Playback.playing) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 220),
        (_) => _emitChunk(),
      );
    }
  }

  void _emitChunk() {
    final controller = _controller!;
    controller.add(_chunks[_position.value]);
    _position.value++;
    if (_position.value == _chunks.length) {
      _timer?.cancel();
      controller.close();
      setState(() => _playback = _Playback.finished);
    }
  }

  void _reset() {
    _timer?.cancel();
    _controller?.close();
    setState(() {
      _position.value = 0;
      _chunks = const [];
      _controller = null;
      _playback = _Playback.idle;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.close();
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final localized = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final title = localized?.demoStreaming ?? (zh ? '流式渲染' : 'Streaming');
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final canvas = dark ? const Color(0xff191a1f) : const Color(0xfff8f6f2);
    final accent = dark ? const Color(0xffffac91) : const Color(0xffb74c30);
    final ink = dark ? const Color(0xfff8f6f2) : const Color(0xff20232b);
    final border = dark ? const Color(0xff42434b) : const Color(0xffdcd6cd);
    final paper = dark ? const Color(0xff23242b) : const Color(0xfffffdfa);
    final sheetColor = widget.styleSheet?.textStyle?.color;
    final contentDark = sheetColor == null
        ? dark
        : ThemeData.estimateBrightnessForColor(sheetColor) == Brightness.light;
    final documentColor = contentDark
        ? const Color(0xff23242b)
        : const Color(0xfffffdfa);
    final total = _chunks.isNotEmpty
        ? _chunks.length
        : (zh ? _zh.length : _en.length);
    final (label, icon) = switch (_playback) {
      _Playback.idle => (
        zh ? '开始播放' : 'Start stream',
        Icons.play_arrow_rounded,
      ),
      _Playback.playing => (zh ? '暂停' : 'Pause', Icons.pause_rounded),
      _Playback.paused => (zh ? '继续播放' : 'Resume', Icons.play_arrow_rounded),
      _Playback.finished => (zh ? '重新播放' : 'Replay', Icons.replay_rounded),
    };

    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        backgroundColor: canvas,
        foregroundColor: ink,
        title: Text(title),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Material(
                  color: paper,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.notes_rounded, color: accent, size: 19),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'stream-notes.md',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: ink,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: border),
                      if (_controller == null)
                        Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                zh ? '渲染一段回复' : 'Rendering a response',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                zh
                                    ? '播放这份笔记，观察标题、代码和表格如何随片段到达而出现。'
                                    : 'Play the note to see headings, code and a table appear as each chunk arrives.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: ink,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ColoredBox(
                          color: documentColor,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: StreamMarkdown(
                              key: ObjectKey(_controller),
                              stream: _controller!.stream,
                              styleSheet:
                                  widget.styleSheet ??
                                  MarkdownStyleSheet.fromTheme(theme),
                              useEnhancedComponents: true,
                              loadingWidget: const SizedBox.shrink(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: ColoredBox(
        color: paper,
        child: SafeArea(
          top: false,
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: ValueListenableBuilder<int>(
                  valueListenable: _position,
                  builder: (context, received, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              zh ? '已接收片段' : 'Chunks received',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: ink,
                              ),
                            ),
                          ),
                          Text(
                            '$received / $total',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: received / total,
                        minHeight: 3,
                        color: accent,
                        backgroundColor: border,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: dark
                                    ? const Color(0xff311a12)
                                    : Colors.white,
                                minimumSize: const Size(48, 46),
                              ),
                              onPressed: () => _play(zh),
                              icon: Icon(icon),
                              label: Text(label),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            tooltip: zh ? '重置' : 'Reset',
                            onPressed: _controller == null ? null : _reset,
                            icon: const Icon(Icons.restart_alt_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
