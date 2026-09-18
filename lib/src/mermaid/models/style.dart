import 'edge.dart';
import 'node.dart';

/// Default colors for Mermaid diagrams
class MermaidColors {
  MermaidColors._();

  /// Default node fill color (light blue)
  static const int defaultNodeFill = 0xFFE3F2FD;

  /// Default node stroke color (blue)
  static const int defaultNodeStroke = 0xFF1976D2;

  /// Default text color
  static const int defaultTextColor = 0xFF212121;

  /// Default edge color (gray)
  static const int defaultEdgeColor = 0xFF616161;

  /// Default background color
  static const int defaultBackground = 0xFFFFFFFF;

  /// Primary color (blue)
  static const int primary = 0xFF2196F3;

  /// Secondary color (purple)
  static const int secondary = 0xFF9C27B0;

  /// Success color (green)
  static const int success = 0xFF4CAF50;

  /// Warning color (orange)
  static const int warning = 0xFFFF9800;

  /// Error color (red)
  static const int error = 0xFFF44336;

  /// Decision node color (yellow)
  static const int decision = 0xFFFFF9C4;

  /// Decision node stroke
  static const int decisionStroke = 0xFFFBC02D;
}

/// Global style configuration for Mermaid diagrams
class MermaidStyle {
  /// Creates a Mermaid style configuration
  const MermaidStyle({
    this.backgroundColor = MermaidColors.defaultBackground,
    this.defaultNodeStyle = const NodeStyle(
      fillColor: MermaidColors.defaultNodeFill,
      strokeColor: MermaidColors.defaultNodeStroke,
      textColor: MermaidColors.defaultTextColor,
    ),
    this.defaultEdgeStyle = const EdgeStyle(
      strokeColor: MermaidColors.defaultEdgeColor,
    ),
    this.nodeSpacingX = 50.0,
    this.nodeSpacingY = 50.0,
    this.padding = 20.0,
    this.fontFamily,
    this.themeMode = MermaidThemeMode.light,
    this.classDefs = const {},
  });

  /// Background color (as ARGB int)
  final int backgroundColor;

  /// Default style for nodes
  final NodeStyle defaultNodeStyle;

  /// Default style for edges
  final EdgeStyle defaultEdgeStyle;

  /// Horizontal spacing between nodes
  final double nodeSpacingX;

  /// Vertical spacing between nodes
  final double nodeSpacingY;

  /// Padding around the diagram
  final double padding;

  /// Font family for text
  final String? fontFamily;

  /// Theme mode
  final MermaidThemeMode themeMode;

  /// Custom class definitions (classDef statements)
  final Map<String, NodeStyle> classDefs;

  /// Creates a dark theme style
  factory MermaidStyle.dark() {
    return const MermaidStyle(
      backgroundColor: 0xFF1E1E1E,
      defaultNodeStyle: NodeStyle(
        fillColor: 0xFF2D2D2D,
        strokeColor: 0xFF64B5F6,
        textColor: 0xFFE0E0E0,
      ),
      defaultEdgeStyle: EdgeStyle(
        strokeColor: 0xFF9E9E9E,
        labelColor: 0xFFE0E0E0,
      ),
      themeMode: MermaidThemeMode.dark,
    );
  }

  /// Creates a forest theme style
  factory MermaidStyle.forest() {
    return const MermaidStyle(
      backgroundColor: 0xFFF1F8E9,
      defaultNodeStyle: NodeStyle(
        fillColor: 0xFFC8E6C9,
        strokeColor: 0xFF388E3C,
        textColor: 0xFF1B5E20,
      ),
      defaultEdgeStyle: EdgeStyle(
        strokeColor: 0xFF4CAF50,
      ),
    );
  }

  /// Creates a neutral theme style
  factory MermaidStyle.neutral() {
    return const MermaidStyle(
      backgroundColor: 0xFFFAFAFA,
      defaultNodeStyle: NodeStyle(
        fillColor: 0xFFEEEEEE,
        strokeColor: 0xFF757575,
        textColor: 0xFF424242,
      ),
      defaultEdgeStyle: EdgeStyle(
        strokeColor: 0xFF9E9E9E,
      ),
    );
  }

  /// Gets the node style for a specific class or returns default
  NodeStyle getNodeStyle(String? className) {
    if (className == null) return defaultNodeStyle;
    return classDefs[className] ?? defaultNodeStyle;
  }

  /// Creates a copy with modified properties
  MermaidStyle copyWith({
    int? backgroundColor,
    NodeStyle? defaultNodeStyle,
    EdgeStyle? defaultEdgeStyle,
    double? nodeSpacingX,
    double? nodeSpacingY,
    double? padding,
    String? fontFamily,
    MermaidThemeMode? themeMode,
    Map<String, NodeStyle>? classDefs,
  }) {
    return MermaidStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      defaultNodeStyle: defaultNodeStyle ?? this.defaultNodeStyle,
      defaultEdgeStyle: defaultEdgeStyle ?? this.defaultEdgeStyle,
      nodeSpacingX: nodeSpacingX ?? this.nodeSpacingX,
      nodeSpacingY: nodeSpacingY ?? this.nodeSpacingY,
      padding: padding ?? this.padding,
      fontFamily: fontFamily ?? this.fontFamily,
      themeMode: themeMode ?? this.themeMode,
      classDefs: classDefs ?? this.classDefs,
    );
  }
}

/// Theme modes for Mermaid diagrams
enum MermaidThemeMode {
  /// Light theme (default)
  light,

  /// Dark theme
  dark,

  /// Forest theme (green)
  forest,

  /// Neutral theme (gray)
  neutral,
}

/// Predefined themes for Mermaid diagrams
class MermaidThemes {
  MermaidThemes._();

  /// Default light theme
  static const MermaidStyle light = MermaidStyle();

  /// Dark theme
  static final MermaidStyle dark = MermaidStyle.dark();

  /// Forest (green) theme
  static final MermaidStyle forest = MermaidStyle.forest();

  /// Neutral (gray) theme
  static final MermaidStyle neutral = MermaidStyle.neutral();

  /// Gets a theme by mode
  static MermaidStyle getTheme(MermaidThemeMode mode) {
    switch (mode) {
      case MermaidThemeMode.light:
        return light;
      case MermaidThemeMode.dark:
        return dark;
      case MermaidThemeMode.forest:
        return forest;
      case MermaidThemeMode.neutral:
        return neutral;
    }
  }
}
