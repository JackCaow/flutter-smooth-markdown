part of 'smooth_markdown.dart';

/// A top-level heading in reading order. Duplicate anchors gain a numeric suffix.
@immutable
class MarkdownHeading {
  const MarkdownHeading._(
    this.title,
    this.level,
    this.anchor,
    this.blockIndex,
    this.occurrence,
  );
  final String title;
  final int level;
  final String anchor;
  final int blockIndex;

  /// One-based occurrence of this displayed title within the document.
  final int occurrence;
}

/// A literal search result, with UTF-16 offsets in the block's readable text.
@immutable
class MarkdownSearchMatch {
  const MarkdownSearchMatch._(this.blockIndex, this.start, this.end);
  final int blockIndex;
  final int start;
  final int end;
}

/// Connects a box or sliver reader to an outline and full-document search.
///
/// The index uses the same parsed blocks as the renderer, including fenced code,
/// tables and inline formatting. A host can expose text for its own AST nodes
/// through [textForNode]. Matches never cross top-level block boundaries.
class MarkdownReaderController extends ChangeNotifier {
  MarkdownReaderController({this.textForNode});

  final String? Function(MarkdownNode)? textForNode;
  _NavigableDocumentState? _view;
  List<MarkdownNode> _nodes = const [];
  List<String>? _texts;
  List<MarkdownHeading> _headings = const [];
  Map<String, MarkdownHeading> _byAnchor = const {};
  List<MarkdownSearchMatch> _matches = const [];
  Map<int, List<MarkdownSearchMatch>> _byBlock = const {};
  int _active = -1;
  MarkdownHeading? _section;
  String _query = '';
  bool _caseSensitive = false;
  bool _complete = false;
  bool _deferred = false;
  bool _disposed = false;

  List<MarkdownHeading> get headings => _headings;
  MarkdownHeading? get activeHeading => _section;
  List<MarkdownSearchMatch> get matches => _matches;
  int get activeMatchIndex => _active;
  String get query => _query;
  bool get isIndexComplete => _complete;

  static final _punctuation = RegExp(r'[^\p{L}\p{M}\p{N}\s_-]', unicode: true);
  static final _spaces = RegExp(r'\s+');

  void _attach(_NavigableDocumentState view) {
    if (_view != null && _view != view) {
      throw StateError(
        'A MarkdownReaderController can serve one reader at a time.',
      );
    }
    _view = view;
  }

  void _detach(_NavigableDocumentState view) {
    if (_view != view) return;
    _view = null;
    _index(const [], false);
  }

