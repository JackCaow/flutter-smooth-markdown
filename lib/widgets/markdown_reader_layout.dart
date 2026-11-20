part of 'smooth_markdown.dart';

class _NavigableDocument extends StatefulWidget {
  const _NavigableDocument({
    required this.document,
    required this.nodes,
    required this.sliver,
    this.complete = true,
  });
  final SmoothMarkdown document;
  final List<MarkdownNode> nodes;
  final bool sliver;
  final bool complete;
  @override
  State<_NavigableDocument> createState() => _NavigableDocumentState();
}

class _NavigableDocumentState extends State<_NavigableDocument> {
  final _sliverKey = GlobalKey();
  final _blocks = <int, _RenderReaderBlock>{};
  ScrollPosition? _position;
  Completer<void>? _ready;
  Future<void> get ready => (_ready ??= Completer<void>()).future;
  int _request = 0;
  bool _framePending = false;
  MarkdownReaderController get reader => widget.document.readerController!;

  @override
  void initState() {
    super.initState();
    reader
      .._attach(this)
      .._index(widget.nodes, widget.complete);
  }

  @override
  void didUpdateWidget(_NavigableDocument oldWidget) {
    super.didUpdateWidget(oldWidget);
    final replaced = oldWidget.document.readerController != reader;
    if (replaced) {
      oldWidget.document.readerController?._detach(this);
      reader._attach(this);
    }
    if (replaced ||
        !identical(oldWidget.nodes, widget.nodes) ||
        oldWidget.complete != widget.complete) {
      _request++;
      reader._index(
        widget.nodes,
        widget.complete,
        retainMatch:
            !replaced && oldWidget.document.data == widget.document.data,
      );
      for (final block in _blocks.values) {
        block.markNeedsPaint();
      }
      if (widget.complete ||
          oldWidget.document.data != widget.document.data ||
          replaced) {
        _ready?.complete();
        _ready = null;
      }
      _scheduleSection();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (_position != position) {
      _position?.removeListener(_scheduleSection);
      _position = position;
      position?.addListener(_scheduleSection);
    }
    _scheduleSection();
  }

  void _scheduleSection() {
    if (_framePending) return;
    _framePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _framePending = false;
      if (!mounted || _blocks.isEmpty || _position == null) return;
      final pos = _position!;
      if (!pos.hasPixels) return;
      // In a box all blocks are mounted; binary search also avoids scanning
      // them on each scroll tick. In a sliver only the cache window exists.
      final indices = widget.sliver ? (_blocks.keys.toList()..sort()) : null;
      var lo = 0;
      var hi = indices?.length ?? widget.nodes.length;
      while (lo < hi) {
        final mid = (lo + hi) ~/ 2;
        final box = _blocks[indices?[mid] ?? mid];
        if (box == null || !box.attached || !box.hasSize) return;
        final viewport = RenderAbstractViewport.maybeOf(box);
        if (viewport == null) return;
        final top = box
            .localToGlobal(Offset.zero, ancestor: viewport as RenderObject)
            .dy;
        if (top <= 1) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      final at = (lo - 1).clamp(
        0,
        (indices?.length ?? widget.nodes.length) - 1,
      );
      reader._setVisibleBlock(indices?[at] ?? at);
    });
  }

  Future<bool> reveal(int index, {MarkdownSearchMatch? hit}) async {
    final request = ++_request;
    final pos = _position;
    if (pos == null || !pos.hasContentDimensions) return false;
    var box = _blocks[index];
    if (box == null) {
      final list = _sliverKey.currentContext?.findRenderObject();
      if (list is! _IndexedReaderSliver || list.geometry == null) return false;
      final extent = list.geometry!.scrollExtent;
      final offset = extent * index / widget.nodes.length;
      list.seek(index, offset);
      // The sliver will place this index directly at the seek origin.
      // No intermediate blocks are built or measured along the way.
      pos.jumpTo(
        (list.constraints.precedingScrollExtent + offset).clamp(
          pos.minScrollExtent,
          pos.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || request != _request || _position != pos) return false;
      box = _blocks[index];
    }
    if (box == null || !box.attached || !box.hasSize) return false;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return false;
    final rect = hit == null ? null : box.firstRect(hit);
    final alignment = pos.axisDirection == AxisDirection.up ? 1.0 : 0.0;
    final offset = viewport
        .getOffsetToReveal(box, alignment, rect: rect)
        .offset;
    pos.jumpTo(offset.clamp(pos.minScrollExtent, pos.maxScrollExtent));
    _scheduleSection();
    return true;
  }

  @override
  void dispose() {
    _request++;
    _ready?.complete();
    _position?.removeListener(_scheduleSection);
    reader._detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.document._renderNodes(
    context,
    widget.nodes,
    sliver: widget.sliver,
    blockLayout: (buildBlock, count, spacing) {
      Widget block(BuildContext context, int i) => Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : spacing),
        child: _ReaderBlock(
          owner: this,
          index: i,
          child: buildBlock(context, i),
        ),
      );
      if (widget.sliver) {
        return _ReaderSliverList(
          key: _sliverKey,
          delegate: SliverChildBuilderDelegate(
            block,
            childCount: count,
            addRepaintBoundaries: widget.document.useRepaintBoundary,
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < count; i++) block(context, i)],
      );
    },
  );
}

