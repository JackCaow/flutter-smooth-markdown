import 'package:flutter/material.dart';

import '../config/responsive_config.dart';
import '../layout/dagre_layout.dart';
import '../layout/layout_engine.dart';
import '../layout/sugiyama_layout.dart';
import '../models/diagram.dart';
import '../models/gantt.dart';
import '../models/kanban.dart';
import '../models/pie_chart.dart';
import '../models/radar.dart';
import '../models/timeline.dart';
import '../models/style.dart';
import '../models/xy_chart.dart';
import '../painter/flowchart_painter.dart';
import '../painter/gantt_painter.dart';
import '../painter/kanban_painter.dart';
import '../painter/pie_chart_painter.dart';
import '../painter/radar_painter.dart';
import '../painter/sequence_painter.dart';
import '../painter/timeline_painter.dart';
import '../painter/xy_chart_painter.dart';
import '../parser/mermaid_parser.dart';

/// A widget that renders Mermaid diagrams using pure Dart/Flutter
///
/// This widget parses Mermaid diagram syntax and renders it using
/// Flutter's CustomPainter, without any WebView or external dependencies.
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
///   style: MermaidStyle.dark(),
/// )
/// ```
class MermaidDiagram extends StatefulWidget {
  /// Creates a Mermaid diagram widget
  const MermaidDiagram({
    super.key,
    required this.code,
    this.style,
    this.width,
    this.height,
    this.onNodeTap,
    this.onError,
    this.errorBuilder,
    this.loadingBuilder,
    this.responsiveConfig,
    this.enableResponsive = true,
  });

  /// The Mermaid diagram code
  final String code;

  /// Style configuration (defaults to light theme)
  final MermaidStyle? style;

  /// Fixed width (if not provided, uses available space)
  final double? width;

  /// Fixed height (if not provided, uses computed size)
  final double? height;

  /// Callback when a node is tapped
  final void Function(String nodeId)? onNodeTap;

  /// Callback when parsing fails
  final void Function(String error)? onError;

  /// Builder for error state
  final Widget Function(BuildContext context, String error)? errorBuilder;

  /// Builder for loading state
  final Widget Function(BuildContext context)? loadingBuilder;

  /// Responsive configuration for different screen sizes
  final MermaidResponsiveConfig? responsiveConfig;

  /// Whether to enable responsive layout (defaults to true)
  final bool enableResponsive;

  @override
  State<MermaidDiagram> createState() => _MermaidDiagramState();
}

class _MermaidDiagramState extends State<MermaidDiagram> {
  MermaidDiagramData? _diagram;
  PieChartData? _pieChartData;
  GanttChartData? _ganttChartData;
  TimelineChartData? _timelineChartData;
  KanbanChartData? _kanbanChartData;
  RadarChartData? _radarChartData;
  XYChartData? _xyChartData;
  Size _computedSize = Size.zero;
  String? _error;
  bool _isLoading = true;
  MermaidDeviceConfig? _deviceConfig;
  double? _lastWidth;

  late MermaidStyle _style;

  @override
  void initState() {
    super.initState();
    _style = widget.style ?? const MermaidStyle();
  }

  @override
  void didUpdateWidget(MermaidDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code || oldWidget.style != widget.style) {
      _style = widget.style ?? const MermaidStyle();
      _lastWidth = null; // Force re-layout
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initial parse will happen in build when we have context
  }

