# State, class and ER diagrams

The native Flutter renderer supports the following **basic subset**. It does not
embed Mermaid.js and does not claim complete Mermaid syntax or pixel-identical
layout compatibility.

| Type | Supported |
| --- | --- |
| `stateDiagram`, `stateDiagram-v2` | Unicode state IDs, `-->` transitions and labels, separate initial/final `[*]` markers, self transitions, `state "label" as id`, `id : description`, `state id`, `<<choice>>` |
| `classDiagram` | Class declarations, `class ID["label"]`, multiline member blocks, `ID : member`, attribute/method compartments, inheritance, realization, composition, aggregation, association, dependency, solid/dotted links, relationship labels and endpoint multiplicities |
| `erDiagram` | Entities (including quoted names and aliases), multiline attribute blocks with keys/comments preserved as text, identifying/non-identifying relationships, all four symbolic cardinalities at either end |

All three support a separate `direction TB`, `TD`, `BT`, `LR`, or `RL` statement.
Use one statement/member per line; opening and closing block braces belong on
the declaration line and a separate closing line respectively.

Not supported yet: composite/concurrent states, state notes and fork/join;
class namespaces, annotations, generic class IDs, lollipop/bidirectional
relationships and notes; ER subgraphs and word-form cardinality aliases;
per-node styling/click directives in these three new parsers. Unsupported
statements return the existing parse-error UI rather than rendering a partial
diagram. Members and ER attributes are displayed as text, not rich HTML.

Flowchart subgraphs are laid out as clusters together with external nodes.
Nested clusters, cluster-to-cluster and cluster-to-node connections participate
in layout. The existing flowchart parser still determines subgraph membership;
per-subgraph direction overrides are not implemented.

## Usage

```dart
MermaidDiagram(code: '''stateDiagram-v2
  [*] --> Pending
  Pending --> Paid: payment succeeds
  Paid --> [*]
''')
```

For fenced `mermaid` blocks in `SmoothMarkdown`, register both the parser and
builder (unchanged API):

````dart
SmoothMarkdown(
  data: '```mermaid\nclassDiagram\nAnimal <|-- Duck\n```',
  plugins: ParserPluginRegistry()..register(const MermaidPlugin()),
  builderRegistry: BuilderRegistry()..register('mermaid', const MermaidBuilder()),
)
````

## Regression validation

```sh
flutter test test/mermaid
flutter test
cd example
flutter test integration_test/issue46_test.dart -d DEVICE_ID
# Also save device screenshots under example/build/issue46-screenshots:
flutter drive --driver=test_driver/issue46_driver.dart \
  --target=integration_test/issue46_test.dart -d DEVICE_ID \
  --dart-define=ISSUE46_SCREENSHOTS=true
```

The fixtures include both exact examples from issue #46, plus representative
class and ER diagrams. Tests cover parsing/relationship semantics, non-overlap,
all four layout directions, nested clusters, and inline/interactive/Markdown
widget paths. Device tests exercise the actual Flutter renderer and panning.

UI regressions additionally assert label bounds, node/marker avoidance in all
four directions, and dark-label contrast. Five reviewed visual baselines cover
long transitions, self loops, ER labels, and dark states/nested subgraphs. Run
`example/integration_test/issue46_ui_test.dart` with the same driver and screenshot
flag above to capture those five scenarios on a device.

Syntax references: [state diagrams](https://mermaid.js.org/syntax/stateDiagram.html),
[class diagrams](https://mermaid.js.org/syntax/classDiagram.html),
[ER diagrams](https://mermaid.js.org/syntax/entityRelationshipDiagram.html).
