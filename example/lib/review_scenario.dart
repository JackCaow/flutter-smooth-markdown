import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

const _files = [
  (
    name: 'answer_buffer.dart',
    patch: '''--- a/lib/answer_buffer.dart
+++ b/lib/answer_buffer.dart
@@ -6,4 +6,4 @@ class AnswerBuffer {
   void append(String chunk) {
-    if (chunk.trim().isEmpty) return;
+    if (chunk.isEmpty) return;
     _text.write(chunk);
   }''',
  ),
  (
    name: 'answer_buffer_test.dart',
    patch: r'''--- a/test/answer_buffer_test.dart
+++ b/test/answer_buffer_test.dart
@@ -7,2 +7,10 @@ void main() {
   });
+
+  test('keeps paragraph breaks', () {
+    final buffer = AnswerBuffer();
+    buffer.append('One');
+    buffer.append('\n\n');
+    buffer.append('Two');
+    expect(buffer.text, 'One\n\nTwo');
+  });
 }''',
  ),
];

/// An offline pull request with a reproducible input and a two-file review.
class ReviewScenario extends StatefulWidget {
  const ReviewScenario({super.key});

  @override
  State<ReviewScenario> createState() => _ReviewScenarioState();
}

class _ReviewScenarioState extends State<ReviewScenario> {
  int _selected = 0;
  final _reviewed = <int>{};
  bool _after = false;
  PageStorageBucket? _storage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final storage = PageStorage.maybeOf(context);
    if (identical(storage, _storage)) return;
    _storage = storage;
    final saved = storage?.readState(context, identifier: 'review-files');
    _reviewed.clear();
    if (saved is Set<int>) _reviewed.addAll(saved);
  }

  void _toggleReview() {
    setState(() {
      if (!_reviewed.remove(_selected)) _reviewed.add(_selected);
    });
    _storage?.writeState(context, {..._reviewed}, identifier: 'review-files');
  }

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final panel = dark ? const Color(0xff28292e) : const Color(0xfffffdfa);
    final line = colors.outlineVariant;
    final heading = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final reviewed = _reviewed.contains(_selected);
    final complete = _reviewed.length == _files.length;
    final status = complete
        ? (zh ? '审阅完成 · 2/2' : 'Review complete · 2/2')
        : (zh ? '已审阅 ${_reviewed.length}/2' : '${_reviewed.length}/2 reviewed');
    const chunks = ['One', '\n\n', 'Two'];
    final result = chunks.where((chunk) {
      return _after ? chunk.isNotEmpty : chunk.trim().isNotEmpty;
    }).join();

    return Scaffold(
      appBar: AppBar(title: Text(zh ? '代码审阅' : 'Code review')),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              children: [
                Row(
                  children: [
                    Icon(Icons.merge_rounded, color: colors.primary, size: 20),
                    const SizedBox(width: 7),
                    Text(
                      zh ? '本地示例 PR' : 'Local sample PR',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  zh
                      ? '修复回答里的段落粘连'
                      : 'Keep paragraph breaks in streamed replies',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.14,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  zh
                      ? '当换行符单独到达时，聊天窗口会把前后两段拼在一起。这次改动修正了缓冲区过滤逻辑，并补上回归测试。'
                      : 'When a line break arrives on its own, the chat joins two paragraphs. This patch fixes the buffer and adds a regression test.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                Text(zh ? '改动文件' : 'Changed files', style: heading),
                const SizedBox(height: 8),
                Material(
                  color: panel,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: line),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _files.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: line),
                        Semantics(
                          selected: i == _selected,
                          button: true,
                          value: _reviewed.contains(i)
                              ? (zh ? '已审阅' : 'Reviewed')
                              : (zh ? '待审阅' : 'Pending review'),
                          child: Ink(
                            color: i == _selected
                                ? colors.primary.withValues(
                                    alpha: dark ? .15 : .07,
                                  )
                                : panel,
                            child: InkWell(
                              key: ValueKey('review-file-$i'),
                              onTap: () => setState(() => _selected = i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 13,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _reviewed.contains(i)
                                          ? Icons.check_circle_rounded
                                          : Icons.code_rounded,
                                      size: 19,
                                      color:
                                          i == _selected ||
                                              _reviewed.contains(i)
                                          ? colors.primary
                                          : colors.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _files[i].name,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 13,
                                          fontWeight: i == _selected
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    if (i == _selected)
                                      Icon(
                                        Icons.chevron_right,
                                        size: 18,
                                        color: colors.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: panel,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: line),
                  ),
                  child: MarkdownDiffView(
                    key: ValueKey(_selected),
                    patch: _files[_selected].patch,
                    language: 'dart',
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 2,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  zh ? '重放这三个数据块' : 'Replay the three chunks',
                  style: heading,
                ),
                const SizedBox(height: 8),
                Material(
                  color: panel,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: line),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          r"'One'  →  '\n\n'  →  'Two'",
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: false,
                              label: Text(zh ? '修改前' : 'Before'),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text(zh ? '修改后' : 'After'),
                            ),
                          ],
                          selected: {_after},
                          onSelectionChanged: (value) =>
                              setState(() => _after = value.single),
                        ),
                        const SizedBox(height: 12),
                        SmoothMarkdown(data: result),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: panel,
          border: Border(top: BorderSide(color: line)),
        ),
        child: SafeArea(
          top: false,
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          status,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: complete
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 2,
                      child: FilledButton.icon(
                        key: const ValueKey('review-toggle'),
                        icon: Icon(
                          reviewed ? Icons.undo_rounded : Icons.done_rounded,
                          size: 18,
                        ),
                        label: Text(
                          reviewed
                              ? (zh ? '撤销标记' : 'Undo review')
                              : (zh ? '标记已审阅' : 'Mark reviewed'),
                        ),
                        onPressed: _toggleReview,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
