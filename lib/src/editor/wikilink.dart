import 'package:flutter/material.dart';

import '../config/style_sheet.dart';
import '../parser/ast/markdown_node.dart';
import '../parser/parser_plugin.dart';
import '../renderer/widget_builder.dart';

/// AST node for a `[[wikilink]]` inline element.
class WikilinkNode extends MarkdownNode {
  /// Creates a wikilink node.
  const WikilinkNode({
    required this.target,
  });

  /// Target note or page title.
  ///
  /// Scratch treats the entire text inside `[[...]]` as the note title.
  final String target;

  /// Text displayed to the reader.
  String get label => target;

  @override
  String get type => 'wikilink';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target,
      };

  @override
  WikilinkNode copyWith({String? target}) {
    return WikilinkNode(
      target: target ?? this.target,
    );
  }
}

/// Parser plugin for Scratch-style `[[wikilink]]` inline nodes.
class WikilinkPlugin extends InlineParserPlugin {
  /// Creates a wikilink parser plugin.
  const WikilinkPlugin();

  @override
  String get id => 'wikilink';

  @override
  String get name => 'Wikilink';

  @override
  int get priority => 100;

  @override
  String get triggerCharacter => '[';

  @override
  bool canParse(String text, int index) {
    return index + 1 < text.length &&
        text[index] == '[' &&
        text[index + 1] == '[';
  }

  @override
  InlineParseResult? parse(String text, int startIndex) {
    if (!canParse(text, startIndex)) return null;

    final match = RegExp(r'^\[\[([^\]]+?)\]\]').firstMatch(
      text.substring(startIndex),
    );
    if (match == null) return null;

    final target = match.group(1)!;
    if (target.isEmpty) return null;

    return InlineParseResult(
      node: WikilinkNode(target: target),
      consumed: match.group(0)!.length,
    );
  }
}

/// Renders [WikilinkNode] inline.
class WikilinkBuilder extends MarkdownWidgetBuilder {
  /// Creates a wikilink builder.
  const WikilinkBuilder({this.onTapWikilink});

  /// Called when a wikilink is tapped.
  final void Function(String target)? onTapWikilink;

  @override
  bool canBuild(MarkdownNode node) => node is WikilinkNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final wikilink = node as WikilinkNode;
    final baseStyle = styleSheet.linkStyle ??
        styleSheet.textStyle?.copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ) ??
        const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        );

    return Semantics(
      link: true,
      label: wikilink.target,
      child: GestureDetector(
        onTap: () => onTapWikilink?.call(wikilink.target),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Text(
            wikilink.label,
            style:
                baseStyle.copyWith(decorationStyle: TextDecorationStyle.dashed),
          ),
        ),
      ),
    );
  }
}
