import 'node.dart';
import 'edge.dart';
import 'style.dart';

/// Direction of the diagram flow
enum DiagramDirection {
  /// Top to Bottom
  topToBottom,

  /// Bottom to Top
  bottomToTop,

  /// Left to Right
  leftToRight,

  /// Right to Left
  rightToLeft,
}

/// Type of diagram
enum DiagramType {
  /// Flowchart diagram
  flowchart,

  /// Sequence diagram
  sequence,

  /// Class diagram
  classDiagram,

  /// State diagram
  stateDiagram,

  /// Entity relationship diagram
  erDiagram,

  /// Pie chart diagram
  pieChart,

  /// Gantt chart diagram
  ganttChart,

  /// Timeline diagram
  timeline,

  /// Kanban board diagram
  kanban,

  /// Radar chart diagram
  radar,

  /// XY chart diagram
  xyChart,

  /// Unknown/unsupported type
  unknown,
}

/// Represents a parsed Mermaid diagram
class MermaidDiagramData {
  /// Creates a new diagram data
  const MermaidDiagramData({
    required this.type,
    required this.nodes,
    required this.edges,
    this.direction = DiagramDirection.topToBottom,
    this.subgraphs = const [],
    this.style = const MermaidStyle(),
    this.title,
  });

  /// Type of this diagram
  final DiagramType type;

  /// All nodes in the diagram
  final List<MermaidNode> nodes;

  /// All edges connecting nodes
  final List<MermaidEdge> edges;

  /// Direction of the diagram flow
  final DiagramDirection direction;

  /// Subgraphs (nested containers)
  final List<Subgraph> subgraphs;

  /// Style configuration
  final MermaidStyle style;

  /// Optional title
  final String? title;

  /// Gets a node by its ID
  MermaidNode? getNode(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  /// Creates a copy with modified properties
  MermaidDiagramData copyWith({
    DiagramType? type,
    List<MermaidNode>? nodes,
    List<MermaidEdge>? edges,
    DiagramDirection? direction,
    List<Subgraph>? subgraphs,
    MermaidStyle? style,
    String? title,
  }) {
    return MermaidDiagramData(
      type: type ?? this.type,
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      direction: direction ?? this.direction,
      subgraphs: subgraphs ?? this.subgraphs,
      style: style ?? this.style,
      title: title ?? this.title,
    );
  }
}

/// Represents a subgraph container
class Subgraph {
  /// Creates a new subgraph
  const Subgraph({
    required this.id,
    required this.label,
    required this.nodeIds,
    this.style,
  });

  /// Unique identifier
  final String id;

  /// Display label
  final String label;

  /// IDs of nodes contained in this subgraph
  final List<String> nodeIds;

  /// Optional custom style
  final SubgraphStyle? style;
}

/// Style for subgraphs
class SubgraphStyle {
  /// Creates a subgraph style
  const SubgraphStyle({
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius = 4.0,
    this.padding = 16.0,
  });

  /// Background color
  final int? backgroundColor;

  /// Border color
  final int? borderColor;

  /// Border width
  final double borderWidth;

  /// Border radius
  final double borderRadius;

  /// Padding inside the subgraph
  final double padding;
}
