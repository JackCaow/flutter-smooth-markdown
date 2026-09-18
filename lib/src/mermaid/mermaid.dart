/// Pure Dart Mermaid diagram renderer for Flutter
///
/// This library provides a complete implementation of Mermaid diagram
/// rendering using only Dart and Flutter's CustomPainter, without
/// any WebView or external API dependencies.
///
/// Supported diagram types:
/// - Flowchart (graph TD/LR/BT/RL)
/// - Sequence diagram
/// - Pie chart
/// - Gantt chart
/// - Timeline
/// - Class diagram (basic)
/// - State diagram (basic)
/// - Entity relationship diagram (basic)
///
/// See docs/mermaid-structured-diagrams.md for syntax coverage and limitations.
///
/// Example usage:
/// ```dart
/// MermaidDiagram(
///   code: '''
///   graph TD
///     A[Start] --> B{Decision}
///     B -->|Yes| C[OK]
///     B -->|No| D[Cancel]
///   ''',
/// )
/// ```
///
/// Pie chart example:
/// ```dart
/// MermaidDiagram(
///   code: '''
///   pie
///     title Favorite Pets
///     "Dogs" : 386
///     "Cats" : 85
///     "Birds" : 15
///   ''',
/// )
/// ```
///
/// Timeline example:
/// ```dart
/// MermaidDiagram(
///   code: '''
///   timeline
///     title History of Social Media Platform
///     2002 : LinkedIn
///     2004 : Facebook
///          : Google
///     2005 : Youtube
///     2006 : Twitter
///   ''',
/// )
/// ```

export 'config/responsive_config.dart';
export 'layout/layout_engine.dart';
export 'layout/sugiyama_layout.dart';
export 'models/diagram.dart';
export 'models/edge.dart';
export 'models/gantt.dart';
export 'models/kanban.dart';
export 'models/node.dart';
export 'models/pie_chart.dart';
export 'models/timeline.dart';
export 'models/style.dart';
export 'painter/flowchart_painter.dart';
export 'painter/gantt_painter.dart';
export 'painter/kanban_painter.dart';
export 'painter/mermaid_painter.dart';
export 'painter/pie_chart_painter.dart';
export 'painter/sequence_painter.dart';
export 'painter/timeline_painter.dart';
export 'parser/flowchart_parser.dart';
export 'parser/gantt_parser.dart';
export 'parser/kanban_parser.dart';
export 'parser/mermaid_parser.dart';
export 'parser/pie_chart_parser.dart';
export 'parser/sequence_parser.dart';
export 'parser/timeline_parser.dart';
export 'widgets/mermaid_diagram.dart';
