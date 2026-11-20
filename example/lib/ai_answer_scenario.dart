import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

import 'ai_chat_demo.dart';

/// An offline assistant replay grounded in a small, reproducible frame profile.
class AiAnswerScenario extends StatefulWidget {
  const AiAnswerScenario({super.key});

  @override
  State<AiAnswerScenario> createState() => _AiAnswerScenarioState();
}

typedef _Exchange = ({String question, List<String> chunks});

const _chinese = <_Exchange>[
  (
    question: '长文档滚动时，先查哪里？',
    chunks: [
      '**先看 UI 线程。** ',
      '60 Hz 屏幕每帧约有 16.7 ms。样本里的 UI P95 达到 24 ms，',
      'Raster P95 为 4 ms。先打开一帧慢帧，看时间花在哪个阶段。[1]\n\n',
      '### 在时间线上找重复工作\n\n',
      '1. 静止页面，只追加一小段 Markdown。观察解析和组件构建事件。\n',
      '2. 停止追加，滚动同一段内容。查看慢帧里的布局事件。\n',
      '3. 如果每次追加都会重新布局旧段落，就把稳定区块和正在变化的末段分开。\n\n',
      '> P95 能帮你选择排查方向。具体是哪一段代码，还需要一帧的时间线来确认。',
    ],
  ),
  (
    question: '怎么验证优化有效？',
    chunks: [
      '**用同一段输入，重放同一组操作。** ',
      '在同一台真机上使用 profile 构建，固定文档、追加节奏和滚动距离。\n\n',
      '### 分开记录两段操作\n\n',
      '| 操作 | 观察指标 |\n',
      '| --- | --- |\n',
      '| 静止时追加文本 | 追加期间的 UI P95 |\n',
      '| 停止追加后滚动 | 滚动慢帧数和 Raster P95 |\n\n',
      '先预热一次，再分别记录多轮。这个示例的 UI 基线是 **24 ms**。[1]',
      '比较改动前后同一指标，同时核对最终的文本、代码块和表格。\n\n',
      '> 保留帧时间线。遇到偶发慢帧时，还能回到对应的那次操作。',
    ],
  ),
];

const _english = <_Exchange>[
  (
    question: 'What should I inspect first?',
    chunks: [
      '**Start with the UI thread.** ',
      'A 60 Hz display allows about 16.7 ms per frame. In the sample, UI P95 is 24 ms ',
      'and raster P95 is 4 ms. Open one slow frame to see which phase took the time. [1]\n\n',
      '### Look for repeated work\n\n',
      '1. Hold the page still and append a little Markdown. Watch the parsing and build events.\n',
      '2. Stop appending and scroll through the same passage. Check layout work in slow frames.\n',
      '3. If each append lays out old paragraphs again, separate stable blocks from the changing tail.\n\n',
      '> P95 points you toward a thread. A frame timeline identifies the expensive operation.',
    ],
  ),
  (
    question: 'How do I verify the improvement?',
    chunks: [
      '**Replay the same input and gestures.** ',
      'Use a profile build on the same phone. Keep the document, append cadence and scroll distance fixed.\n\n',
      '### Record two separate intervals\n\n',
      '| Action | Metric |\n',
      '| --- | --- |\n',
      '| Append while stationary | UI P95 during appends |\n',
      '| Scroll with appends stopped | Slow frames and raster P95 |\n\n',
      'Warm up once, then collect several runs. This sample has a UI baseline of **24 ms**. [1] ',
      'Compare the same metric before and after. Check the final text, code blocks and tables as well.\n\n',
      '> Save the timeline so you can trace an occasional slow frame back to the gesture that triggered it.',
    ],
  ),
];

enum _Playback { playing, paused, finished }

class _AiAnswerScenarioState extends State<AiAnswerScenario> {
  final _scroll = MarkdownChatScrollController();
  final _plugins = ParserPluginRegistry()
    ..register(const MarkdownCitationPlugin());
  StreamController<String>? _response;
  Timer? _clock;
  bool? _zh;
  int _question = 0;
  int _next = 0;
  _Playback _playback = _Playback.playing;

