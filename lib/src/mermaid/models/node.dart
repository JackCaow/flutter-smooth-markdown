import 'dart:ui';

/// Shape types for nodes
enum NodeShape {
  /// Rectangle with square corners [text]
  rectangle,

  /// Rectangle with rounded corners (text)
  roundedRect,

  /// Stadium/pill shape ([text])
  stadium,

  /// Diamond/rhombus shape {text}
  diamond,

  /// Hexagon shape {{text}}
  hexagon,

  /// Circle shape ((text))
  circle,

  /// Parallelogram shape [/text/]
  parallelogram,

  /// Parallelogram (alt) shape [\text\]
  parallelogramAlt,

  /// Trapezoid shape [/text\]
  trapezoid,

  /// Trapezoid (alt) shape [\text/]
  trapezoidAlt,

  /// Cylinder/database shape [(text)]
  cylinder,

  /// Subroutine shape [[text]]
  subroutine,

  /// Asymmetric shape >text]
  asymmetric,

  /// Double circle (for state diagrams)
  doubleCircle,

  /// Filled initial-state marker.
  stateStart,

  /// Final-state marker (filled circle inside a ring).
  stateEnd,
}

/// Represents a node in a Mermaid diagram
class MermaidNode {
  /// Creates a new node
  MermaidNode({
    required this.id,
    required this.label,
    this.shape = NodeShape.rectangle,
    this.style,
    this.className,
    this.link,
    this.tooltip,
    this.compartments = const [],
  });

  /// Unique identifier for this node
  final String id;

  /// Display label
  final String label;

  /// Rows below the heading, grouped into UML/ER compartments.
  final List<List<String>> compartments;

  /// Shape of the node
  final NodeShape shape;

  /// Custom inline style
  final NodeStyle? style;

  /// CSS class name for styling
  final String? className;

  /// Optional link URL
  final String? link;

  /// Optional tooltip text
  final String? tooltip;

  // Layout properties (set by layout engine)
  /// X position after layout
  double x = 0;

  /// Y position after layout
  double y = 0;

  /// Width after measurement
  double width = 0;

  /// Height after measurement
  double height = 0;

  /// Layer/rank in the graph (for hierarchical layout)
  int rank = 0;

  /// Order within the layer
  int order = 0;

  /// Creates a copy with modified properties
  MermaidNode copyWith({
    String? id,
    String? label,
    NodeShape? shape,
    NodeStyle? style,
    String? className,
    String? link,
    String? tooltip,
    List<List<String>>? compartments,
  }) {
    return MermaidNode(
      id: id ?? this.id,
      label: label ?? this.label,
      shape: shape ?? this.shape,
      style: style ?? this.style,
      className: className ?? this.className,
      link: link ?? this.link,
      tooltip: tooltip ?? this.tooltip,
      compartments: compartments ?? this.compartments,
    );
  }

  @override
  String toString() => 'MermaidNode($id: $label, shape: $shape)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MermaidNode && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Style configuration for a node
class NodeStyle {
  /// Creates a node style
  const NodeStyle({
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1.0,
    this.textColor,
    this.fontSize = 14.0,
    this.fontWeight,
    this.borderRadius = 4.0,
  });

  /// Fill/background color (as ARGB int)
  final int? fillColor;

  /// Border/stroke color (as ARGB int)
  final int? strokeColor;

  /// Border width
  final double strokeWidth;

  /// Text color (as ARGB int)
  final int? textColor;

  /// Font size
  final double fontSize;

  /// Font weight
  final FontWeight? fontWeight;

  /// Border radius for rectangular shapes
  final double borderRadius;

  /// Creates a copy with modified properties
  NodeStyle copyWith({
    int? fillColor,
    int? strokeColor,
    double? strokeWidth,
    int? textColor,
    double? fontSize,
    FontWeight? fontWeight,
    double? borderRadius,
  }) {
    return NodeStyle(
      fillColor: fillColor ?? this.fillColor,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      textColor: textColor ?? this.textColor,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}

/// Represents a participant in a sequence diagram
class SequenceParticipant extends MermaidNode {
  /// Creates a sequence participant
  SequenceParticipant({
    required super.id,
    required super.label,
    this.participantType = ParticipantType.participant,
    super.style,
  }) : super(shape: _getShape(participantType));

  /// Type of participant
  final ParticipantType participantType;

  static NodeShape _getShape(ParticipantType type) {
    switch (type) {
      case ParticipantType.actor:
        return NodeShape.circle;
      case ParticipantType.participant:
        return NodeShape.rectangle;
      case ParticipantType.database:
        return NodeShape.cylinder;
    }
  }
}

/// Types of participants in sequence diagrams
enum ParticipantType {
  /// Regular participant (box)
  participant,

  /// Actor (stick figure)
  actor,

  /// Database (cylinder)
  database,
}
