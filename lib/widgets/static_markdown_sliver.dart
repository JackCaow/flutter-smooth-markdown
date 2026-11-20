part of 'smooth_markdown.dart';

const _largeDocumentUnits = 32 * 1024;
const _previewUnits = 4096;

typedef _ParseRequest = ({
  String source,
  MarkdownParserBackend backend,
  bool html,
});

// A top-level callback sends just the immutable source and parser policy to
// the worker. Widget callbacks, plugin instances and BuildContexts stay local.
List<MarkdownNode> _parseStaticDocument(_ParseRequest request) =>
    MarkdownParser(
      backend: request.backend,
      enableHtml: request.html,
    ).parse(request.source);

class _StaticMarkdownSliver extends StatefulWidget {
  const _StaticMarkdownSliver({required this.document});
  final SmoothMarkdown document;

  @override
  State<_StaticMarkdownSliver> createState() => _StaticMarkdownSliverState();
}

class _StaticMarkdownSliverState extends State<_StaticMarkdownSliver> {
  List<MarkdownNode> _nodes = const [];
  _ParseRequest? _wanted;
  bool _running = false;
  AsyncError? _error;
  List<BlockParserPlugin>? _inactiveBlocks;
  List<InlineParserPlugin>? _inactiveInlines;
  var _generation = SmoothMarkdown._cacheGeneration;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(_StaticMarkdownSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.document;
    final doc = widget.document;
    if (old.data != doc.data ||
        old._backend != doc._backend ||
        old.config?.enableHtml != doc.config?.enableHtml ||
        old.plugins != doc.plugins ||
        (doc.plugins != null &&
            (_inactiveBlocks == null ||
                !listEquals(_inactiveBlocks, doc.plugins!.blockPlugins) ||
                !listEquals(_inactiveInlines, doc.plugins!.inlinePlugins))) ||
        _generation != SmoothMarkdown._cacheGeneration) {
      _read();
    }
  }

  void _read() {
    final doc = widget.document;
    _generation = SmoothMarkdown._cacheGeneration;
    _wanted = null;
    _error = null;
    _inactiveBlocks = null;
    _inactiveInlines = null;
    final cached = doc._cache?.get(doc.data);
    if (cached != null) {
      _nodes = cached;
      return;
    }
    final html = doc.config?.enableHtml ?? false;
    if (doc.data.length < _largeDocumentUnits) {
      _nodes = doc._parse();
      return;
    }

    // Unknown hooks can close over UI objects or depend on invocation order.
    // Only bypass exact built-in hooks when the full input rules them out.
    final previewAllowed =
        !html &&
        (doc.plugins == null ||
            doc.plugins.runtimeType == ParserPluginRegistry) &&
        canParseIncrementally(doc.data, doc.plugins);
    if (doc.plugins != null && !previewAllowed) {
      _nodes = doc._parse();
      return;
    }
    if (doc.plugins != null) {
      _inactiveBlocks = doc.plugins!.blockPlugins;
      _inactiveInlines = doc.plugins!.inlinePlugins;
    }
    final backend = backendForSourceLength(doc._backend, doc.data.length);
    final request = (source: doc.data, html: html, backend: backend);
    _nodes = const [];
    if (previewAllowed && !doc.data.contains(']:')) {
      // As in both append-only parsers, the last two blocks may still change.
      // Resolve references against the entire document whenever it contains
      // definitions. Never present a partial paragraph, fence or table as final.
      final boundary = doc.data.lastIndexOf('\n', _previewUnits);
      if (boundary > 0) {
        final head = MarkdownParser(
          backend: backend,
        ).parse(doc.data.substring(0, boundary + 1));
        if (head.length > 2) _nodes = head.sublist(0, head.length - 2);
      }
    }
    _wanted = request;
    if (!_running) unawaited(_finish(request));
  }

  Future<void> _finish(_ParseRequest request) async {
    _running = true;
    try {
      final nodes = await compute(
        _parseStaticDocument,
        request,
        debugLabel: 'SmoothMarkdown.parse',
      );
      if (mounted && _wanted == request) {
        if (_generation == SmoothMarkdown._cacheGeneration) {
          widget.document._cache?.put(request.source, nodes);
        }
        setState(() {
          _wanted = null;
          _nodes = nodes;
        });
      }
    } catch (error, stack) {
      if (mounted && _wanted == request) {
        setState(() {
          _wanted = null;
          _error = AsyncError(error, stack);
        });
      }
    } finally {
      _running = false;
      // Rapid replacements share at most one running parser. Skip obsolete
      // pending documents and never publish results for a previous input.
      final next = _wanted;
      if (mounted && next != null) unawaited(_finish(next));
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) Error.throwWithStackTrace(error.error, error.stackTrace);
    if (_wanted != null &&
        (_nodes.isEmpty ||
            widget.document.selectable ||
            Scrollable.maybeOf(context)?.axisDirection == AxisDirection.up)) {
      return const SliverToBoxAdapter(child: LinearProgressIndicator());
    }
    return widget.document.renderSliverNodes(
      context,
      _nodes,
      complete: _wanted == null,
    );
  }
}

// Preserve the box contract for consumers with their own SingleChildScrollView.
// Without host builders, an unchanged large document can reuse its entire tree
// across unrelated parent rebuilds, even for an explicitly selected backend.
class _StaticMarkdownBox extends StatefulWidget {
  const _StaticMarkdownBox({required this.document});
  final SmoothMarkdown document;

  @override
  State<_StaticMarkdownBox> createState() => _StaticMarkdownBoxState();
}

class _StaticMarkdownBoxState extends State<_StaticMarkdownBox> {
  List<MarkdownNode>? _nodes;
  Widget? _content;
  var _generation = SmoothMarkdown._cacheGeneration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _content = null;
  }

  @override
  void didUpdateWidget(_StaticMarkdownBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.document;
    final doc = widget.document;
    if (doc.data != old.data ||
        old._backend != doc._backend ||
        old.config?.enableHtml != doc.config?.enableHtml ||
        _generation != SmoothMarkdown._cacheGeneration) {
      _nodes = null;
      _content = null;
    }
    _generation = SmoothMarkdown._cacheGeneration;
    if (doc.readerController != old.readerController ||
        doc.styleSheet != old.styleSheet ||
        doc.config != old.config ||
        doc.useEnhancedComponents != old.useEnhancedComponents ||
        doc.useRepaintBoundary != old.useRepaintBoundary ||
        doc.onTapLink != old.onTapLink ||
        doc.onTapImage != old.onTapImage) {
      _content = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    return _content ??= doc.renderNodes(context, _nodes ??= doc._parse());
  }
}