  void _parseDiagram(double availableWidth) {
    // Get responsive config
    if (widget.enableResponsive) {
      final responsiveConfig =
          widget.responsiveConfig ?? const MermaidResponsiveConfig();
      _deviceConfig = responsiveConfig.getConfigForWidth(availableWidth);

      // Apply responsive settings to style
      _style = _applyResponsiveStyle(_style, _deviceConfig!);
    }

    try {
      final parser = const MermaidParser();
      final result = parser.parseWithData(widget.code);

      if (result == null) {
        throw Exception('Unable to parse diagram');
      }

      final diagram = result.diagram;
      Size size;

      // Compute layout based on diagram type
      if (diagram.type == DiagramType.pieChart && result.pieChartData != null) {
        // Use pie chart layout with responsive config
        final pieLayout = PieChartLayout(deviceConfig: _deviceConfig);
        size = pieLayout.computeLayout(
          result.pieChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.ganttChart &&
          result.ganttChartData != null) {
        // Use Gantt chart layout with responsive config
        final ganttLayout = GanttChartLayout(deviceConfig: _deviceConfig);
        size = ganttLayout.computeLayout(
          result.ganttChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.timeline &&
          result.timelineChartData != null) {
        // Use Timeline chart layout with responsive config
        final timelineLayout = TimelineChartLayout(deviceConfig: _deviceConfig);
        size = timelineLayout.computeLayout(
          result.timelineChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.kanban &&
          result.kanbanChartData != null) {
        // Use Kanban chart layout with responsive config
        final kanbanLayout = KanbanChartLayout(deviceConfig: _deviceConfig);
        size = kanbanLayout.computeLayout(
          result.kanbanChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.radar &&
          result.radarChartData != null) {
        // Use Radar chart layout with responsive config
        final radarLayout = RadarChartLayout(deviceConfig: _deviceConfig);
        size = radarLayout.computeLayout(
          result.radarChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.xyChart &&
          result.xyChartData != null) {
        // Use XY chart layout with responsive config
        final xyLayout = XYChartLayout(deviceConfig: _deviceConfig);
        size = xyLayout.computeLayout(
          result.xyChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else {
        final layoutEngine = _getLayoutEngine(diagram.type);
        size = layoutEngine.computeLayout(
          diagram,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      }

      _diagram = diagram;
      _pieChartData = result.pieChartData;
      _ganttChartData = result.ganttChartData;
      _timelineChartData = result.timelineChartData;
      _kanbanChartData = result.kanbanChartData;
      _radarChartData = result.radarChartData;
      _xyChartData = result.xyChartData;
      _computedSize = size;
      _error = null;
      _isLoading = false;
    } catch (e) {
      final errorMsg = e.toString();
      _error = errorMsg;
      _isLoading = false;
      widget.onError?.call(errorMsg);
    }
  }

  MermaidStyle _applyResponsiveStyle(
      MermaidStyle style, MermaidDeviceConfig config) {
    return style.copyWith(
      padding: config.padding,
      nodeSpacingX: config.nodeSpacingX,
      nodeSpacingY: config.nodeSpacingY,
      defaultNodeStyle: style.defaultNodeStyle.copyWith(
        fontSize: config.fontSize,
      ),
    );
  }

  LayoutEngine _getLayoutEngine(DiagramType type) {
    switch (type) {
      case DiagramType.flowchart:
      case DiagramType.stateDiagram:
      case DiagramType.classDiagram:
      case DiagramType.erDiagram:
        return DagreLayout(deviceConfig: _deviceConfig);
      case DiagramType.sequence:
        return SequenceLayout(deviceConfig: _deviceConfig);
      default:
        return const SimpleLayoutEngine();
    }
  }

  CustomPainter _getPainter(MermaidDiagramData diagram) {
    switch (diagram.type) {
      case DiagramType.flowchart:
        return FlowchartPainter(
          diagram: diagram,
          style: _style,
          deviceConfig: _deviceConfig,
        );
      case DiagramType.sequence:
        return SequencePainter(
          diagram: diagram,
          style: _style,
          deviceConfig: _deviceConfig,
        );
      case DiagramType.pieChart:
        if (_pieChartData != null) {
          return PieChartPainter(
            pieData: _pieChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.ganttChart:
        if (_ganttChartData != null) {
          return GanttPainter(
            ganttData: _ganttChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.timeline:
        if (_timelineChartData != null) {
          return TimelinePainter(
            timelineData: _timelineChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.kanban:
        if (_kanbanChartData != null) {
          return KanbanPainter(
            kanbanData: _kanbanChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.radar:
        if (_radarChartData != null) {
          return RadarPainter(
            radarData: _radarChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.xyChart:
        if (_xyChartData != null) {
          return XYChartPainter(
            xyData: _xyChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      default:
        return FlowchartPainter(diagram: diagram, style: _style);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        // Re-parse if width changed significantly or first time
        if (_lastWidth == null ||
            (availableWidth - _lastWidth!).abs() > 50 ||
            _isLoading) {
          _lastWidth = availableWidth;
          _parseDiagram(availableWidth);
        }

        if (_isLoading) {
          return widget.loadingBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator());
        }

        if (_error != null) {
          return widget.errorBuilder?.call(context, _error!) ??
              _buildErrorWidget(_error!);
        }

        if (_diagram == null) {
          return const SizedBox.shrink();
        }

        final painter = _getPainter(_diagram!);

        // Keep the full canvas width. Clamping the child before placing it in
        // a horizontal scroll view made wide diagrams permanently unreachable.
        final displayWidth = widget.width != null
            ? (_computedSize.width > widget.width!
                ? _computedSize.width
                : widget.width!)
            : _computedSize.width;

        final displayHeight = widget.height != null
            ? (_computedSize.height > widget.height!
                ? _computedSize.height
                : widget.height!)
            : _computedSize.height;

        // For mobile, wrap in horizontal scroll if needed
        Widget diagramWidget = Container(
          width: displayWidth,
          height: displayHeight,
          color: Color(_style.backgroundColor),
          child: CustomPaint(
            painter: painter,
            size: _computedSize,
          ),
        );

        diagramWidget = GestureDetector(
          onTapDown: widget.onNodeTap != null ? _handleTap : null,
          child: diagramWidget,
        );

        // Scroll constrained inline canvases on any device. Interactive viewers
        // provide unbounded width and handle their own panning.
        if (constraints.maxWidth.isFinite && displayWidth > availableWidth) {
          diagramWidget = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: diagramWidget,
          );
        }

        return diagramWidget;
      },
    );
  }

  void _handleTap(TapDownDetails details) {
    if (_diagram == null || widget.onNodeTap == null) return;

    final localPosition = details.localPosition;

    for (final node in _diagram!.nodes) {
      final nodeRect = Rect.fromLTWH(
        node.x,
        node.y,
        node.width,
        node.height,
      );

      if (nodeRect.contains(localPosition)) {
        widget.onNodeTap!(node.id);
        break;
      }
    }
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(
                'Mermaid Parse Error',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              color: Colors.red.shade900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An interactive Mermaid diagram with pan and zoom support
class InteractiveMermaidDiagram extends StatefulWidget {
  /// Creates an interactive Mermaid diagram
  const InteractiveMermaidDiagram({
    super.key,
    required this.code,
    this.style,
    this.minScale = 0.5,
    this.maxScale = 3.0,
    this.onNodeTap,
  });

  /// The Mermaid diagram code
  final String code;

  /// Style configuration
  final MermaidStyle? style;

  /// Minimum zoom scale
  final double minScale;

  /// Maximum zoom scale
  final double maxScale;

  /// Callback when a node is tapped
  final void Function(String nodeId)? onNodeTap;

  @override
  State<InteractiveMermaidDiagram> createState() =>
      _InteractiveMermaidDiagramState();
}

class _InteractiveMermaidDiagramState extends State<InteractiveMermaidDiagram> {
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _diagramKey = GlobalKey();
  Size? _lastDiagramSize;
  Size? _lastViewportSize;
  bool _hasCentered = false;

  @override
  void didUpdateWidget(InteractiveMermaidDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code || oldWidget.style != widget.style) {
      // Reset centering when code changes
      _hasCentered = false;
      _lastDiagramSize = null;
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _centerDiagram(Size viewportSize, Size diagramSize) {
    // Only center if size changed or first time
    if (_hasCentered &&
        _lastDiagramSize == diagramSize &&
        _lastViewportSize == viewportSize) {
      return;
    }

    _lastDiagramSize = diagramSize;
    _lastViewportSize = viewportSize;
    _hasCentered = true;

    // Calculate scale to fit diagram in viewport with padding
    const padding = 40.0; // Padding around diagram
    final availableWidth = viewportSize.width - padding * 2;
    final availableHeight = viewportSize.height - padding * 2;

    // Calculate scale factors for width and height
    final scaleX = availableWidth / diagramSize.width;
    final scaleY = availableHeight / diagramSize.height;

    // Use the smaller scale to ensure the entire diagram fits
    // But don't scale up beyond 1.0 (100%)
    final scale =
        (scaleX < scaleY ? scaleX : scaleY).clamp(widget.minScale, 1.0);

    // Calculate the scaled diagram size
    final scaledWidth = diagramSize.width * scale;
    final scaledHeight = diagramSize.height * scale;

    // Calculate offset to center the scaled diagram
    final offsetX = (viewportSize.width - scaledWidth) / 2;
    final offsetY = (viewportSize.height - scaledHeight) / 2;

    // Set the transformation matrix
    // Matrix4 applies transformations in reverse order when using cascade
    // So we build: translate then scale (which applies as scale first, then translate)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Create matrix that scales at origin then translates to center
        final matrix = Matrix4.identity();
        // Apply translation
        matrix.setEntry(0, 3, offsetX);
        matrix.setEntry(1, 3, offsetY);
        // Apply scale
        matrix.setEntry(0, 0, scale);
        matrix.setEntry(1, 1, scale);
        _transformationController.value = matrix;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 使用实际可用空间来计算布局
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 800.0;
        final availableHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 600.0;

        final viewportSize = Size(availableWidth, availableHeight);

        return InteractiveViewer(
          transformationController: _transformationController,
          minScale: widget.minScale,
          maxScale: widget.maxScale,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          constrained: false,
          child: _CenteringMermaidDiagram(
            key: _diagramKey,
            code: widget.code,
            style: widget.style,
            viewportSize: viewportSize,
            onNodeTap: widget.onNodeTap,
            onSizeComputed: (diagramSize) {
              _centerDiagram(viewportSize, diagramSize);
            },
          ),
        );
      },
    );
  }
}

/// Internal widget that reports its computed size for centering
class _CenteringMermaidDiagram extends StatefulWidget {
  const _CenteringMermaidDiagram({
    super.key,
    required this.code,
    required this.viewportSize,
    required this.onSizeComputed,
    this.style,
    this.onNodeTap,
  });

  final String code;
  final MermaidStyle? style;
  final Size viewportSize;
  final void Function(String nodeId)? onNodeTap;
  final void Function(Size size) onSizeComputed;

  @override
  State<_CenteringMermaidDiagram> createState() =>
      _CenteringMermaidDiagramState();
}

class _CenteringMermaidDiagramState extends State<_CenteringMermaidDiagram> {
  MermaidDiagramData? _diagram;
  PieChartData? _pieChartData;
  GanttChartData? _ganttChartData;
  TimelineChartData? _timelineChartData;
  KanbanChartData? _kanbanChartData;
  RadarChartData? _radarChartData;
  XYChartData? _xyChartData;
  Size _computedSize = Size.zero;
  String? _error;
  bool _isLoading = true;
  MermaidDeviceConfig? _deviceConfig;

  late MermaidStyle _style;

  @override
  void initState() {
    super.initState();
    _style = widget.style ?? const MermaidStyle();
    _parseDiagram();
  }

  @override
  void didUpdateWidget(_CenteringMermaidDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code || oldWidget.style != widget.style) {
      _style = widget.style ?? const MermaidStyle();
      _parseDiagram();
    }
  }

  void _parseDiagram() {
    try {
      const parser = MermaidParser();
      final result = parser.parseWithData(widget.code);

      if (result == null) {
        throw Exception('Unable to parse diagram');
      }

      final diagram = result.diagram;
      Size size;

      // Compute layout based on diagram type
      if (diagram.type == DiagramType.pieChart && result.pieChartData != null) {
        final pieLayout = PieChartLayout(deviceConfig: _deviceConfig);
        size = pieLayout.computeLayout(
          result.pieChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.ganttChart &&
          result.ganttChartData != null) {
        final ganttLayout = GanttChartLayout(deviceConfig: _deviceConfig);
        size = ganttLayout.computeLayout(
          result.ganttChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.timeline &&
          result.timelineChartData != null) {
        final timelineLayout = TimelineChartLayout(deviceConfig: _deviceConfig);
        size = timelineLayout.computeLayout(
          result.timelineChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.kanban &&
          result.kanbanChartData != null) {
        final kanbanLayout = KanbanChartLayout(deviceConfig: _deviceConfig);
        size = kanbanLayout.computeLayout(
          result.kanbanChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.radar &&
          result.radarChartData != null) {
        final radarLayout = RadarChartLayout(deviceConfig: _deviceConfig);
        size = radarLayout.computeLayout(
          result.radarChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.xyChart &&
          result.xyChartData != null) {
        final xyLayout = XYChartLayout(deviceConfig: _deviceConfig);
        size = xyLayout.computeLayout(
          result.xyChartData!,
          _style,
          widget.viewportSize,
        );
      } else {
        final layoutEngine = _getLayoutEngine(diagram.type);
        size = layoutEngine.computeLayout(
          diagram,
          _style,
          widget.viewportSize,
        );
      }

      setState(() {
        _diagram = diagram;
        _pieChartData = result.pieChartData;
        _ganttChartData = result.ganttChartData;
        _timelineChartData = result.timelineChartData;
        _kanbanChartData = result.kanbanChartData;
        _radarChartData = result.radarChartData;
        _xyChartData = result.xyChartData;
        _computedSize = size;
        _error = null;
        _isLoading = false;
      });

      // Notify parent of computed size for centering
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSizeComputed(size);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  LayoutEngine _getLayoutEngine(DiagramType type) {
    switch (type) {
      case DiagramType.flowchart:
      case DiagramType.stateDiagram:
      case DiagramType.classDiagram:
      case DiagramType.erDiagram:
        return DagreLayout(deviceConfig: _deviceConfig);
      case DiagramType.sequence:
        return SequenceLayout(deviceConfig: _deviceConfig);
      default:
        return const SimpleLayoutEngine();
    }
  }

  CustomPainter _getPainter(MermaidDiagramData diagram) {
    switch (diagram.type) {
      case DiagramType.flowchart:
        return FlowchartPainter(
          diagram: diagram,
          style: _style,
          deviceConfig: _deviceConfig,
        );
      case DiagramType.sequence:
        return SequencePainter(
          diagram: diagram,
          style: _style,
          deviceConfig: _deviceConfig,
        );
      case DiagramType.pieChart:
        if (_pieChartData != null) {
          return PieChartPainter(
            pieData: _pieChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.ganttChart:
        if (_ganttChartData != null) {
          return GanttPainter(
            ganttData: _ganttChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.timeline:
        if (_timelineChartData != null) {
          return TimelinePainter(
            timelineData: _timelineChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.kanban:
        if (_kanbanChartData != null) {
          return KanbanPainter(
            kanbanData: _kanbanChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.radar:
        if (_radarChartData != null) {
          return RadarPainter(
            radarData: _radarChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.xyChart:
        if (_xyChartData != null) {
          return XYChartPainter(
            xyData: _xyChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      default:
        return FlowchartPainter(diagram: diagram, style: _style);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorWidget(_error!);
    }

    if (_diagram == null) {
      return const SizedBox.shrink();
    }

    final painter = _getPainter(_diagram!);

    return Container(
      width: _computedSize.width,
      height: _computedSize.height,
      color: Color(_style.backgroundColor),
      child: GestureDetector(
        onTapDown: widget.onNodeTap != null ? _handleTap : null,
        child: CustomPaint(
          painter: painter,
          size: _computedSize,
        ),
      ),
    );
  }

  void _handleTap(TapDownDetails details) {
    if (_diagram == null || widget.onNodeTap == null) return;

    final localPosition = details.localPosition;

    for (final node in _diagram!.nodes) {
      final nodeRect = Rect.fromLTWH(
        node.x,
        node.y,
        node.width,
        node.height,
      );

      if (nodeRect.contains(localPosition)) {
        widget.onNodeTap!(node.id);
        break;
      }
    }
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(
                'Mermaid Parse Error',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              color: Colors.red.shade900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
