import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../parser/ast/markdown_node.dart';

/// Internal owner of retained block widgets and lazily built layout pages.
/// Pages own only their node slice, never a closure over an old full snapshot.
class StreamBlockCache extends MapBase<MarkdownNode, Widget> {
  final _widgets = Map<MarkdownNode, Widget>.identity();
  List<MarkdownNode> _nodes = const [];
  final _pages = <Widget>[];
  static const pageSize = 32;
  int _renderRevision = 0;
  bool owns(List<MarkdownNode> nodes) => identical(_nodes, nodes);

  void updateNodes(List<MarkdownNode> nodes, int retained) {
    // Host/context invalidation clears the old snapshot independently of the
    // parser. In that case every page must be rebuilt with the new context.
    retained = retained.clamp(0, _nodes.length);
    if (_widgets.isNotEmpty) {
      for (var i = retained; i < _nodes.length; i++) {
        _widgets.remove(_nodes[i]);
      }
    }
    final complete = retained ~/ pageSize;
    if (_pages.length > complete) _pages.length = complete;
    _nodes = nodes;
  }

  Widget layout(
    Widget Function(MarkdownNode) build,
    double spacing, {
    required bool sliver,
  }) {
    if (sliver) {
      // Each delegate reads its immutable publication. Only mounted blocks
      // retain their built widgets, including the viewport's cache extent.
      final nodes = _nodes;
      final revision = _renderRevision;
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, index) => _ViewportBlock(
            node: nodes[index],
            renderNode: build,
            revision: revision,
            leadingSpace: index == 0 ? 0 : spacing,
          ),
          childCount: nodes.length,
        ),
      );
    }
    final count = (_nodes.length + pageSize - 1) ~/ pageSize;
    while (_pages.length < count) {
      final page = _pages.length;
      final start = page * pageSize;
      final end = (start + pageSize).clamp(0, _nodes.length);
      final nodes = _nodes.sublist(start, end);
      _pages.add(
        _StreamBlockPage(
          key: ValueKey(page),
          owner: this,
          nodes: nodes,
          renderNode: build,
          spacing: spacing,
          leadingSpace: start != 0,
        ),
      );
    }
    // A publication owns its directory; changing the owner's tail cannot
    // mutate a widget tree still being reconciled by Flutter.
    final pages = List<Widget>.of(_pages, growable: false);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: pages,
    );
  }

  @override
  Widget? operator [](Object? key) => _widgets[key];
  @override
  void operator []=(MarkdownNode key, Widget value) => _widgets[key] = value;
  @override
  Iterable<MarkdownNode> get keys => _widgets.keys;
  @override
  Widget? remove(Object? key) => _widgets.remove(key);
  @override
  void clear() {
    _renderRevision++;
    _widgets.clear();
    _nodes = const [];
    _pages.clear();
  }
}

// A tail publication preserves the identity of committed nodes. Keep their
// widget only for as long as Flutter keeps this sliver child mounted.
class _ViewportBlock extends StatefulWidget {
  const _ViewportBlock({
    required this.node,
    required this.renderNode,
    required this.revision,
    required this.leadingSpace,
  });

  final MarkdownNode node;
  final Widget Function(MarkdownNode) renderNode;
  final int revision;
  final double leadingSpace;

  @override
  State<_ViewportBlock> createState() => _ViewportBlockState();
}

class _ViewportBlockState extends State<_ViewportBlock> {
  Widget? _content;

  @override
  void didUpdateWidget(_ViewportBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.node, oldWidget.node) ||
        widget.revision != oldWidget.revision) {
      _content = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _content ??= widget.renderNode(widget.node);
    return widget.leadingSpace == 0
        ? child
        : Padding(
            padding: EdgeInsets.only(top: widget.leadingSpace),
            child: child,
          );
  }
}

// A separate widget keeps lazy closures from retaining an old page directory.
class _StreamBlockPage extends StatelessWidget {
  const _StreamBlockPage({
    required this.owner,
    required this.nodes,
    required this.renderNode,
    required this.spacing,
    required this.leadingSpace,
    super.key,
  });
  final StreamBlockCache owner;
  final List<MarkdownNode> nodes;
  final Widget Function(MarkdownNode) renderNode;
  final double spacing;
  final bool leadingSpace;
  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      if (leadingSpace || i != 0) children.add(SizedBox(height: spacing));
      children.add(
        owner._widgets.putIfAbsent(nodes[i], () => renderNode(nodes[i])),
      );
    }
    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
