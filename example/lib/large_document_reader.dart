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
  final _reader = MarkdownReaderController();
  bool _searching = false;
  String? _pasted;

  void _open(String? text) {
    if (_controller.hasClients) _controller.jumpTo(0);
    _reader.search('');
    setState(() {
      _pasted = text;
      _searching = false;
    });
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
    _reader.dispose();
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
          IconButton(
            tooltip: chinese ? '目录' : 'Table of contents',
            icon: const Icon(Icons.toc),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (sheet) => SafeArea(
                child: Column(
                  children: [
                    Text(
                      chinese ? '目录' : 'Table of contents',
                      style: Theme.of(sheet).textTheme.titleLarge,
                    ),
                    Expanded(
                      child: MarkdownOutlineView(
                        controller: _reader,
                        onSelected: (_) => Navigator.pop(sheet),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: chinese ? '在文档中查找' : 'Find in document',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching) _reader.search('');
            },
          ),
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
        bottom: _searching
            ? PreferredSize(
                preferredSize: const Size.fromHeight(55),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MarkdownReaderSearchBar(
                    controller: _reader,
                    autofocus: true,
                    hintText: chinese ? '输入要查找的文字' : 'Find in document',
                    previousLabel: chinese ? '上一个匹配项' : 'Previous match',
                    nextLabel: chinese ? '下一个匹配项' : 'Next match',
                  ),
                ),
              )
            : null,
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
                      readerController: _reader,
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
