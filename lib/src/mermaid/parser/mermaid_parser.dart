import '../models/diagram.dart';
import '../models/gantt.dart';
import '../models/kanban.dart';
import '../models/pie_chart.dart';
import '../models/radar.dart';
import '../models/timeline.dart';
import '../models/xy_chart.dart';
import 'flowchart_parser.dart';
import 'gantt_parser.dart';
import 'kanban_parser.dart';
import 'pie_chart_parser.dart';
import 'radar_parser.dart';
import 'sequence_parser.dart';
import 'structured_graph_parser.dart';
import 'timeline_parser.dart';
import 'xy_chart_parser.dart';

/// Result of parsing a Mermaid diagram
class MermaidParseResult {
  /// Creates a parse result
  const MermaidParseResult({
    required this.diagram,
    this.pieChartData,
    this.ganttChartData,
    this.timelineChartData,
    this.kanbanChartData,
    this.radarChartData,
    this.xyChartData,
  });

  /// The parsed diagram data
  final MermaidDiagramData diagram;

  /// Pie chart specific data (only set for pie charts)
  final PieChartData? pieChartData;

  /// Gantt chart specific data (only set for Gantt charts)
  final GanttChartData? ganttChartData;

  /// Timeline chart specific data (only set for timeline charts)
  final TimelineChartData? timelineChartData;

  /// Kanban chart specific data (only set for Kanban charts)
  final KanbanChartData? kanbanChartData;

  /// Radar chart specific data (only set for Radar charts)
  final RadarChartData? radarChartData;

  /// XY chart specific data (only set for XY charts)
  final XYChartData? xyChartData;
}

/// Main parser for Mermaid diagrams
///
/// This parser detects the diagram type and delegates to the
/// appropriate specialized parser.
class MermaidParser {
  /// Creates a new Mermaid parser
  const MermaidParser();

  /// Parses a Mermaid diagram string
  ///
  /// Returns null if the diagram cannot be parsed
  MermaidDiagramData? parse(String source) {
    final result = parseWithData(source);
    return result?.diagram;
  }

  /// Parses a Mermaid diagram string and returns additional data
  ///
  /// Returns a [MermaidParseResult] containing the diagram and any
  /// type-specific data (like [PieChartData] for pie charts)
  MermaidParseResult? parseWithData(String source) {
    if (source.trim().isEmpty) return null;

    final lines = source.split('\n');
    final cleanedLines = _cleanLines(lines);

    if (cleanedLines.isEmpty) return null;

    // Skip YAML frontmatter if present (used by some diagram types like Kanban)
    var firstContentLine = cleanedLines.first.trim().toLowerCase();
    if (firstContentLine == '---') {
      // Find the closing --- and get the first line after it
      for (var i = 1; i < cleanedLines.length; i++) {
        if (cleanedLines[i].trim() == '---') {
          if (i + 1 < cleanedLines.length) {
            firstContentLine = cleanedLines[i + 1].trim().toLowerCase();
          }
          break;
        }
      }
    }
    final firstLine = firstContentLine;

    // Detect diagram type
    final type = _detectDiagramType(firstLine);

    switch (type) {
      case DiagramType.flowchart:
        final diagram = FlowchartParser().parse(cleanedLines);
        if (diagram != null) {
          return MermaidParseResult(diagram: diagram);
        }
        return null;
      case DiagramType.sequence:
        final diagram = SequenceParser().parse(cleanedLines);
        if (diagram != null) {
          return MermaidParseResult(diagram: diagram);
        }
        return null;
      case DiagramType.pieChart:
        final result = const PieChartParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            pieChartData: result.$2,
          );
        }
        return null;
      case DiagramType.ganttChart:
        final result = const GanttParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            ganttChartData: result.$2,
          );
        }
        return null;
      case DiagramType.timeline:
        final result = const TimelineParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            timelineChartData: result.$2,
          );
        }
        return null;
      case DiagramType.kanban:
        final result = const KanbanParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            kanbanChartData: result.$2,
          );
        }
        return null;
      case DiagramType.radar:
        final result = const RadarParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            radarChartData: result.$2,
          );
        }
        return null;
      case DiagramType.xyChart:
        final result = const XYChartParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            xyChartData: result.$2,
          );
        }
        return null;
      case DiagramType.classDiagram:
      case DiagramType.stateDiagram:
      case DiagramType.erDiagram:
        final diagram = StructuredGraphParser(type).parse(cleanedLines);
        return diagram == null ? null : MermaidParseResult(diagram: diagram);
      case DiagramType.unknown:
        return null;
    }
  }

  /// Detects the diagram type from the first line
  DiagramType _detectDiagramType(String firstLine) {
    // Flowchart patterns
    if (firstLine.startsWith('graph ') ||
        firstLine.startsWith('flowchart ')) {
      return DiagramType.flowchart;
    }

    // Sequence diagram
    if (firstLine.startsWith('sequencediagram')) {
      return DiagramType.sequence;
    }

    // Pie chart
    if (firstLine.startsWith('pie')) {
      return DiagramType.pieChart;
    }

    // Gantt chart
    if (firstLine.startsWith('gantt')) {
      return DiagramType.ganttChart;
    }

    // Timeline
    if (firstLine.startsWith('timeline')) {
      return DiagramType.timeline;
    }

    // Kanban
    if (firstLine.startsWith('kanban')) {
      return DiagramType.kanban;
    }

    // Radar chart
    if (firstLine.startsWith('radar-beta')) {
      return DiagramType.radar;
    }

    // XY chart
    if (firstLine.startsWith('xychart')) {
      return DiagramType.xyChart;
    }

    // Class diagram
    if (firstLine.startsWith('classdiagram')) {
      return DiagramType.classDiagram;
    }

    // State diagram
    if (firstLine.startsWith('statediagram') ||
        firstLine.startsWith('statediagram-v2')) {
      return DiagramType.stateDiagram;
    }

    if (firstLine.startsWith('erdiagram')) return DiagramType.erDiagram;
    return DiagramType.unknown;
  }

  /// Cleans and filters input lines
  List<String> _cleanLines(List<String> lines) {
    final result = <String>[];

    for (var line in lines) {
      // Remove comments
      final commentIndex = line.indexOf('%%');
      if (commentIndex != -1) {
        line = line.substring(0, commentIndex);
      }

      // Skip empty lines
      if (line.trim().isNotEmpty) {
        result.add(line);
      }
    }

    return result;
  }
}

/// Result of parsing a token
class ParseToken {
  /// Creates a parse token
  const ParseToken({
    required this.type,
    required this.value,
    this.start = 0,
    this.end = 0,
  });

  /// Type of token
  final TokenType type;

  /// Token value
  final String value;

  /// Start position in source
  final int start;

  /// End position in source
  final int end;
}

/// Token types for lexical analysis
enum TokenType {
  /// Node identifier
  nodeId,

  /// Node label
  nodeLabel,

  /// Arrow/edge
  arrow,

  /// Edge label
  edgeLabel,

  /// Keyword (graph, subgraph, etc)
  keyword,

  /// Style definition
  style,

  /// Class definition
  classDef,

  /// Subgraph start
  subgraphStart,

  /// Subgraph end
  subgraphEnd,

  /// End of input
  eof,
}
