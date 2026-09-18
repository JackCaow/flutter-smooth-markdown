import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';

/// Parses the basic state, class and ER graph syntaxes.
///
/// Unsupported statements fail explicitly instead of silently losing content.
/// See docs/mermaid-structured-diagrams.md for the supported subset.
class StructuredGraphParser {
  /// Creates a parser for one of the structured graph types.
  StructuredGraphParser(this.type);

  final DiagramType type;
  final Map<String, MermaidNode> _nodes = {};
  final List<MermaidEdge> _edges = [];
  DiagramDirection _direction = DiagramDirection.topToBottom;

  static const _identifier = r'[\w\u0080-\uFFFF-]+';
  static const _entity = '(?:"[^"]+"|$_identifier)';

  String _unquote(String value) => value.replaceAll(RegExp(r'^"|"$'), '');

  /// Parses a complete diagram, including its header.
  MermaidDiagramData? parse(List<String> lines) {
    _nodes.clear();
    _edges.clear();
    _direction = DiagramDirection.topToBottom;
    String? block;
    final rows = <String>[];
    for (var line in lines
        .skipWhile((line) => !RegExp(
              r'^(stateDiagram(?:-v2)?|classDiagram|erDiagram)\b',
              caseSensitive: false,
            ).hasMatch(line.trim()))
        .skip(1)) {
      line = line.trim().replaceFirst(RegExp(r';$'), '');
      if (line.isEmpty) continue;
      if (block != null) {
        if (line == '}') {
          final node = _nodes[block]!;
          _nodes[block] = node.copyWith(
              compartments: type == DiagramType.classDiagram
                  ? [
                      [
                        ...node.compartments[0],
                        ...rows.where((r) => !r.contains('('))
                      ],
                      [
                        ...node.compartments[1],
                        ...rows.where((r) => r.contains('('))
                      ]
                    ]
                  : [
                      [...node.compartments.single, ...rows]
                    ]);
          block = null;
          rows.clear();
        } else {
          if (line.contains('{') || line.contains('}')) return null;
          rows.add(line);
        }
        continue;
      }
      final direction =
          RegExp(r'^direction\s+(TB|TD|BT|LR|RL)$').firstMatch(line);
      if (direction != null) {
        _direction = switch (direction[1]) {
          'BT' => DiagramDirection.bottomToTop,
          'LR' => DiagramDirection.leftToRight,
          'RL' => DiagramDirection.rightToLeft,
          _ => DiagramDirection.topToBottom,
        };
        continue;
      }
      if (type == DiagramType.stateDiagram) {
        if (!_state(line)) return null;
      } else {
        final declaration = RegExp(type == DiagramType.classDiagram
                ? '^class\\s+($_identifier)(?:\\s*\\["(.*)"\\])?\\s*(\\{)?\$'
                : '^($_entity)(?:\\s*\\["?(.*?)"?\\])?\\s*(\\{)?\$')
            .firstMatch(line);
        if (declaration != null) {
          final id = _unquote(declaration[1]!);
          _node(id);
          if (declaration[2] != null) {
            _nodes[id] = _nodes[id]!.copyWith(label: declaration[2]);
          }
          if (declaration[3] != null) block = id;
        } else if (type == DiagramType.classDiagram) {
          if (!_class(line)) return null;
        } else if (!_er(line)) {
          return null;
        }
      }
    }
    if (block != null || _nodes.isEmpty) return null;
    return MermaidDiagramData(
        type: type,
        nodes: _nodes.values.toList(),
        edges: List.of(_edges),
        direction: _direction);
  }

  void _node(String id) {
    _nodes.putIfAbsent(
        id,
        () => MermaidNode(
            id: id,
            label: id,
            shape: type == DiagramType.stateDiagram
                ? NodeShape.roundedRect
                : NodeShape.rectangle,
            compartments: type == DiagramType.classDiagram
                ? const [[], []]
                : type == DiagramType.erDiagram
                    ? const [[]]
                    : const []));
  }

