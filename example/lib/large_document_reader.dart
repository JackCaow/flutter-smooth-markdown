import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

import 'large_document_sample.dart';

/// Opens the benchmark document or Markdown pasted explicitly by the reader.
class LargeDocumentReader extends StatefulWidget {
  const LargeDocumentReader({super.key, required this.title, this.style});

  final String title;
  final MarkdownStyleSheet? style;

  @override
  State<LargeDocumentReader> createState() => _LargeDocumentReaderState();
}

class _LargeDocumentReaderState extends State<LargeDocumentReader> {
  late final String _sample = buildLargeDocumentSample();
  final _controller = ScrollController();
  String? _pasted;

  void _open(String? text) {
    if (_controller.hasClients) _controller.jumpTo(0);
    setState(() => _pasted = text);
  }

  Future<void> _paste(bool chinese) async {
    try {
      final value = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (!mounted) return;
      if (value != null && value.isNotEmpty) {
        _open(value);
        return;
      }
      _notice(chinese ? '剪贴板没有文本' : 'The clipboard contains no text.');
    } on PlatformException {
      if (mounted) {
        _notice(chinese ? '无法读取剪贴板' : 'Could not read the clipboard.');
      }
    }
  }

  void _notice(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final source = _pasted ?? _sample;
    final sourceLabel = _pasted != null
        ? (chinese ? '剪贴板' : 'Clipboard')
        : (chinese ? '混合排版样本' : 'Mixed Markdown sample');
    final units = MaterialLocalizations.of(
      context,
    ).formatDecimal(source.length);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_pasted != null)
            IconButton(
              tooltip: chinese ? '打开原始样本' : 'Reopen sample',
              onPressed: () => _open(null),
              icon: const Icon(Icons.restart_alt),
            ),
          IconButton(
            key: const ValueKey('large-document-paste'),
            tooltip: chinese ? '从剪贴板打开' : 'Open from clipboard',
            onPressed: () => _paste(chinese),
            icon: const Icon(Icons.content_paste_go_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Scrollbar(
              controller: _controller,
              child: CustomScrollView(
                controller: _controller,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Text(
                        chinese
                            ? '$sourceLabel · $units UTF-16 码元'
                            : '$sourceLabel · $units UTF-16 units',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    sliver: SmoothMarkdown.sliver(
                      data: source,
                      styleSheet:
                          widget.style ??
                          MarkdownStyleSheet.fromBrightness(
                            Theme.of(context).brightness,
                          ),
                      enableCache: _pasted == null,
                      useEnhancedComponents: true,
                      onTapLink: _notice,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