  void _index(
    List<MarkdownNode> nodes,
    bool complete, {
    bool retainMatch = false,
  }) {
    final selectedIndex = retainMatch ? _active : -1;
    _nodes = nodes;
    _texts = null;
    _complete = complete;
    final anchors = <String, MarkdownHeading>{};
    final suffixes = <String, int>{};
    final titleCounts = <String, int>{};
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is! HeaderNode) continue;
      final title = _text(node);
      var base = title
          .trim()
          .toLowerCase()
          .replaceAll(_punctuation, '')
          .replaceAll(_spaces, '-');
      if (base.isEmpty) base = 'section';
      var anchor = base;
      var suffix = suffixes[base] ?? 0;
      while (anchors.containsKey(anchor)) {
        anchor = '$base-${++suffix}';
      }
      suffixes[base] = suffix;
      final occurrence = titleCounts.update(
        title,
        (n) => n + 1,
        ifAbsent: () => 1,
      );
      anchors[anchor] = MarkdownHeading._(
        title,
        node.level,
        anchor,
        i,
        occurrence,
      );
    }
    _byAnchor = anchors;
    _headings = List.unmodifiable(anchors.values);
    _section = null;
    _find();
    if (selectedIndex >= 0 && selectedIndex < _matches.length) {
      _active = selectedIndex;
    }
    _refreshHighlights();
    _changed();
  }

  String? _anchor(String fragment) {
    final raw = fragment.startsWith('#') ? fragment.substring(1) : fragment;
    try {
      return Uri.decodeComponent(raw);
    } on FormatException {
      return null;
      // Uri.decodeComponent throws ArgumentError on an incomplete percent escape.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      return null;
    }
  }

  bool _hasAnchor(String fragment) => _byAnchor.containsKey(_anchor(fragment));

  void _openLink(String url, ValueChanged<String>? fallback) {
    final view = _view;
    if (!url.startsWith('#') ||
        view == null ||
        (_complete && !_hasAnchor(url))) {
      fallback?.call(url);
      return;
    }
    final source = view.widget.document.data;
    unawaited(
      jumpToAnchor(url).then((_) {
        // A preview may not contain the target yet. Forward only after a full
        // index confirms the fragment does not belong to this same document.
        if (_view == view &&
            view.widget.document.data == source &&
            _complete &&
            !_hasAnchor(url)) {
          fallback?.call(url);
        }
      }),
    );
  }

  /// Scrolls to the heading, including a heading outside the current viewport.
  /// Accepts a decoded ID or a percent-encoded URL fragment.
  Future<bool> jumpToAnchor(String anchor) async {
    final view = _view;
    if (view == null) return false;
    var heading = _byAnchor[_anchor(anchor)];
    if (heading == null && !_complete) {
      final source = view.widget.document.data;
      await view.ready;
      if (_view != view || view.widget.document.data != source) return false;
      heading = _byAnchor[_anchor(anchor)];
    }
    return heading != null && await view.reveal(heading.blockIndex);
  }

  /// Searches all indexed blocks. The first result becomes current; call
  /// [jumpToMatch] to reveal it. The query stays active while the index grows.
  void search(String value, {bool caseSensitive = false}) {
    if (_query == value && _caseSensitive == caseSensitive) return;
    _view?._request++;
    _query = value;
    _caseSensitive = caseSensitive;
    _find();
    _refreshHighlights();
    _changed();
  }

  void _find() {
    final found = <MarkdownSearchMatch>[];
    final byBlock = <int, List<MarkdownSearchMatch>>{};
    if (_query.isNotEmpty) {
      final text = _texts ??= _nodes.map(_text).toList(growable: false);
      final pattern = RegExp(
        RegExp.escape(_query),
        caseSensitive: _caseSensitive,
        unicode: true,
      );
      for (var i = 0; i < text.length; i++) {
        for (final hit in pattern.allMatches(text[i])) {
          final match = MarkdownSearchMatch._(i, hit.start, hit.end);
          found.add(match);
          (byBlock[i] ??= []).add(match);
        }
      }
    }
    _matches = List.unmodifiable(found);
    _byBlock = byBlock;
    _active = found.isEmpty ? -1 : 0;
  }

  Future<bool> jumpToMatch(int index) async {
    if (index < 0 || index >= _matches.length || _view == null) return false;
    final hit = _matches[index];
    _active = index;
    _refreshHighlights();
    _changed();
    return _view!.reveal(hit.blockIndex, hit: hit);
  }

  Future<bool> nextMatch() => _matches.isEmpty
      ? Future.value(false)
      : jumpToMatch((_active + 1) % _matches.length);
  Future<bool> previousMatch() => _matches.isEmpty
      ? Future.value(false)
      : jumpToMatch((_active - 1) % _matches.length);

  void _setVisibleBlock(int index) {
    // The headings are sorted by block index.
    var lo = 0;
    var hi = _headings.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (_headings[mid].blockIndex <= index) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final next = lo == 0 ? null : _headings[lo - 1];
    if (next == _section) return;
    _section = next;
    _changed();
  }

  void _refreshHighlights() {
    final view = _view;
    if (view == null) return;
    for (final block in view._blocks.values) {
      block.markNeedsPaint();
    }
  }

  void _changed() {
    if (_disposed) return;
    // Parsing and attachment can finish during a build or layout pass.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_deferred) return;
      _deferred = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _deferred = false;
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  String _children(Iterable<MarkdownNode> nodes, [String separator = '']) =>
      nodes.map(_text).join(separator);

  String _text(MarkdownNode n) {
    final custom = textForNode?.call(n);
    if (custom != null) return custom;
    return switch (n) {
      HeaderNode(:final children) =>
        children == null ? n.content : _children(children),
      TextNode() => n.content,
      InlineCodeNode() => n.code,
      CodeBlockNode() => n.code,
      InlineMathNode() => n.latex,
      BlockMathNode() => n.latex,
      HardBreakNode() => '\n',
      ImageNode() => n.alt,
      ParagraphNode(:final children) ||
      BoldNode(:final children) ||
      ItalicNode(:final children) ||
      StrikethroughNode(:final children) ||
      LinkNode(:final children) ||
      ListItemNode(:final children) ||
      StyledSpanNode(:final children) ||
      HighlightNode(:final children) ||
      KbdNode(:final children) ||
      UnderlineNode(:final children) ||
      SubscriptNode(:final children) ||
      SuperscriptNode(:final children) => _children(children),
      BlockquoteNode(:final children) ||
      HtmlBlockNode(:final children) => _children(children, '\n'),
      ListNode() => _children(n.items, '\n'),
      TableNode() => [
        n.headers,
        ...n.rows.map((row) => row.cells),
      ].map((row) => row.map((cell) => _children(cell)).join('\t')).join('\n'),
      FootnoteReferenceNode() => '[${n.label}]',
      FootnoteDefinitionNode() => '[${n.label}]: ${_children(n.children)}',
      DetailsNode() =>
        '${_children(n.summary)}\n${_children(n.children, '\n')}',
      AdmonitionNode() => '${n.title}\n${_children(n.children, '\n')}',
      WikilinkNode() => n.label,
      MermaidDiagramNode() => n.code,
      ThinkingNode() => n.content,
      ArtifactNode() => [n.title, n.content].nonNulls.join('\n'),
      ToolCallNode() => [
        n.toolName,
        n.parameters?.toString(),
        n.result,
        n.errorMessage,
      ].nonNulls.join('\n'),
      MarkdownCitationNode() => '[${n.number}]',
      MentionNode() => '@${n.username}',
      HashtagNode() => '#${n.tag}',
      EmojiNode() => n.emoji,
      _ => '',
    };
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A lazily built, scroll-linked table of contents for a [MarkdownReaderController].
class MarkdownOutlineView extends StatelessWidget {
  const MarkdownOutlineView({
    required this.controller,
    super.key,
    this.onSelected,
  });
  final MarkdownReaderController controller;
  final ValueChanged<MarkdownHeading>? onSelected;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => ListView.builder(
      itemCount: controller.headings.length,
      itemBuilder: (context, index) {
        final heading = controller.headings[index];
        return ListTile(
          contentPadding: EdgeInsetsDirectional.only(
            start: 16 + (heading.level - 1) * 12,
            end: 16,
          ),
          title: Text(heading.title),
          trailing: heading.occurrence > 1
              ? Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatDecimal(heading.occurrence),
                )
              : null,
          selected: controller.activeHeading == heading,
          onTap: () {
            unawaited(controller.jumpToAnchor(heading.anchor));
            onSelected?.call(heading);
          },
        );
      },
    ),
  );
}