  List<_Exchange> get _exchanges => _zh! ? _chinese : _english;
  List<String> get _chunks => _exchanges[_question].chunks;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    if (_zh != chinese) {
      _zh = chinese;
      _start(_question);
    }
  }

  void _start(int index) {
    _clock?.cancel();
    _response?.close();
    _question = index;
    _next = 0;
    _response = StreamController<String>();
    _response!.add(_chunks[_next++]);
    _resume();
    _scroll.jumpToLatest();
  }

  void _resume() {
    _playback = _Playback.playing;
    _clock = Timer.periodic(const Duration(milliseconds: 490), (timer) {
      _response!.add(_chunks[_next++]);
      if (_next == _chunks.length) {
        timer.cancel();
        _response!.close();
        setState(() => _playback = _Playback.finished);
      }
    });
  }

  void _togglePlayback() {
    setState(() {
      switch (_playback) {
        case _Playback.playing:
          _clock?.cancel();
          _playback = _Playback.paused;
        case _Playback.paused:
          _resume();
        case _Playback.finished:
          _start(_question);
      }
    });
  }

  Future<void> _chooseQuestion() async {
    const customQuestion = -1;
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                _zh! ? '关于这份采样' : 'Ask about this profile',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (var i = 0; i < _exchanges.length; i++)
              ListTile(
                key: ValueKey('ai-answer-prompt-$i'),
                title: Text(_exchanges[i].question),
                trailing: Icon(
                  i == _question ? Icons.check : Icons.arrow_outward,
                ),
                onTap: () => Navigator.pop(context, i),
              ),
            const Divider(),
            ListTile(
              key: const ValueKey('ai-answer-custom'),
              title: Text(_zh! ? '自己提问' : 'Ask your own question'),
              subtitle: Text(
                _zh!
                    ? '可在聊天设置中连接 DeepSeek，未配置时使用模拟回答。'
                    : 'Connect DeepSeek in chat settings, or try a simulated reply.',
              ),
              trailing: const Icon(Icons.arrow_forward_rounded),
              onTap: () => Navigator.pop(context, customQuestion),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == customQuestion) {
      if (_playback == _Playback.playing) _togglePlayback();
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const AIChatDemo()));
    } else if (choice != _question) {
      setState(() => _start(choice));
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _chunks.join()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_zh! ? '已复制 Markdown 回答' : 'Markdown answer copied'),
      ),
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    _response?.close();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zh = _zh!;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final paper = dark ? const Color(0xFF1D2022) : const Color(0xFFF8F6F2);
    final ink = dark ? const Color(0xFFF6F1E7) : const Color(0xFF20232B);
    final accent = dark ? const Color(0xFFFFAE91) : const Color(0xFFAD462C);
    final tint = dark ? const Color(0xFF49342D) : const Color(0xFFF2E5DC);
    final (playLabel, playIcon) = switch (_playback) {
      _Playback.playing => (zh ? '暂停' : 'Pause', Icons.pause_rounded),
      _Playback.paused => (zh ? '继续' : 'Resume', Icons.play_arrow_rounded),
      _Playback.finished => (zh ? '重播' : 'Replay', Icons.replay_rounded),
    };
    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        backgroundColor: paper,
        foregroundColor: ink,
        title: Text(zh ? 'AI 问答' : 'AI Q&A'),
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _scroll.following,
        builder: (context, following, _) => following
            ? const SizedBox.shrink()
            : FloatingActionButton.small(
                tooltip: zh ? '回到最新' : 'Jump to latest',
                onPressed: _scroll.jumpToLatest,
                child: const Icon(Icons.vertical_align_bottom),
              ),
      ),
      body: MarkdownCitationScope(
        sources: {
          1: MarkdownSource(
            title: zh ? '长文档滚动采样' : 'Long-document scroll profile',
            excerpt: zh
                ? '60 Hz 示例采样。UI P95 为 24 ms，Raster P95 为 4 ms。'
                : '60 Hz sample. UI P95 was 24 ms and Raster P95 was 4 ms.',
          ),
        },
        onSourceTap: (source) => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListTile(
              title: Text(source.title),
              subtitle: Text(source.excerpt!),
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FrameProfile(zh: zh),
                          const SizedBox(height: 22),
                          Align(
                            alignment: Alignment.centerRight,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: tint,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(17),
                                  topRight: Radius.circular(17),
                                  bottomLeft: Radius.circular(17),
                                  bottomRight: Radius.circular(3),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 11,
                                ),
                                child: Text(
                                  _exchanges[_question].question,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Icon(
                                Icons.forum_outlined,
                                size: 18,
                                color: accent,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  zh ? '本地示例回答' : 'Offline sample answer',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                    sliver: StreamMarkdown.sliver(
                      key: ObjectKey(_response),
                      stream: _response!.stream,
                      plugins: _plugins,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme),
                      useEnhancedComponents: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('ai-answer-questions'),
              onPressed: _chooseQuestion,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
              label: Text(zh ? '换个问题' : 'Questions'),
              style: OutlinedButton.styleFrom(foregroundColor: ink),
            ),
            FilledButton.icon(
              key: const ValueKey('ai-answer-playback'),
              onPressed: _togglePlayback,
              icon: Icon(playIcon, size: 18),
              label: Text(playLabel),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: dark ? const Color(0xFF331A12) : Colors.white,
              ),
            ),
            IconButton(
              key: const ValueKey('ai-answer-copy'),
              tooltip: zh ? '复制完整回答' : 'Copy full answer',
              onPressed: _playback == _Playback.finished ? _copy : null,
              icon: const Icon(Icons.copy_rounded, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrameProfile extends StatelessWidget {
  const _FrameProfile({required this.zh});
  final bool zh;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff293433),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              zh ? '长文档滚动采样' : 'Long-document scroll profile',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xfff6f4e9),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              zh ? '模拟数据 · 60 Hz' : 'Sample data · 60 Hz',
              style: const TextStyle(color: Color(0xffc3d0c8)),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xff52605a)),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 28,
              runSpacing: 8,
              children: [
                _Metric(
                  label: 'UI P95',
                  value: '24 ms',
                  color: Color(0xffffb295),
                ),
                _Metric(
                  label: 'Raster P95',
                  value: '4 ms',
                  color: Color(0xffd5e6d4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xffc3d0c8), fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 23,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}
