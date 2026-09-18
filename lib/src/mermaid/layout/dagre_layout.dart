import 'dart:math' as math;
import 'package:flutter/painting.dart';

import '../config/responsive_config.dart';
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';
import '../models/style.dart';
import 'layout_engine.dart';

/// Dagre-style hierarchical graph layout algorithm
///
/// This implements a simplified version of the Dagre layout algorithm
/// which is used by Mermaid.js for rendering flowcharts.
class DagreLayout extends LayoutEngine {
  /// Creates a Dagre layout engine
  const DagreLayout({this.deviceConfig});

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  @override
  Size computeLayout(
    MermaidDiagramData diagram,
    MermaidStyle style,
    Size availableSize,
  ) {
    if (diagram.nodes.isEmpty) return Size.zero;

    // Check if we have subgraphs
    if (diagram.subgraphs.isNotEmpty) {
      return _computeSubgraphLayout(diagram, style, availableSize);
    }

    final context = _LayoutContext(diagram, style);

    // Step 1: Measure all nodes
    _measureNodes(context);

    // Step 2: Build graph structure
    _buildGraph(context);

    // Step 3: Assign ranks using topological sort (BFS)
    _assignRanks(context);

    // Step 4: Order nodes within layers to minimize crossings
    _orderNodes(context);

    // Step 5: Assign coordinates
    final size = _assignCoordinates(context);
    return _reserveEdgeSpace(diagram, style, size);
  }

  Size _reserveEdgeSpace(
      MermaidDiagramData diagram, MermaidStyle style, Size size) {
    // Cycles are routed 40px outside the nodes; leave room for those curves
    // and self transitions rather than clipping them at the canvas edge.
    if (diagram.edges.any((edge) =>
            edge.from == edge.to ||
            ((edge.sourceMarker != null || edge.targetMarker != null) &&
                edge.label != null &&
                edge.label!.isNotEmpty)) ||
        diagram.edges.any((edge) =>
            (diagram.getNode(edge.to)?.rank ?? 0) -
                (diagram.getNode(edge.from)?.rank ?? 0) !=
            1)) {
      var marginX = 40.0;
      var marginY = 40.0;
      for (final edge in diagram.edges) {
        if (edge.label == null || edge.label!.isEmpty) continue;
        final fontSize = (edge.style ?? style.defaultEdgeStyle).labelFontSize;
        marginX =
            math.max(marginX, _measureTextWidth(edge.label!, fontSize) + 60);
        marginY = math.max(
            marginY, fontSize * 1.4 * edge.label!.split('\n').length + 60);
      }
      for (final node in diagram.nodes) {
        node.x += marginX;
        node.y += marginY;
      }
      return Size(size.width + marginX * 2, size.height + marginY * 2);
    }
    return size;
  }

