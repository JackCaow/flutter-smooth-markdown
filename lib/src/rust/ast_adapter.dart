import '../parser/ast/markdown_node.dart';
import 'wire.dart';

List<MarkdownNode> adaptNodes(
  List<CoreNode> nodes,
  Map<int, MarkdownNode> custom,
) => nodes.expand((node) => adaptNode(node, custom)).toList();

List<MarkdownNode> adaptNode(CoreNode n, Map<int, MarkdownNode> custom) {
  List<MarkdownNode> children() => adaptNodes(n.children, custom);
  String plain(CoreNode node) =>
      node.literal ??
      (node.children.isEmpty ? node.source : node.children.map(plain).join());
  String withoutFinalNewline(String s) =>
      s.endsWith('\n') ? s.substring(0, s.length - 1) : s;
  switch (n.kind) {
    case 0:
      return children();
    case 1:
      return [ParagraphNode(children())];
    case 2:
      return [
        HeaderNode(
          level: n.level,
          content: n.children.map(plain).join(),
          children: children(),
        ),
      ];
    case 3:
    case 4:
      final language = n.info.trim().split(RegExp(r'\s+')).first;
      final fence =
          RegExp(r'^\s*(`{3,}|~{3,})').firstMatch(n.source)?.group(1) ?? '```';
      return [
        CodeBlockNode(
          code: withoutFinalNewline(n.literal ?? ''),
          language: language.isEmpty ? null : language,
          info: n.info.isEmpty ? null : n.info,
          fence: fence,
        ),
      ];
    case 5:
      final rows = n.children.where((row) => row.kind == 6).toList();
      if (rows.isEmpty) return [];
      List<List<MarkdownNode>> cells(CoreNode row) => row.children
          .map((cell) => adaptNodes(cell.children, custom))
          .toList();
      return [
        TableNode(
          headers: cells(rows.first),
          alignments: n.alignments
              .map(
                (a) => switch (a) {
                  'left' => TableAlignment.left,
                  'center' => TableAlignment.center,
                  'right' => TableAlignment.right,
                  _ => null,
                },
              )
              .toList(),
          rows: rows.skip(1).map((row) => TableRowNode(cells(row))).toList(),
        ),
      ];
    case 8:
      final items = n.children
          .expand((item) => adaptNode(item, custom))
          .whereType<ListItemNode>()
          .toList();
      final groups = <MarkdownNode>[];
      var start = 0;
      while (start < items.length) {
        var end = start + 1;
        while (end < items.length &&
            (items[end].checked != null) == (items[start].checked != null)) {
          end++;
        }
        groups.add(
          ListNode(
            items: items.sublist(start, end),
            ordered: n.flags & 1 != 0,
            startIndex: (n.flags & 32 != 0 ? n.listStart : 1) + start,
          ),
        );
        start = end;
      }
      return groups;
    case 9:
      final content = children();
      return [
        ListItemNode(
          children: [
            if (content.isNotEmpty && content.first is ParagraphNode)
              ...(content.first as ParagraphNode).children
            else if (content.isNotEmpty)
              content.first,
            ...content.skip(1),
          ],
          checked: n.flags & 4 != 0 ? n.flags & 2 != 0 : null,
        ),
      ];
    case 10:
      return [BlockquoteNode(children())];
    case 11:
      return [const HorizontalRuleNode()];
    case 12:
      return [TextNode(n.literal ?? n.source)];
    case 13:
      return [BoldNode(children())];
    case 14:
      return [ItalicNode(children())];
    case 15:
      return [StrikethroughNode(children())];
    case 16:
      return [InlineCodeNode(n.literal ?? '')];
    case 17:
      return [InlineMathNode(n.literal ?? '')];
    case 18:
      return [const TextNode('\n')];
    case 19:
      return [const HardBreakNode()];
    // HTML is disabled on this path. Preserve its literal spelling, matching
    // the existing reader; enabled safe HTML uses the compatibility parser.
    case 20:
    case 27:
    case 28:
      return [TextNode(n.literal ?? n.source)];
    case 21:
      return [BlockMathNode((n.literal ?? '').trim())];
    case 22:
      return [FootnoteReferenceNode(n.label)];
    case 23:
      return [FootnoteDefinitionNode(label: n.label, children: children())];
    case 24:
      return [];
    case 25:
      return [
        LinkNode(url: n.destination, title: n.title, children: children()),
      ];
    case 26:
      return [
        ImageNode(
          url: n.destination,
          title: n.title,
          alt: n.children.map(plain).join(),
        ),
      ];
    case 29:
      final id = int.tryParse(n.label);
      if (id == null || !custom.containsKey(id)) {
        throw const FormatException('Unknown custom node');
      }
      return [custom[id]!];
    case 6:
    case 7:
    case 30:
    case 31:
      return children();
    case 32:
      return [];
    default:
      throw FormatException('Unknown Rust node ${n.kind}');
  }
}