  bool _state(String line) {
    final transition = RegExp('^(\\[\\*\\]|$_identifier)\\s*-->\\s*'
            '(\\[\\*\\]|$_identifier)(?:\\s*:\\s*(.*))?\$')
        .firstMatch(line);
    if (transition != null) {
      String endpoint(String value, bool start) {
        if (value != '[*]') {
          _node(value);
          return value;
        }
        // Separate source and destination pseudo-states: merging them creates
        // a false cycle and turns the terminal state into the initial state.
        final id = start ? '\$state:start' : '\$state:end';
        _nodes.putIfAbsent(
            id,
            () => MermaidNode(
                id: id,
                label: '',
                shape: start ? NodeShape.stateStart : NodeShape.stateEnd));
        return id;
      }

      _edges.add(MermaidEdge(
          from: endpoint(transition[1]!, true),
          to: endpoint(transition[2]!, false),
          label: transition[3]));
      return true;
    }
    final alias =
        RegExp('^state\\s+"(.*)"\\s+as\\s+($_identifier)\$').firstMatch(line);
    if (alias != null) {
      _node(alias[2]!);
      _nodes[alias[2]!] = _nodes[alias[2]!]!.copyWith(label: alias[1]);
      return true;
    }
    final declaration = RegExp('^state\\s+($_identifier)(?:\\s+<<choice>>)?\$')
        .firstMatch(line);
    if (declaration != null) {
      final id = declaration[1]!;
      _node(id);
      if (line.endsWith('<<choice>>')) {
        _nodes[id] = _nodes[id]!.copyWith(label: '', shape: NodeShape.diamond);
      }
      return true;
    }
    final description =
        RegExp('^($_identifier)\\s*:\\s*(.+)\$').firstMatch(line);
    if (description != null) {
      _node(description[1]!);
      _nodes[description[1]!] =
          _nodes[description[1]!]!.copyWith(label: description[2]);
      return true;
    }
    if (RegExp('^$_identifier\$').hasMatch(line)) {
      _node(line);
      return true;
    }
    return false;
  }

  bool _class(String line) {
    final relation = RegExp('^($_identifier)(?:\\s+"([^"]*)")?\\s*'
            r'(<\|--|--\|>|<\|\.\.|\.\.\|>|\*--|--\*|o--|--o|<--|-->|<\.\.|\.\.>|--|\.\.)'
            '(?:\\s*"([^"]*)")?\\s*($_identifier)(?:\\s*:\\s*(.*))?\$')
        .firstMatch(line);
    if (relation != null) {
      final from = relation[1]!, to = relation[5]!, operator = relation[3]!;
      _node(from);
      _node(to);
      EdgeMarker? marker(String value) => value.contains('|')
          ? EdgeMarker.inheritance
          : value.contains('*')
              ? EdgeMarker.composition
              : value.contains('o')
                  ? EdgeMarker.aggregation
                  : null;
      final source = operator.startsWith('<') ||
          operator.startsWith('*') ||
          operator.startsWith('o');
      final symbol = marker(operator);
      final reverse = source && symbol == null && operator.startsWith('<');
      _edges.add(MermaidEdge(
          from: reverse ? to : from,
          to: reverse ? from : to,
          label: relation[6],
          sourceLabel: reverse ? relation[4] : relation[2],
          targetLabel: reverse ? relation[2] : relation[4],
          arrowType: symbol == null &&
                  (operator.contains('>') || operator.contains('<'))
              ? ArrowType.arrow
              : ArrowType.none,
          lineType: operator.contains('.') ? LineType.dotted : LineType.solid,
          sourceMarker: source ? symbol : null,
          targetMarker: source ? null : symbol));
      return true;
    }
    final member = RegExp('^($_identifier)\\s*:\\s*(.+)\$').firstMatch(line);
    if (member == null) return false;
    final id = member[1]!, row = member[2]!;
    _node(id);
    final parts =
        _nodes[id]!.compartments.map((p) => List<String>.of(p)).toList();
    parts[row.contains('(') ? 1 : 0].add(row);
    _nodes[id] = _nodes[id]!.copyWith(compartments: parts);
    return true;
  }

  bool _er(String line) {
    final relation = RegExp('^($_entity)\\s+'
            r'(\|\||o\||\|o|\}\||\}o)\s*(--|\.\.)\s*(\|\||o\||\|o|\|\{|o\{)'
            '\\s*($_entity)\\s*:\\s*(.+)\$')
        .firstMatch(line);
    if (relation == null) return false;
    EdgeMarker cardinality(String value) {
      if (value.contains('{') || value.contains('}')) {
        return value.contains('o')
            ? EdgeMarker.zeroOrMore
            : EdgeMarker.oneOrMore;
      }
      return value.contains('o') ? EdgeMarker.zeroOrOne : EdgeMarker.exactlyOne;
    }

    final from = _unquote(relation[1]!);
    final to = _unquote(relation[5]!);
    _node(from);
    _node(to);
    _edges.add(MermaidEdge(
        from: from,
        to: to,
        label: relation[6]!.replaceAll(RegExp(r'^"|"$'), ''),
        arrowType: ArrowType.none,
        lineType: relation[3] == '..' ? LineType.dotted : LineType.solid,
        sourceMarker: cardinality(relation[2]!),
        targetMarker: cardinality(relation[4]!)));
    return true;
  }
}