  /// Computes layout for diagrams with subgraphs
  Size _computeSubgraphLayout(
    MermaidDiagramData diagram,
    MermaidStyle style,
    Size availableSize,
  ) {
    // Lay out each outermost cluster, then rank clusters AND standalone nodes
    // together. Keeping proxy sizes avoids crushing a cluster into one node.
    final groups = diagram.subgraphs;
    bool contains(Subgraph parent, Subgraph child) =>
        parent.nodeIds.toSet().containsAll(child.nodeIds) &&
        (parent.nodeIds.length > child.nodeIds.length ||
            groups.indexOf(parent) > groups.indexOf(child));
    final roots = groups
        .where((g) => !groups.any((other) => other != g && contains(other, g)))
        .toList();
    final owners = <String, String>{};
    final proxies = <MermaidNode>[];
    final members = <String, List<MermaidNode>>{};
    for (final group in roots) {
      final nodes =
          diagram.nodes.where((n) => group.nodeIds.contains(n.id)).toList();
      if (nodes.isEmpty) continue;
      final children =
          groups.where((g) => g != group && contains(group, g)).toList();
      final ids = {...group.nodeIds, ...children.map((g) => g.id)};
      final inner = diagram.copyWith(
          nodes: nodes,
          subgraphs: children,
          edges: diagram.edges
              .where((e) => ids.contains(e.from) && ids.contains(e.to))
              .toList());
      // 20px border padding and 30px title match the subgraph painter.
      final innerSize =
          computeLayout(inner, style.copyWith(padding: 20), availableSize);
      final proxy = MermaidNode(id: '\$cluster:${group.id}', label: group.label)
        ..width =
            math.max(innerSize.width, _measureTextWidth(group.label, 14) + 40)
        ..height = innerSize.height + 30;
      final titleOffset = (proxy.width - innerSize.width) / 2;
      for (final node in nodes) {
        node.x += titleOffset;
        node.y += 30;
        owners[node.id] = proxy.id;
      }
      owners[group.id] = proxy.id;
      for (final child in children) {
        owners[child.id] = proxy.id;
      }
      members[proxy.id] = nodes;
      proxies.add(proxy);
    }
    for (final node in diagram.nodes.where((n) => !owners.containsKey(n.id))) {
      final size = measureNodeWithShape(node, style);
      node.width = size.width;
      node.height = size.height;
      proxies.add(node);
    }
    final outerEdges = <MermaidEdge>[];
    for (final edge in diagram.edges) {
      final from = owners[edge.from] ?? edge.from;
      final to = owners[edge.to] ?? edge.to;
      if (from != to) outerEdges.add(edge.copyWith(from: from, to: to));
    }
    final context = _LayoutContext(
        diagram
            .copyWith(nodes: proxies, edges: outerEdges, subgraphs: const []),
        style);
    _buildGraph(context);
    _assignRanks(context);
    _orderNodes(context);
    final size = _assignCoordinates(context);
    for (final proxy in proxies) {
      for (final node in members[proxy.id] ?? <MermaidNode>[]) {
        node.x += proxy.x;
        node.y += proxy.y;
      }
    }
    return _reserveEdgeSpace(diagram, style, size);
  }

  void _measureNodes(_LayoutContext context) {
    for (final node in context.diagram.nodes) {
      final size = measureNodeWithShape(node, context.style);
      node.width = size.width;
      node.height = size.height;
    }
  }

  /// Measures node size considering shape requirements
  Size measureNodeWithShape(MermaidNode node, MermaidStyle style) {
    final nodeStyle = style.getNodeStyle(node.className);
    final fontSize = nodeStyle.fontSize;

    // Calculate text dimensions
    if (node.shape == NodeShape.stateStart ||
        node.shape == NodeShape.stateEnd) {
      return const Size(24, 24);
    }
    final lines = [
      ...node.label.split('\n'),
      ...node.compartments.expand((p) => p)
    ];
    final textWidth = lines
        .map((line) => _measureTextWidth(line, fontSize,
            fontWeight: node.compartments.isNotEmpty &&
                    node.label.split('\n').contains(line)
                ? FontWeight.bold
                : nodeStyle.fontWeight))
        .reduce(math.max);
    final textHeight = fontSize *
            1.4 *
            (node.label.split('\n').length +
                node.compartments.fold<int>(
                    0, (count, rows) => count + math.max(1, rows.length))) +
        node.compartments.length * 12;

    // Shape-specific sizing
    switch (node.shape) {
      case NodeShape.diamond:
        // Diamond needs extra space for the rotated square
        final innerWidth = textWidth + 20;
        final innerHeight = textHeight + 12;
        final size = math.max(innerWidth, innerHeight) * 1.5;
        return Size(math.max(size, 90), math.max(size * 0.8, 70));

      case NodeShape.circle:
      case NodeShape.doubleCircle:
        final diameter = math.max(textWidth, textHeight) + 40;
        return Size(diameter, diameter);

      case NodeShape.hexagon:
        return Size(textWidth + 60, textHeight + 32);

      case NodeShape.stadium:
        return Size(textWidth + 40, textHeight + 24);

      case NodeShape.cylinder:
        return Size(textWidth + 32, textHeight + 40);

      case NodeShape.parallelogram:
      case NodeShape.parallelogramAlt:
        return Size(textWidth + 50, textHeight + 20);

      case NodeShape.trapezoid:
      case NodeShape.trapezoidAlt:
        return Size(textWidth + 40, textHeight + 20);

      case NodeShape.subroutine:
        return Size(textWidth + 40, textHeight + 20);

      case NodeShape.roundedRect:
        return Size(textWidth + 32, textHeight + 20);

      default:
        // Rectangle
        return Size(textWidth + 28, textHeight + 16);
    }
  }

