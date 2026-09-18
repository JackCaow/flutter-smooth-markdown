import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/mermaid/layout/dagre_layout.dart';

import 'issue46_fixtures.dart';

void expectLayout(MermaidDiagramData diagram, Size size) {
  expect(size.width, greaterThan(0));
  expect(size.height, greaterThan(0));
  final bounds = Offset.zero & size;
  final rects = diagram.nodes
      .map((n) => Rect.fromLTWH(n.x, n.y, n.width, n.height))
      .toList();
  for (var i = 0; i < rects.length; i++) {
    expect(bounds.contains(rects[i].topLeft), isTrue);
    expect(bounds.contains(rects[i].bottomRight), isTrue);
    for (var j = i + 1; j < rects.length; j++) {
      expect(rects[i].overlaps(rects[j]), isFalse,
          reason: '${diagram.nodes[i].id} overlaps ${diagram.nodes[j].id}');
    }
  }
}

void main() {
  const parser = MermaidParser();
  const layout = DagreLayout();
  const style = MermaidStyle();

  test('issue 46 Chinese states retain transitions and distinct terminals', () {
    final graph = parser.parse(issue46State)!;
    expect(graph.type, DiagramType.stateDiagram);
    expect(graph.nodes, hasLength(7));
    expect(graph.edges, hasLength(7));
    expect(graph.nodes.where((n) => n.shape == NodeShape.stateStart),
        hasLength(1));
    expect(
        graph.nodes.where((n) => n.shape == NodeShape.stateEnd), hasLength(1));
    expect(graph.edges[5].label, '超时/取消');
    expect(graph.edges.first.from, isNot(graph.edges.last.to));
    expectLayout(
        graph, layout.computeLayout(graph, style, const Size(800, 600)));
    for (final edge in graph.edges) {
      expect(graph.getNode(edge.from)!.y, lessThan(graph.getNode(edge.to)!.y));
    }
  });

  test('state aliases and direction preserve node identity', () {
    final graph = parser.parse('''stateDiagram
direction LR
state "Waiting for payment" as pending
[*] --> pending
pending --> done: success
done : Completed
done --> [*]
''')!;
    expect(graph.getNode('pending')!.label, 'Waiting for payment');
    expect(graph.getNode('done')!.label, 'Completed');
    expect(graph.direction, DiagramDirection.leftToRight);
  });

  test('class members are measured in separate compartments', () {
    final graph = parser.parse(issue46Class)!;
    expect(graph.type, DiagramType.classDiagram);
    expect(graph.getNode('Duck')!.compartments, [
      ['+String beakColor'],
      ['+swim()', '+quack()']
    ]);
    expect(graph.edges.first.sourceMarker, EdgeMarker.inheritance);
    expect(graph.edges[1].sourceMarker, EdgeMarker.aggregation);
    expect(graph.edges[2].lineType, LineType.dotted);
    expectLayout(
        graph, layout.computeLayout(graph, style, const Size(800, 600)));
    expect(graph.getNode('Duck')!.height, greaterThan(100));
  });

  for (final relation in {
    '<|--': (EdgeMarker.inheritance, null),
    '--|>': (null, EdgeMarker.inheritance),
    '<|..': (EdgeMarker.inheritance, null),
    '..|>': (null, EdgeMarker.inheritance),
    '*--': (EdgeMarker.composition, null),
    '--*': (null, EdgeMarker.composition),
    'o--': (EdgeMarker.aggregation, null),
    '--o': (null, EdgeMarker.aggregation),
  }.entries) {
    test('class relation ${relation.key} preserves endpoint semantics', () {
      final edge =
          parser.parse('classDiagram\nA ${relation.key} B')!.edges.single;
      expect(edge.sourceMarker, relation.value.$1);
      expect(edge.targetMarker, relation.value.$2);
      expect(edge.arrowType, ArrowType.none);
      expect(edge.copyWith(label: 'test').sourceMarker, edge.sourceMarker);
    });
  }

  test('ER diagram retains attributes, keys and both cardinalities', () {
    final graph = parser.parse(issue46Er)!;
    expect(graph.type, DiagramType.erDiagram);
    expect(graph.nodes, hasLength(3));
    expect(graph.getNode('ORDER')!.compartments.single,
        ['int id PK', 'int customer_id FK']);
    expect(graph.edges.first.sourceMarker, EdgeMarker.exactlyOne);
    expect(graph.edges.first.targetMarker, EdgeMarker.zeroOrMore);
    expect(graph.edges.last.targetMarker, EdgeMarker.oneOrMore);
    expectLayout(
        graph, layout.computeLayout(graph, style, const Size(800, 600)));
  });

  for (final source in {
    '||': EdgeMarker.exactlyOne,
    '|o': EdgeMarker.zeroOrOne,
    '}|': EdgeMarker.oneOrMore,
    '}o': EdgeMarker.zeroOrMore
  }.entries) {
    for (final target in {
      '||': EdgeMarker.exactlyOne,
      'o|': EdgeMarker.zeroOrOne,
      '|{': EdgeMarker.oneOrMore,
      'o{': EdgeMarker.zeroOrMore
    }.entries) {
      test('ER ${source.key}..${target.key}', () {
        final graph = parser
            .parse('erDiagram\nA ${source.key}..${target.key} B : "has"')!;
        expect(graph.edges.single.sourceMarker, source.value);
        expect(graph.edges.single.targetMarker, target.value);
        expect(graph.edges.single.lineType, LineType.dotted);
        expect(graph.edges.single.label, 'has');
      });
    }
  }

  for (final direction in ['TD', 'LR', 'RL', 'BT']) {
    test(
        'issue 46 standalone nodes and subgraph fit without overlap ($direction)',
        () {
      final graph =
          parser.parse(issue46Subgraph.replaceFirst('LR', direction))!;
      expect(graph.nodes, hasLength(8));
      final size = layout.computeLayout(graph, style, const Size(800, 600));
      expectLayout(graph, size);
      final h = graph.getNode('H')!;
      final cluster = Rect.fromLTRB(
          h.x - 20, h.y - 50, h.x + h.width + 20, h.y + h.height + 20);
      expect(cluster.left, greaterThanOrEqualTo(0));
      expect(cluster.top, greaterThanOrEqualTo(0));
      expect(cluster.right, lessThanOrEqualTo(size.width));
      expect(cluster.bottom, lessThanOrEqualTo(size.height));
      for (final node in graph.nodes.where((n) => n.id != 'H')) {
        expect(
            cluster.overlaps(
                Rect.fromLTWH(node.x, node.y, node.width, node.height)),
            isFalse);
      }
      final a = graph.getNode('A')!, b = graph.getNode('B')!;
      switch (direction) {
        case 'LR':
          expect(a.x, lessThan(b.x));
        case 'RL':
          expect(a.x, greaterThan(b.x));
        case 'TD':
          expect(a.y, lessThan(b.y));
        case 'BT':
          expect(a.y, greaterThan(b.y));
      }
      final previous = graph.nodes.map((n) => Offset(n.x, n.y)).toList();
      expect(layout.computeLayout(graph, style, const Size(800, 600)), size);
      expect(graph.nodes.map((n) => Offset(n.x, n.y)).toList(), previous);
    });
  }

  test(
      'cluster edges preserve ordering and nested clusters do not duplicate nodes',
      () {
    final graph = parser.parse('''graph TD
subgraph outer
subgraph inner
A --> B
end
B --> C
end
subgraph other
D --> E
end
outer --> other
X --> A
E --> Y
''')!;
    expectLayout(
        graph, layout.computeLayout(graph, style, const Size(800, 600)));
    expect(graph.getNode('C')!.y, lessThan(graph.getNode('D')!.y));
    expect(graph.getNode('X')!.y, lessThan(graph.getNode('A')!.y));
    expect(graph.getNode('E')!.y, lessThan(graph.getNode('Y')!.y));
  });

  test(
      'unsupported or incomplete structured syntax does not render partial data',
      () {
    for (final code in [
      'stateDiagram-v2\nA --> B\nstate composite {',
      'classDiagram\nclass A {\n+int x',
      'erDiagram\nA ||--o{ B : has\ninvalid syntax',
      'classDiagram',
      'erDiagram'
    ]) {
      expect(parser.parse(code), isNull, reason: code);
    }
  });

  test(
      'class block appends to existing members and multiplicities stay at endpoints',
      () {
    final graph = parser.parse('''classDiagram
Animal : +int age
class Animal {
  +String name
  +eat()
}
Animal "1" <-- "many" Food : feeds
''')!;
    expect(graph.getNode('Animal')!.compartments, [
      ['+int age', '+String name'],
      ['+eat()']
    ]);
    final edge = graph.edges.single;
    expect(edge.from, 'Food');
    expect(edge.to, 'Animal');
    expect(edge.sourceLabel, 'many');
    expect(edge.targetLabel, '1');
    expect(edge.label, 'feeds');
  });

  test('ER quoted names and aliases keep stable identities', () {
    final graph = parser.parse('''erDiagram
"Customer Account"["Customer"] {
  int id PK "identifier"
}
"Customer Account" ||--o{ "Order Line" : has
''')!;
    expect(graph.getNode('Customer Account')!.label, 'Customer');
    expect(graph.getNode('Customer Account')!.compartments.single,
        ['int id PK "identifier"']);
    expect(graph.edges.single.to, 'Order Line');
  });

  test('state choice and cyclic transitions leave room for loop strokes', () {
    final graph = parser.parse('''stateDiagram-v2
state retry
state decision <<choice>>
retry --> retry: again
retry --> decision
decision --> retry
''')!;
    expect(graph.getNode('decision')!.shape, NodeShape.diamond);
    final size = layout.computeLayout(graph, style, const Size(800, 600));
    expectLayout(graph, size);
    final retry = graph.getNode('retry')!;
    expect(size.width - retry.x - retry.width, greaterThanOrEqualTo(40));
  });

  testWidgets('wide inline subgraph retains horizontal scroll extent',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Center(
            child: SizedBox(
      width: 320,
      height: 500,
      child: MermaidDiagram(code: issue46Subgraph),
    ))));
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  for (final sample in issue46Samples.entries) {
    testWidgets('${sample.key} visual regression', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: RepaintBoundary(
        key: const ValueKey('diagram-golden'),
        child: ColoredBox(
            color: Colors.white,
            child:
                InteractiveMermaidDiagram(code: sample.value, minScale: 0.1)),
      )));
      await tester.pumpAndSettle();
      await expectLater(find.byKey(const ValueKey('diagram-golden')),
          matchesGoldenFile('goldens/issue46-${sample.key}.png'));
    });
    for (final interactive in [false, true]) {
      testWidgets(
          '${sample.key} ${interactive ? "interactive" : "inline"} renders',
          (tester) async {
        final errors = <String>[];
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: SizedBox(
          width: 800,
          height: 600,
          child: interactive
              ? InteractiveMermaidDiagram(code: sample.value)
              : MermaidDiagram(code: sample.value, onError: errors.add),
        ))));
        await tester.pumpAndSettle();
        expect(errors, isEmpty);
        expect(tester.takeException(), isNull);
        final painters = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<FlowchartPainter>()
            .toList();
        expect(painters, hasLength(1));
        expect(painters.single.diagram.nodes, isNotEmpty);
        expect(
            painters.single.diagram.nodes
                .every((n) => n.width > 0 && n.height > 0),
            isTrue);
      });
    }
    testWidgets('${sample.key} works in SmoothMarkdown fenced code',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
        child: SmoothMarkdown(
            data: '```mermaid\n${sample.value}\n```',
            plugins: ParserPluginRegistry()..register(const MermaidPlugin()),
            builderRegistry: BuilderRegistry()
              ..register('mermaid', const MermaidBuilder())),
      ))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MermaidDiagram), findsOneWidget);
    });
  }
}