/// A search field with occurrence count and previous/next controls.
/// Connect it to the same controller as [SmoothMarkdown].
class MarkdownReaderSearchBar extends StatefulWidget {
  const MarkdownReaderSearchBar({
    required this.controller,
    super.key,
    this.autofocus = false,
    this.hintText,
    this.previousLabel,
    this.nextLabel,
  });
  final MarkdownReaderController controller;
  final bool autofocus;
  final String? hintText;
  final String? previousLabel;
  final String? nextLabel;

  @override
  State<MarkdownReaderSearchBar> createState() =>
      _MarkdownReaderSearchBarState();
}

class _MarkdownReaderSearchBarState extends State<MarkdownReaderSearchBar> {
  late final _input = TextEditingController(text: widget.controller.query);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(MarkdownReaderSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _sync();
    }
  }

  void _sync() {
    final q = widget.controller.query;
    if (_input.text != q) {
      _input.value = TextEditingValue(
        text: q,
        selection: TextSelection.collapsed(offset: q.length),
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reader = widget.controller;
    final l = MaterialLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _input,
            autofocus: widget.autofocus,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: widget.hintText ?? l.searchFieldLabel,
            ),
            onChanged: (s) {
              reader.search(s);
              if (reader.matches.isNotEmpty) unawaited(reader.jumpToMatch(0));
            },
            onSubmitted: (_) => unawaited(reader.nextMatch()),
          ),
        ),
        ListenableBuilder(
          listenable: reader,
          builder: (context, _) => Row(
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  '${reader.activeMatchIndex + 1} / ${reader.matches.length}',
                ),
              ),
              IconButton(
                tooltip: widget.previousLabel ?? l.previousPageTooltip,
                onPressed: reader.matches.isEmpty
                    ? null
                    : () => unawaited(reader.previousMatch()),
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                tooltip: widget.nextLabel ?? l.nextPageTooltip,
                onPressed: reader.matches.isEmpty
                    ? null
                    : () => unawaited(reader.nextMatch()),
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
