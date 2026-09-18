const uiLongState = '''stateDiagram-v2
A --> B: first
B --> C: second
A --> C: SKIP
''';
const uiDarkState = '''stateDiagram-v2
[*] --> 待支付
待支付 --> 已支付: 支付成功
已支付 --> [*]
''';
const uiDarkSubgraph = '''graph TD
subgraph outer [Outer group]
subgraph inner [Inner group]
A[First] --> B[Second]
end
B --> C[Third]
end
C --> D[Outside]
''';
const uiEr = '''erDiagram
CUSTOMER ||--o{ ORDER : places
ORDER ||--|{ LINE_ITEM : contains
''';
const uiSelfState = '''stateDiagram-v2
[*] --> Idle
Idle --> Idle: RETRY
Idle --> Done: FINISH
Done --> [*]
''';

const uiSelfSiblings = '''stateDiagram-v2
[*] --> Idle
[*] --> Waiting
Idle --> Idle: RETRY
Waiting --> Waiting: WAIT
Idle --> Done
Waiting --> Done
Done --> [*]
''';
