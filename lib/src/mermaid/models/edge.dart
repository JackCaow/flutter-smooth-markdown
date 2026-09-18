/// Type of arrow head
enum ArrowType {
  /// Standard arrow head -->
  arrow,

  /// Open/no arrow head ---
  none,

  /// Circle end --o
  circle,

  /// Cross end --x
  cross,

  /// Double arrow head <-->
  doubleArrow,
}

/// Type of line
enum LineType {
  /// Solid line ---
  solid,

  /// Dotted line -.-
  dotted,

  /// Thick line ===
  thick,
}

/// UML relationship and ER cardinality endpoint symbols.
enum EdgeMarker {
  inheritance,
  aggregation,
  composition,
  exactlyOne,
  zeroOrOne,
  oneOrMore,
  zeroOrMore,
}

/// Represents an edge/connection between nodes
class MermaidEdge {
  /// Creates a new edge
  const MermaidEdge({
    required this.from,
    required this.to,
    this.label,
    this.arrowType = ArrowType.arrow,
    this.lineType = LineType.solid,
    this.style,
    this.animated = false,
    this.bidirectional = false,
    this.isSubgraphEdge = false,
    this.sourceMarker,
    this.targetMarker,
    this.sourceLabel,
    this.targetLabel,
  });

  /// Source node ID
  final String from;

  /// Target node ID
  final String to;

  /// Optional label on the edge
  final String? label;

  /// Type of arrow at the end
  final ArrowType arrowType;

  /// Type of line
  final LineType lineType;

  /// Custom style
  final EdgeStyle? style;

  /// Whether the edge should be animated
  final bool animated;

  /// Whether the arrow points both ways
  final bool bidirectional;

  /// Whether this edge connects subgraphs (not individual nodes)
  final bool isSubgraphEdge;

  /// Optional typed symbols at each end of the relationship.
  final EdgeMarker? sourceMarker;
  final EdgeMarker? targetMarker;

  /// Multiplicity labels placed next to their respective endpoints.
  final String? sourceLabel;
  final String? targetLabel;

  /// Creates a copy with modified properties
  MermaidEdge copyWith({
    String? from,
    String? to,
    String? label,
    ArrowType? arrowType,
    LineType? lineType,
    EdgeStyle? style,
    bool? animated,
    bool? bidirectional,
    bool? isSubgraphEdge,
    EdgeMarker? sourceMarker,
    EdgeMarker? targetMarker,
    String? sourceLabel,
    String? targetLabel,
  }) {
    return MermaidEdge(
      from: from ?? this.from,
      to: to ?? this.to,
      label: label ?? this.label,
      arrowType: arrowType ?? this.arrowType,
      lineType: lineType ?? this.lineType,
      style: style ?? this.style,
      animated: animated ?? this.animated,
      bidirectional: bidirectional ?? this.bidirectional,
      isSubgraphEdge: isSubgraphEdge ?? this.isSubgraphEdge,
      sourceMarker: sourceMarker ?? this.sourceMarker,
      targetMarker: targetMarker ?? this.targetMarker,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      targetLabel: targetLabel ?? this.targetLabel,
    );
  }

  @override
  String toString() => 'MermaidEdge($from -> $to, label: $label)';
}

/// Style configuration for an edge
class EdgeStyle {
  /// Creates an edge style
  const EdgeStyle({
    this.strokeColor,
    this.strokeWidth = 1.5,
    this.labelColor,
    this.labelFontSize = 12.0,
    this.labelBackgroundColor,
    this.dashPattern,
  });

  /// Line color (as ARGB int)
  final int? strokeColor;

  /// Line width
  final double strokeWidth;

  /// Label text color (as ARGB int)
  final int? labelColor;

  /// Label font size
  final double labelFontSize;

  /// Label background color (as ARGB int)
  final int? labelBackgroundColor;

  /// Custom dash pattern for the line
  final List<double>? dashPattern;

  /// Creates a copy with modified properties
  EdgeStyle copyWith({
    int? strokeColor,
    double? strokeWidth,
    int? labelColor,
    double? labelFontSize,
    int? labelBackgroundColor,
    List<double>? dashPattern,
  }) {
    return EdgeStyle(
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      labelColor: labelColor ?? this.labelColor,
      labelFontSize: labelFontSize ?? this.labelFontSize,
      labelBackgroundColor: labelBackgroundColor ?? this.labelBackgroundColor,
      dashPattern: dashPattern ?? this.dashPattern,
    );
  }
}

/// Represents a message in a sequence diagram
class SequenceMessage extends MermaidEdge {
  /// Creates a sequence message
  const SequenceMessage({
    required super.from,
    required super.to,
    super.label,
    super.arrowType = ArrowType.arrow,
    super.lineType = LineType.solid,
    this.messageType = MessageType.sync,
    this.activate = false,
    this.deactivate = false,
  });

  /// Type of message
  final MessageType messageType;

  /// Whether to activate the target
  final bool activate;

  /// Whether to deactivate the target
  final bool deactivate;
}

/// Types of messages in sequence diagrams
enum MessageType {
  /// Synchronous message ->>
  sync,

  /// Asynchronous message -)
  async,

  /// Reply message -->>
  reply,

  /// Async reply --)
  asyncReply,
}
