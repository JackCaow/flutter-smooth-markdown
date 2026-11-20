import 'package:flutter/material.dart';

import '../src/config/style_sheet.dart';
import '../src/parser/ast/markdown_node.dart';
import '../src/parser/plugins/citation_plugin.dart';
import '../src/renderer/widget_builder.dart';

/// Metadata provided by the app for a numbered reference in an answer.
@immutable
class MarkdownSource {
  const MarkdownSource({required this.title, this.uri, this.excerpt});

  final String title;
  final Uri? uri;
  final String? excerpt;
}

/// Resolves markers parsed by [MarkdownCitationPlugin] in descendant views.
/// Register the plugin on the views that use numbered citations. Unknown
/// numbers remain visible as literal text. Hosts handle navigation on tap.
class MarkdownCitationScope extends InheritedWidget {
  const MarkdownCitationScope({
    required this.sources,
    required this.onSourceTap,
    required super.child,
    super.key,
  });

  /// Replace the map when sources arrive or change. Numbers are one-based.
  final Map<int, MarkdownSource> sources;
  final ValueChanged<MarkdownSource> onSourceTap;

  static MarkdownCitationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MarkdownCitationScope>();

  @override
  bool updateShouldNotify(MarkdownCitationScope oldWidget) =>
      sources != oldWidget.sources || onSourceTap != oldWidget.onSourceTap;
}

/// Default inline builder for numbered sources.
class MarkdownCitationBuilder extends MarkdownWidgetBuilder {
  const MarkdownCitationBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is MarkdownCitationNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final number = (node as MarkdownCitationNode).number;
    return Builder(
      builder: (context) {
        final scope = MarkdownCitationScope.maybeOf(context);
        final source = scope?.sources[number];
        final marker = '[$number]';
        if (source == null || scope == null) {
          return Text(marker, style: styleSheet.textStyle);
        }
        return Semantics(
          link: true,
          label: '$marker ${source.title}',
          child: Tooltip(
            message: source.title,
            excludeFromSemantics: true,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => scope.onSourceTap(source),
                child: ExcludeSemantics(
                  child: Text(marker, style: styleSheet.linkStyle),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