  double _measureTextWidth(String text, double fontSize,
      {FontWeight? fontWeight}) {
    final painter = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(fontSize: fontSize, fontWeight: fontWeight)),
        textDirection: TextDirection.ltr)
      ..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  void _buildGraph(_LayoutContext context) {
    // Initialize adjacency lists
    for (final node in context.diagram.nodes) {
      context.successors[node.id] = [];
      context.predecessors[node.id] = [];
    }

    // Build edges, handling back-edges (cycles)
    for (final edge in context.diagram.edges) {
      if (!context.nodeMap.containsKey(edge.from) ||
          !context.nodeMap.containsKey(edge.to)) continue;
      context.successors[edge.from]?.add(edge.to);
      context.predecessors[edge.to]?.add(edge.from);
    }

    // Find root nodes (no incoming edges)
    context.roots = context.diagram.nodes
        .where((n) => context.predecessors[n.id]?.isEmpty ?? true)
        .map((n) => n.id)
        .toList();

    // If no roots found (all cycles), use first node
    if (context.roots.isEmpty && context.diagram.nodes.isNotEmpty) {
      context.roots = [context.diagram.nodes.first.id];
    }
  }

  /// Assign ranks using BFS from roots, ignoring back-edges
  /// This follows the standard Mermaid/Dagre approach
  void _assignRanks(_LayoutContext context) {
    final ranks = <String, int>{};

    // First pass: identify back-edges by doing DFS to find cycles
    final backEdges = <String, Set<String>>{};
    final visited = <String>{};
    final inStack = <String>{};

    void findBackEdges(String nodeId) {
      if (visited.contains(nodeId)) return;
      visited.add(nodeId);
      inStack.add(nodeId);

      for (final succId in context.successors[nodeId] ?? <String>[]) {
        if (inStack.contains(succId)) {
          // This is a back-edge
          backEdges[nodeId] ??= {};
          backEdges[nodeId]!.add(succId);
        } else if (!visited.contains(succId)) {
          findBackEdges(succId);
        }
      }

      inStack.remove(nodeId);
    }

    // Find all back-edges
    for (final root in context.roots) {
      findBackEdges(root);
    }
    // Also check from any unvisited nodes
    for (final node in context.diagram.nodes) {
      if (!visited.contains(node.id)) {
        findBackEdges(node.id);
      }
    }

    // Helper to check if an edge is a back-edge
    bool isBackEdge(String from, String to) {
      return (backEdges[from] ?? {}).contains(to);
    }

    // Topological longest-path ranks: a join must follow ALL predecessors,
    // including a longer branch that is visited after a shorter branch.
    final queue = <String>[];
    final remaining = <String, int>{};
    for (final node in context.diagram.nodes) {
      remaining[node.id] = (context.predecessors[node.id] ?? [])
          .where((pred) => !isBackEdge(pred, node.id))
          .length;
      ranks[node.id] = 0;
      if (remaining[node.id] == 0) {
        queue.add(node.id);
      }
    }
    while (queue.isNotEmpty) {
      final nodeId = queue.removeAt(0);
      final currentRank = ranks[nodeId]!;

      // Get all successors that are not back-edges
      final successors = (context.successors[nodeId] ?? <String>[])
          .where((succId) => !isBackEdge(nodeId, succId))
          .toList();

      for (final succId in successors) {
        final newRank = currentRank + 1;

        ranks[succId] = math.max(ranks[succId] ?? 0, newRank);
        remaining[succId] = remaining[succId]! - 1;
        if (remaining[succId] == 0) {
          queue.add(succId);
        }
      }
    }

    // Handle any unranked nodes
    final maxRank = ranks.values.isEmpty ? 0 : ranks.values.reduce(math.max);
    for (final node in context.diagram.nodes) {
      if (!ranks.containsKey(node.id)) {
        ranks[node.id] = maxRank + 1;
      }
    }

    // Apply ranks to nodes
    for (final node in context.diagram.nodes) {
      node.rank = ranks[node.id] ?? 0;
    }

    // Group nodes by rank
    context.layers.clear();
    for (final node in context.diagram.nodes) {
      while (context.layers.length <= node.rank) {
        context.layers.add([]);
      }
      context.layers[node.rank].add(node);
    }

    // Store back-edges info for edge drawing
    context.backEdges = backEdges;
  }

  void _orderNodes(_LayoutContext context) {
    if (context.layers.isEmpty) return;

    // Build edge order map - tracks the order of successors for each node
    final edgeOrder = <String, Map<String, int>>{};
    for (final node in context.diagram.nodes) {
      edgeOrder[node.id] = {};
      final succs = context.successors[node.id] ?? [];
      for (var i = 0; i < succs.length; i++) {
        edgeOrder[node.id]![succs[i]] = i;
      }
    }

    // Initial ordering: preserve edge definition order from parent
    for (var layerIdx = 0; layerIdx < context.layers.length; layerIdx++) {
      final layer = context.layers[layerIdx];

      if (layerIdx == 0) {
        // First layer: use original order
        for (var i = 0; i < layer.length; i++) {
          layer[i].order = i;
        }
      } else {
        // Order by parent's edge order
        final prevLayer = context.layers[layerIdx - 1];
        layer.sort((a, b) {
          // Find common parent and compare edge order
          for (final pred in prevLayer) {
            final orderA = edgeOrder[pred.id]?[a.id];
            final orderB = edgeOrder[pred.id]?[b.id];
            if (orderA != null && orderB != null) {
              return orderA.compareTo(orderB);
            }
          }
          // If no common parent, use barycenter
          return 0;
        });

        for (var i = 0; i < layer.length; i++) {
          layer[i].order = i;
        }
      }
    }

    // Refine with barycenter heuristic (fewer iterations to preserve initial order)
    for (var iter = 0; iter < 4; iter++) {
      // Forward sweep (top to bottom)
      for (var i = 1; i < context.layers.length; i++) {
        _orderLayerByBarycenter(
          context.layers[i],
          context.layers[i - 1],
          context.predecessors,
        );
      }

      // Backward sweep (bottom to top)
      for (var i = context.layers.length - 2; i >= 0; i--) {
        _orderLayerByBarycenter(
          context.layers[i],
          context.layers[i + 1],
          context.successors,
        );
      }
    }

    // Final order assignment
    for (final layer in context.layers) {
      for (var i = 0; i < layer.length; i++) {
        layer[i].order = i;
      }
    }
  }

  void _orderLayerByBarycenter(
    List<MermaidNode> layer,
    List<MermaidNode> adjacentLayer,
    Map<String, List<String>> connections,
  ) {
    if (layer.isEmpty || adjacentLayer.isEmpty) return;

    // Build position map for adjacent layer
    final posMap = <String, double>{};
    for (var i = 0; i < adjacentLayer.length; i++) {
      posMap[adjacentLayer[i].id] = i.toDouble();
    }

    // Calculate barycenter for each node
    final barycenters = <MermaidNode, double>{};
    for (final node in layer) {
      final connected = connections[node.id] ?? [];
      final positions = connected
          .where((id) => posMap.containsKey(id))
          .map((id) => posMap[id]!)
          .toList();

      if (positions.isEmpty) {
        // Keep relative position
        barycenters[node] = node.order.toDouble();
      } else {
        // Average position of connected nodes
        barycenters[node] =
            positions.reduce((a, b) => a + b) / positions.length;
      }
    }

    // Sort by barycenter
    layer.sort((a, b) => barycenters[a]!.compareTo(barycenters[b]!));

    // Update order
    for (var i = 0; i < layer.length; i++) {
      layer[i].order = i;
    }
  }

  Size _assignCoordinates(_LayoutContext context) {
    final direction = context.diagram.direction;
    final isHorizontal = direction == DiagramDirection.leftToRight ||
        direction == DiagramDirection.rightToLeft;

    final style = context.style;
    // Increase spacing for better readability
    var rankSep =
        (isHorizontal ? style.nodeSpacingX : style.nodeSpacingY) * 1.2;
    for (final edge in context.diagram.edges) {
      if (edge.from == edge.to || edge.label == null || edge.label!.isEmpty)
        continue;
      final fontSize = (edge.style ?? style.defaultEdgeStyle).labelFontSize;
      final mainSize = isHorizontal
          ? _measureTextWidth(edge.label!, fontSize)
          : fontSize * 1.4 * edge.label!.split('\n').length;
      rankSep = math.max(rankSep, mainSize + 24);
    }
    final nodeSep =
        (isHorizontal ? style.nodeSpacingY : style.nodeSpacingX) * 1.0;

    // Calculate max width for each layer (for centering)
    final layerMaxSizes = <double>[];
    double maxLayerWidth = 0;

    for (final layer in context.layers) {
      double layerWidth = 0;
      double layerHeight = 0;

      for (final node in layer) {
        if (isHorizontal) {
          layerHeight += node.height + nodeSep;
          layerWidth = math.max(layerWidth, node.width);
        } else {
          layerWidth += node.width + nodeSep;
          layerHeight = math.max(layerHeight, node.height);
        }
      }

      if (isHorizontal) {
        layerHeight -= nodeSep;
        layerMaxSizes.add(layerWidth);
        maxLayerWidth = math.max(maxLayerWidth, layerHeight);
      } else {
        layerWidth -= nodeSep;
        layerMaxSizes.add(layerHeight);
        maxLayerWidth = math.max(maxLayerWidth, layerWidth);
      }
    }

    // Position nodes
    double mainOffset = style.padding;
    double totalWidth = 0;
    double totalHeight = 0;

    for (var layerIdx = 0; layerIdx < context.layers.length; layerIdx++) {
      final layer = context.layers[layerIdx];

      // Calculate layer's total cross size
      double layerCrossSize = 0;
      for (final node in layer) {
        layerCrossSize += (isHorizontal ? node.height : node.width) + nodeSep;
      }
      layerCrossSize -= nodeSep;

      // Center the layer
      double crossOffset = style.padding + (maxLayerWidth - layerCrossSize) / 2;

      for (final node in layer) {
        if (isHorizontal) {
          node.x = mainOffset;
          node.y = crossOffset;
          crossOffset += node.height + nodeSep;
          totalHeight = math.max(totalHeight, node.y + node.height);
        } else {
          node.x = crossOffset;
          node.y = mainOffset;
          crossOffset += node.width + nodeSep;
          totalWidth = math.max(totalWidth, node.x + node.width);
        }
      }

      // Move to next layer
      final maxMain = layer.isEmpty
          ? 0.0
          : layer
              .map((n) => isHorizontal ? n.width : n.height)
              .reduce(math.max);
      mainOffset += maxMain + rankSep;
    }

    if (isHorizontal) {
      totalWidth = mainOffset - rankSep + style.padding;
      totalHeight += style.padding;
    } else {
      totalHeight = mainOffset - rankSep + style.padding;
      totalWidth += style.padding;
    }

    // Apply direction reversal
    if (direction == DiagramDirection.rightToLeft) {
      for (final node in context.diagram.nodes) {
        node.x = totalWidth - node.x - node.width;
      }
    } else if (direction == DiagramDirection.bottomToTop) {
      for (final node in context.diagram.nodes) {
        node.y = totalHeight - node.y - node.height;
      }
    }

    return Size(totalWidth, totalHeight);
  }
}

/// Internal context for layout computation
class _LayoutContext {
  _LayoutContext(this.diagram, this.style) {
    nodeMap = {for (final n in diagram.nodes) n.id: n};
  }

  final MermaidDiagramData diagram;
  final MermaidStyle style;

  late final Map<String, MermaidNode> nodeMap;
  final Map<String, List<String>> successors = {};
  final Map<String, List<String>> predecessors = {};
  List<String> roots = [];
  final List<List<MermaidNode>> layers = [];
  Map<String, Set<String>> backEdges = {};
}
