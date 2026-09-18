const issue46State = '''stateDiagram-v2
    [*] --> 待支付
    待支付 --> 已支付: 支付成功
    已支付 --> 已发货: 发货
    已发货 --> 已完成: 确认收货
    已完成 --> [*]
    待支付 --> 已取消: 超时/取消
    已取消 --> [*]
''';

const issue46Subgraph = '''graph LR
    %% 节点定义
    A[矩形] --> B(圆角矩形)
    B --> C{菱形}
    C -->|条件| D[(圆柱形)]
    %% 连接样式
    E==>|粗线|F
    F-.->|虚线|G
    %% 方向控制
    subgraph 子图
        H[内部节点]
    end
''';

const issue46Class = '''classDiagram
    Animal <|-- Duck
    Animal : +int age
    Animal : +isMammal() bool
    class Duck {
        +String beakColor
        +swim()
        +quack()
    }
    Pond o-- Duck : contains
    Duck ..> Food : eats
''';

const issue46Er = '''erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE_ITEM : contains
    CUSTOMER {
        int id PK
        string name
    }
    ORDER {
        int id PK
        int customer_id FK
    }
    LINE_ITEM {
        int id PK
        int order_id FK
        string product
    }
''';

const issue46Samples = {
  'state': issue46State,
  'subgraph': issue46Subgraph,
  'class': issue46Class,
  'er': issue46Er,
};