class _ReaderSliverList extends SliverList {
  const _ReaderSliverList({required super.delegate, super.key});
  @override
  RenderSliverList createRenderObject(BuildContext context) =>
      _IndexedReaderSliver(
        childManager: context as SliverMultiBoxAdaptorElement,
      );
}

/// RenderSliverList ordinarily walks from its nearest laid-out child. For an
/// explicit indexed seek, start the new visible run at the requested block.
/// Ordinary scrolling and variable-height layout stay in RenderSliverList.
class _IndexedReaderSliver extends RenderSliverList {
  _IndexedReaderSliver({required super.childManager});
  int? _target;
  double _offset = 0;
  void seek(int index, double offset) {
    _target = index;
    _offset = offset;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final target = _target;
    if (target != null) {
      _target = null;
      collectGarbage(childCount, 0);
      addInitialChild(index: target, layoutOffset: _offset);
    }
    super.performLayout();
  }
}

class _ReaderBlock extends SingleChildRenderObjectWidget {
  const _ReaderBlock({
    required this.owner,
    required this.index,
    required super.child,
  });
  final _NavigableDocumentState owner;
  final int index;
  @override
  _RenderReaderBlock createRenderObject(BuildContext context) =>
      _RenderReaderBlock(owner, index);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderReaderBlock renderObject,
  ) {
    renderObject.update(owner, index);
  }
}

class _RenderReaderBlock extends RenderProxyBox {
  _RenderReaderBlock(this.viewState, this.index);
  _NavigableDocumentState viewState;
  int index;
  MarkdownReaderController get reader => viewState.reader;

  void update(_NavigableDocumentState next, int at) {
    if (next == viewState && at == index) return;
    if (attached) _unregister();
    viewState = next;
    index = at;
    if (attached) viewState._blocks[index] = this;
    markNeedsPaint();
  }

  void _unregister() {
    if (identical(viewState._blocks[index], this)) {
      viewState._blocks.remove(index);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    viewState._blocks[index] = this;
    viewState._scheduleSection();
  }

  @override
  void detach() {
    _unregister();
    super.detach();
  }

  // Map the index's logical text to shaped glyph boxes. Paint decorations after
  // the child so custom fonts, links, recognizers and selection stay intact.
  void _visitHits(void Function(MarkdownSearchMatch, Rect) visit) {
    final hits = reader._byBlock[index];
    if (hits == null) return;
    final text = reader._texts![index];
    var cursor = 0;
    var firstHit = 0;
    void walk(RenderObject object) {
      InlineSpan? span;
      List<TextBox> Function(TextSelection)? boxes;
      if (object is RenderParagraph) {
        span = object.text;
        boxes = object.getBoxesForSelection;
      } else if (object is RenderEditable) {
        span = object.text;
        boxes = object.getBoxesForSelection;
      }
      if (span == null || boxes == null) {
        object.visitChildren(walk);
        return;
      }
      final plain = span.toPlainText(includeSemanticsLabels: false);
      final pieces = plain.split('\uFFFC');
      final embedded = <RenderObject>[];
      if (pieces.length > 1) object.visitChildren(embedded.add);
      var glyphOffset = 0;
      for (var i = 0; i < pieces.length; i++) {
        final piece = pieces[i];
        if (piece.isNotEmpty) {
          final start = text.indexOf(piece, cursor);
          if (start >= 0) {
            final end = start + piece.length;
            while (firstHit < hits.length && hits[firstHit].end <= start) {
              firstHit++;
            }
            for (
              var h = firstHit;
              h < hits.length && hits[h].start < end;
              h++
            ) {
              final hit = hits[h];
              final selected = TextSelection(
                baseOffset:
                    glyphOffset + (hit.start - start).clamp(0, piece.length),
                extentOffset:
                    glyphOffset + (hit.end - start).clamp(0, piece.length),
              );
              final transform = object.getTransformTo(this);
              for (final glyph in boxes(selected)) {
                visit(
                  hit,
                  MatrixUtils.transformRect(transform, glyph.toRect()),
                );
              }
            }
            cursor = end;
          }
        }
        glyphOffset += piece.length + 1;
        if (i < embedded.length) walk(embedded[i]);
      }
    }

    if (child != null) walk(child!);
  }

  Rect? firstRect(MarkdownSearchMatch match) {
    Rect? result;
    _visitHits((hit, rect) {
      if (hit == match) result ??= rect;
    });
    return result;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!reader._byBlock.containsKey(index)) return;
    final active = reader._active < 0 ? null : reader._matches[reader._active];
    final paint = Paint();
    var painted = false;
    _visitHits((hit, rect) {
      painted = true;
      paint.color = identical(hit, active)
          ? const Color(0x88ff9300)
          : const Color(0x66ffd740);
      context.canvas.drawRect(
        rect.intersect(Offset.zero & size).shift(offset),
        paint,
      );
    });
    // Canvas-rendered formulas, images and custom widgets have no text boxes.
    if (!painted) {
      paint.color = const Color(0x33ffb300);
      context.canvas.drawRect(offset & size, paint);
    }
  }
}
