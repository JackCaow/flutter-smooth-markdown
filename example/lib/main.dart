import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

import 'ai_chat_demo.dart';
import 'chat_list_demo.dart';
import 'footnote_demo.dart';
import 'l10n/app_localizations.dart';
import 'conversation_list_demo.dart';
import 'editor_demo.dart';
import 'math_demo.dart';
import 'mermaid_demo.dart';
import 'plugin_demo.dart';
import 'streaming_demo.dart';

Future<void> main() async {
  // 加载 .env 文件（不存在时静默忽略，如 CI 环境）
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env may not exist in CI; non-critical for demo apps.
  }

  // 加载 .env 文件
  // TODO: uncomment when .env is available in CI
  // await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('zh');

  void _changeLanguage(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Smooth Markdown Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(),
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh'),
        Locale('en'),
        Locale('ja'),
        Locale('es'),
        Locale('fr'),
        Locale('ko'),
      ],
      home: MarkdownDemoPage(onLanguageChange: _changeLanguage),
    );
  }
}

class MarkdownDemoPage extends StatefulWidget {
  const MarkdownDemoPage({
    super.key,
    required this.onLanguageChange,
  });

  final void Function(Locale) onLanguageChange;

  @override
  State<MarkdownDemoPage> createState() => _MarkdownDemoPageState();
}

enum MarkdownTheme {
  defaultLight(Brightness.light),
  defaultDark(Brightness.dark),
  github(Brightness.light),
  githubDark(Brightness.dark),
  vscode(Brightness.light),
  vscodeDark(Brightness.dark);

  const MarkdownTheme(this.brightness);
  final Brightness brightness;

  String getLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (this) {
      case MarkdownTheme.defaultLight:
        return l10n.translate('theme_default_light');
      case MarkdownTheme.defaultDark:
        return l10n.translate('theme_default_dark');
      case MarkdownTheme.github:
        return l10n.translate('theme_github');
      case MarkdownTheme.githubDark:
        return l10n.translate('theme_github_dark');
      case MarkdownTheme.vscode:
        return l10n.translate('theme_vscode');
      case MarkdownTheme.vscodeDark:
        return l10n.translate('theme_vscode_dark');
    }
  }
}

class _MarkdownDemoPageState extends State<MarkdownDemoPage> {
  int _selectedIndex = 0;
  MarkdownTheme _selectedTheme = MarkdownTheme.defaultLight;

  // Mermaid plugin and builder for rendering mermaid diagrams
  final _mermaidPlugins = ParserPluginRegistry()
    ..register(const MermaidPlugin());
  final _mermaidBuilders = BuilderRegistry()
    ..register('mermaid', const MermaidBuilder());

  final List<MarkdownExample> _examples = [
    MarkdownExample(
      title: 'Basic Formatting',
      markdown: '''
# Basic Text Formatting

This is a **paragraph** with different text styles.

You can make text **bold** or *italic*. You can also combine ***both***.

For inline code, use backticks: `var x = 42;`

You can also use ~~strikethrough~~ text.
''',
    ),
    MarkdownExample(
      title: 'Headers',
      markdown: '''
# Header 1
## Header 2
### Header 3
#### Header 4
##### Header 5
###### Header 6

Regular paragraph text follows headers.

---

**Headers with Inline Formatting** (New Feature!)

## 📝 **Bold** in Headers

### This is *italic* text

### **Bold** and *italic* mixed

### Use `code` in headers

### Check [this link](https://flutter.dev)

### 🎉 **Celebration** with *style*

### ⚡ Performance **optimization** `v2.0`
''',
    ),
    MarkdownExample(
      title: 'Lists',
      markdown: '''
# Unordered Lists

- Item 1
- Item 2
- Item 3
  - Nested items work too

# Ordered Lists

1. First item
2. Second item
3. Third item

# Task Lists

- [x] Completed task
- [ ] Pending task
- [x] Another completed task
- [ ] Another pending task
''',
    ),
    MarkdownExample(
      title: 'Code Blocks',
      markdown: '''
# Code Example

Here's a Dart code block:

```dart
void main() {
  print('Hello, World!');

  final numbers = [1, 2, 3, 4, 5];
  final doubled = numbers.map((n) => n * 2);

  print('Doubled: \$doubled');
}
```

And some JavaScript:

```javascript
function greet(name) {
  console.log(`Hello, \${name}!`);
}

greet('Flutter');
```
''',
    ),
    MarkdownExample(
      title: 'Quotes & Rules',
      markdown: '''
# Blockquotes

> This is a blockquote.
> It can span multiple lines.
>
> And have multiple paragraphs.

---

# Horizontal Rules

Text above the rule

---

Text below the rule

***

Another rule style
''',
    ),
    MarkdownExample(
      title: 'Links & Images',
      markdown: '''
# Links

Check out [Flutter](https://flutter.dev) for more information.

Here's a [GitHub link](https://github.com) you can click.

# Images

![Flutter Logo](https://flutter.dev/assets/images/shared/brand/flutter/logo/flutter-lockup.png)

![Alt text for broken image](https://example.com/nonexistent.png)
''',
    ),
    MarkdownExample(
      title: 'Enhanced UI',
      markdown: '''
# 增强 UI 组件展示

本页面展示了增强版的 Markdown 渲染组件。

## 代码块增强

增强的代码块包含：
- ✨ 悬停时显示复制按钮
- 🏷️ 语言标签显示
- 📋 一键复制代码功能
- 💫 微妙的阴影效果

```dart
// 试试悬停在代码块上！
void main() {
  final message = 'Enhanced UI is awesome!';
  print(message);

  // 代码块支持水平滚动
  final longLine = 'This is a very long line that will trigger horizontal scrolling to demonstrate the enhanced scrollbar';
}
```

```typescript
// 多种语言支持
interface User {
  id: string;
  name: string;
  email: string;
}

const user: User = {
  id: '123',
  name: 'John Doe',
  email: 'john@example.com'
};
```

## 引用块增强

引用块现在包含：
- 💭 引号图标
- 🎨 渐变背景
- ✨ 微妙阴影
- 🌈 彩色左侧边框

> 这是一个增强的引用块。
>
> 注意渐变背景和引号图标，让引用更加优雅。
>
> **支持嵌套的格式化文本！**

> 💡 **提示**: 引用块非常适合展示重要信息或引用。

## 标题装饰

标题现在有：
- 📍 H1/H2 左侧彩色标记
- ➖ 渐变底部边框
- 📏 更好的间距

### H3 标题示例
#### H4 标题示例
##### H5 标题示例
###### H6 标题示例

## 链接增强

链接现在包含：
- 🎯 悬停动画效果
- 🔗 动态下划线
- 🌐 外部链接图标
- ✨ 平滑过渡

试试这些链接：
- [Flutter 官网](https://flutter.dev)
- [GitHub 仓库](https://github.com)
- [内部链接](#section)

## 列表展示

- **无序列表** - 清晰的项目符号
- **有序列表** - 编号格式化
- **任务列表** - 美化的复选框

任务清单示例：
- [x] 完成基础组件
- [x] 添加增强效果
- [ ] 收集用户反馈
- [ ] 持续优化

---

**体验对比**：切换到其他页面对比标准UI和增强UI的区别！
''',
    ),
    MarkdownExample(
      title: 'Theme Showcase',
      markdown: '''
# 主题展示

点击右上角的 **调色板图标** 🎨 来切换不同的主题！

## 可用主题

### 默认主题
- **默认亮色** - 简洁清爽的亮色主题
- **默认暗色** - 护眼舒适的暗色主题

### GitHub 风格
- **GitHub** - 经典的 GitHub 亮色主题
- **GitHub Dark** - GitHub 暗色主题

### VS Code 风格
- **VS Code** - VS Code 编辑器亮色主题
- **VS Code Dark** - VS Code 编辑器暗色主题

## 主题特性

每个主题都精心设计了以下元素：

1. **文本样式** - 优雅的字体和间距
2. **代码高亮** - 专业的代码块样式
3. **链接颜色** - [点击链接](https://flutter.dev) 查看效果
4. **引用样式** - 查看下方示例

> 这是一个引用块
> 不同主题下颜色和样式会有所不同

## 代码示例

```dart
// 不同主题下的代码块效果
void main() {
  final message = 'Hello, Flutter!';
  print(message);
}
```

## 自定义主题

你也可以创建自己的主题：

```dart
final customTheme = MarkdownStyleSheet(
  h1Style: TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.purple,
  ),
  codeBlockDecoration: BoxDecoration(
    color: Colors.grey[100],
    borderRadius: BorderRadius.circular(8),
  ),
);
```

**试试切换主题，感受不同的视觉体验吧！** ✨
''',
    ),
    MarkdownExample(
      title: 'Details & Summary',
      markdown: '''
# Details & Summary 折叠块

Details 元素提供了可折叠的内容区域，非常适合隐藏详细信息或额外内容。

## 基础示例

<details>
<summary>点击展开/折叠</summary>
这是隐藏的内容，只有当用户点击摘要时才会显示。
</details>

## 默认展开

使用 `open` 属性可以让折叠块默认展开：

<details open>
<summary>默认展开的内容</summary>
这个折叠块默认是展开状态。
</details>

## 包含列表

<details>
<summary>查看功能列表</summary>

支持的功能：
- 折叠/展开动画
- 自定义样式
- 嵌套内容支持
- 响应式布局
</details>

## 包含代码块

<details>
<summary>查看代码示例</summary>

```dart
void main() {
  print('Details 块中的代码');
  final list = [1, 2, 3, 4, 5];
  print(list);
}
```
</details>

## 嵌套折叠块

<details>
<summary>外层折叠块</summary>

这是外层内容。

<details>
<summary>内层折叠块</summary>
这是内层嵌套的内容。
</details>

外层内容的其他部分。
</details>

## FAQ 示例

<details>
<summary>Q: 如何使用 Flutter Smooth Markdown？</summary>

A: 只需在你的 Flutter 项目中添加依赖，然后使用 `SmoothMarkdown` widget：

```dart
SmoothMarkdown(
  data: '# Hello World',
)
```
</details>

<details>
<summary>Q: 支持哪些 Markdown 语法？</summary>

A: 支持 CommonMark 标准语法，以及 GFM 扩展（表格、任务列表等）。
</details>

<details>
<summary>Q: 可以自定义主题吗？</summary>

A: 当然！使用 `MarkdownStyleSheet` 可以完全自定义所有元素的样式。
</details>

## 包含表格

<details>
<summary>查看数据表格</summary>

| 特性 | 支持 | 说明 |
|------|------|------|
| 折叠 | ✅ | 点击展开/收起 |
| 嵌套 | ✅ | 支持多层嵌套 |
| 样式 | ✅ | 可自定义 |
| 动画 | ✅ | 平滑过渡 |
</details>

## 包含引用

<details>
<summary>查看引用内容</summary>

> Details 和 Summary 元素是 HTML5 的原生元素，
> 提供了一种语义化的方式来创建可折叠的内容区域。
>
> 在 Markdown 中使用它们可以让文档更加清晰易读。
</details>

---

**提示**: Details 块非常适合用于：
- FAQ 页面
- 文档中的可选详细信息
- 长列表或大量内容的折叠
- 教程中的提示和解答
''',
    ),
    MarkdownExample(
      title: 'Complex Example',
      markdown: '''
# 🚀 完整 Markdown 功能展示

欢迎来到 **Flutter Smooth Markdown** 的完整功能演示页面！这里展示了所有支持的 Markdown 语法和增强 UI 组件。

![美丽的风景](https://images.unsplash.com/photo-1762966160841-37423cb6c242?q=80&w=2487&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D)

## 一、标题层级展示

所有六级标题都支持，增强模式下 H1 和 H2 带有彩色装饰和渐变边框。

# H1 - 一级标题
## H2 - 二级标题
### H3 - 三级标题
#### H4 - 四级标题
##### H5 - 五级标题
###### H6 - 六级标题

### 1.1 标题中的行内格式 ✨ 新功能

标题现在支持所有行内格式，包括粗体、斜体、代码、链接等！

## 📝 **我的建议** - 粗体标题

### 这是 *斜体* 文本的标题

### **粗体** 和 *斜体* 混合标题

### 使用 `代码` 的标题示例

### 查看 [Flutter 文档](https://flutter.dev) 获取更多信息

### 🎉 **庆祝活动** 现在 *开始* 啦！

### ⚡ 性能 **优化** 指南 `v2.0`

### 🚀 **快速开始**: 运行 `flutter create` 创建项目

---

## 二、文本样式

### 2.1 基础文本样式

你可以使用 **粗体文本** 来强调重要内容，使用 *斜体文本* 来表达语气，使用 ~~删除线~~ 来标记废弃内容，还可以使用 `行内代码` 来标记代码片段。

### 2.2 混合样式

这是一个包含 **粗体**、*斜体*、`代码`、~~删除线~~ 和 [链接](https://flutter.dev) 的混合段落。你甚至可以写 ***粗斜体*** 文本！

---

## 三、代码展示

### 3.1 Dart 代码

增强的代码块支持复制按钮、语言标签和悬停效果（移动端复制按钮始终显示）：

```dart
// Flutter 应用入口
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Smooth Markdown',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// 使用增强组件渲染 Markdown
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Markdown Demo')),
      body: SmoothMarkdown(
        data: '# Hello **World**\\n\\nThis is *amazing*!',
        useEnhancedComponents: true,
        styleSheet: MarkdownStyleSheet.github(),
      ),
    );
  }
}
```

### 3.2 JavaScript 代码

```javascript
// 现代 JavaScript 异步编程
async function fetchUserData(userId) {
  try {
    const response = await fetch('/api/users/' + userId);
    const data = await response.json();

    return {
      ...data,
      timestamp: new Date().toISOString(),
      status: 'success'
    };
  } catch (error) {
    console.error('Error fetching user:', error);
    throw new Error('Failed to load user ' + userId);
  }
}

// 使用箭头函数和解构
const processUsers = users => users
  .filter(({ active }) => active)
  .map(({ id, name, email }) => ({ id, name, email }))
  .sort((a, b) => a.name.localeCompare(b.name));
```

### 3.3 Python 代码

```python
# Python 数据处理示例
import pandas as pd
import numpy as np
from typing import List, Dict, Optional

class DataAnalyzer:
    """强大的数据分析器"""

    def __init__(self, data: pd.DataFrame):
        self.data = data
        self.results: Dict[str, any] = {}

    def analyze(self, columns: List[str]) -> Dict[str, float]:
        """分析指定列的统计信息"""
        stats = {}
        for col in columns:
            if col in self.data.columns:
                stats[col] = {
                    'mean': self.data[col].mean(),
                    'median': self.data[col].median(),
                    'std': self.data[col].std(),
                    'min': self.data[col].min(),
                    'max': self.data[col].max()
                }
        return stats

    @staticmethod
    def normalize(values: np.ndarray) -> np.ndarray:
        """归一化数值"""
        return (values - values.min()) / (values.max() - values.min())

# 使用示例
df = pd.read_csv('data.csv')
analyzer = DataAnalyzer(df)
results = analyzer.analyze(['price', 'quantity', 'rating'])
print(f"Analysis complete: {len(results)} columns processed")
```

### 3.4 行内代码

在段落中使用 `const variable = 'value'` 这样的行内代码，或者 `npm install package-name` 这样的命令。

---

## 四、列表功能

### 4.1 无序列表

购物清单：
- 新鲜水果
  - 苹果 🍎
  - 香蕉 🍌
  - 橙子 🍊
- 蔬菜
  - 西红柿 🍅
  - 黄瓜 🥒
  - 胡萝卜 🥕
- 日用品
  - 洗发水
  - 牙膏
  - 纸巾

### 4.2 有序列表

开发流程：
1. **需求分析**
   1. 收集用户需求
   2. 编写需求文档
   3. 评审和确认
2. **设计阶段**
   1. UI/UX 设计
   2. 架构设计
   3. 数据库设计
3. **开发实现**
   1. 编码实现
   2. 单元测试
   3. 代码审查
4. **测试部署**
   1. 集成测试
   2. 性能测试
   3. 生产部署

### 4.3 任务列表

项目进度：
- [x] ✅ 完成项目初始化
- [x] ✅ 实现 Markdown 解析器
- [x] ✅ 创建渲染引擎
- [x] ✅ 添加增强 UI 组件
- [x] ✅ 支持多主题切换
- [ ] ⏳ 实现流式渲染
- [ ] ⏳ 添加语法高亮
- [ ] 📋 性能优化
- [ ] 📋 编写完整文档

---

## 五、引用块

### 5.1 单行引用

> 简洁是智慧的灵魂。 —— 莎士比亚

### 5.2 多行引用

增强的引用块带有引号图标、渐变背景和阴影效果：

> **关于优秀代码的思考**
>
> 任何傻瓜都能写出计算机能理解的代码。
> 优秀的程序员能写出人类能理解的代码。
>
> 代码是写给人看的，只是顺便让机器执行而已。
>
> —— Martin Fowler

### 5.3 嵌套引用

> 这是第一层引用
>
> > 这是第二层嵌套引用
> >
> > > 这是第三层嵌套引用
> > > 包含多种层级的内容
> >
> > 回到第二层
>
> 回到第一层引用

---

## 六、链接展示

### 6.1 外部链接

增强的链接带有悬停动画和外部链接图标：

- [Flutter 官方网站](https://flutter.dev) - 学习 Flutter 开发
- [Dart 语言官网](https://dart.dev) - Dart 编程语言
- [GitHub](https://github.com) - 代码托管平台
- [Stack Overflow](https://stackoverflow.com) - 开发者问答社区
- [pub.dev](https://pub.dev) - Flutter/Dart 包管理

### 6.2 内部链接

- [跳转到顶部](#-完整-markdown-功能展示)
- [查看代码示例](#三代码展示)
- [查看列表功能](#四列表功能)

### 6.3 链接和文本混合

访问 [Flutter Smooth Markdown](https://github.com/JackCaow/flutter-smooth-markdown) 项目了解更多信息。这个包提供了 **高性能** 的 Markdown 渲染，支持 *增强 UI 组件* 和 `流式渲染`。

---

## 七、分隔线

使用三个或更多连字符创建分隔线：

---

上面和下面都有分隔线！

---

## 八、图片展示

### 8.1 网络图片

![自然美景 - Unsplash](https://images.unsplash.com/photo-1762966160841-37423cb6c242?q=80&w=2487&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D)

### 8.2 带标题的图片

![Flutter Logo](https://storage.googleapis.com/cms-storage-bucket/4fd0db61df0567c0f352.png "Flutter - 谷歌推出的跨平台 UI 框架")

### 8.3 SVG 矢量图

![SVG Icon](https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/flutter.svg)

> SVG 图片支持自动缩放，不会失真，完美适配各种屏幕尺寸。

---

## 九、表格

| 功能 | 标准组件 | 增强组件 | 说明 |
|------|---------|---------|------|
| 代码块 | ✅ | ✅ 复制按钮 | 支持语法高亮 |
| 引用 | ✅ | ✅ 图标装饰 | 渐变背景 |
| 链接 | ✅ | ✅ 悬停动画 | 外链图标 |
| 标题 | ✅ | ✅ 彩色标记 | 渐变边框 |

### 表格对齐示例

| 左对齐 | 居中对齐 | 右对齐 |
|:-------|:-------:|-------:|
| 左     | 中      | 右     |
| Left   | Center  | Right  |
| 数据1  | 数据2   | 数据3  |

### 复杂表格示例

| 编程语言 | 类型 | 发布年份 | 主要用途 |
|---------|:----:|:--------:|---------|
| **Python** | 动态 | 1991 | AI、数据科学、Web |
| **JavaScript** | 动态 | 1995 | Web 前端、后端 |
| **Dart** | 静态 | 2011 | Flutter 应用开发 |
| **Rust** | 静态 | 2010 | 系统编程、性能 |

---

## 十、综合示例

### 10.1 技术文档示例

**函数说明：** `calculateDistance()`

计算两点之间的欧几里得距离。

**参数：**
- `point1` (*Object*): 第一个点，包含 `x` 和 `y` 坐标
- `point2` (*Object*): 第二个点，包含 `x` 和 `y` 坐标

**返回值：**
- (*Number*): 两点之间的距离

**示例代码：**

```javascript
const distance = calculateDistance(
  { x: 0, y: 0 },
  { x: 3, y: 4 }
);
console.log(distance); // 输出: 5
```

> **注意：** 此函数假设使用笛卡尔坐标系。

---

## 十、Mermaid 图表

Mermaid 是一种基于文本的图表绘制工具，支持流程图、时序图、饼图、甘特图等多种类型。

### 10.1 流程图 (Flowchart)

展示软件开发流程：

```mermaid
graph TD
    A[需求分析] --> B{可行吗?}
    B -->|是| C[系统设计]
    B -->|否| D[重新评估]
    D --> A
    C --> E[编码实现]
    E --> F[代码审查]
    F --> G{通过?}
    G -->|是| H[测试]
    G -->|否| E
    H --> I[部署上线]
    I --> J[维护监控]
```

### 10.2 时序图 (Sequence Diagram)

展示用户认证流程：

```mermaid
sequenceDiagram
    participant U as 用户
    participant C as 客户端
    participant S as 服务器
    participant D as 数据库
    U->>C: 输入账号密码
    C->>S: POST /api/login
    S->>D: 查询用户信息
    D-->>S: 返回用户数据
    S-->>C: JWT Token
    C-->>U: 登录成功
```

### 10.3 饼图 (Pie Chart)

展示项目时间分配：

```mermaid
pie showData
    title 开发时间分配
    "编码开发" : 45
    "测试调试" : 25
    "文档编写" : 15
    "会议沟通" : 10
    "其他" : 5
```

### 10.4 甘特图 (Gantt Chart)

展示项目里程碑：

```mermaid
gantt
    title Flutter App 开发计划
    dateFormat YYYY-MM-DD

    section 设计阶段
        需求分析 :done, req, 2024-01-01, 7d
        UI设计 :done, ui, after req, 10d

    section 开发阶段
        核心功能 :active, core, 2024-01-18, 20d
        API集成 :api, after core, 10d

    section 发布阶段
        测试 :test, 2024-02-17, 7d
        上线 :milestone, launch, 2024-02-24, 0d
```

---

## 十一、功能总结

本页面展示了以下所有功能：

### ✅ 已实现
1. **标题** - 6 级标题，H1/H2 带装饰
2. **文本样式** - 粗体、斜体、删除线、行内代码
3. **代码块** - 带复制按钮和语言标签
4. **语法高亮** - 代码块语法着色（支持 Dart、JavaScript、Python 等）
5. **列表** - 无序、有序、任务列表
6. **引用** - 单层和嵌套引用
7. **链接** - 悬停动画和外链图标
8. **图片** - 网络图片加载，支持 PNG/JPEG/GIF/WebP/SVG
9. **分隔线** - 水平分隔线
10. **表格** - 完整的 GFM 表格支持，带对齐
11. **流式渲染** - 实时内容更新（侧边栏"演示"部分查看）
12. **数学公式** - LaTeX 数学表达式（侧边栏"演示"部分查看）
13. **脚注** - 文档脚注支持，支持自定义样式（侧边栏"演示"部分查看）
14. **主题** - 6 种预设主题
15. **Mermaid 图表** - 流程图、时序图、饼图、甘特图

---

## 🎉 结语

感谢使用 **Flutter Smooth Markdown**！

如果你喜欢这个项目，请：
- ⭐ 在 [GitHub](https://github.com/JackCaow/flutter-smooth-markdown) 上给个星标
- 📢 分享给更多开发者
- 🐛 报告问题和建议
- 💡 贡献代码和想法

**Happy Coding!** 🚀✨
''',
    ),
  ];

  MarkdownStyleSheet _getStyleSheet() {
    switch (_selectedTheme) {
      case MarkdownTheme.defaultLight:
        return MarkdownStyleSheet.light();
      case MarkdownTheme.defaultDark:
        return MarkdownStyleSheet.dark();
      case MarkdownTheme.github:
        return MarkdownStyleSheet.github();
      case MarkdownTheme.githubDark:
        return MarkdownStyleSheet.github(brightness: Brightness.dark);
      case MarkdownTheme.vscode:
        return MarkdownStyleSheet.vscode();
      case MarkdownTheme.vscodeDark:
        return MarkdownStyleSheet.vscode(brightness: Brightness.dark);
    }
  }

  void _openEditorPreview() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const EditorDemoPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final example = _examples[_selectedIndex];
    final styleSheet = _getStyleSheet();
    final isDark = _selectedTheme.brightness == Brightness.dark;

    return Theme(
      data: isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF161B22) : null,
          foregroundColor: isDark ? Colors.white : null,
          elevation: 0,
          title: const Text('Smooth Markdown Demo'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_note),
              tooltip: 'Open editor preview',
              onPressed: _openEditorPreview,
            ),
            PopupMenuButton<MarkdownTheme>(
              icon: const Icon(Icons.palette),
              tooltip: AppLocalizations.of(context).translate('tooltip_theme'),
              color: isDark ? const Color(0xFF161B22) : null,
              onSelected: (theme) {
                setState(() {
                  _selectedTheme = theme;
                });
              },
              itemBuilder: (context) => MarkdownTheme.values.map((theme) {
                return PopupMenuItem(
                  value: theme,
                  child: Row(
                    children: [
                      Icon(
                        theme == _selectedTheme
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 20,
                        color: theme == _selectedTheme
                            ? (isDark ? Colors.blue[300] : Colors.blue)
                            : (isDark ? Colors.white70 : null),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        theme.getLabel(context),
                        style: TextStyle(
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        theme.brightness == Brightness.dark
                            ? Icons.dark_mode
                            : Icons.light_mode,
                        size: 16,
                        color: isDark ? Colors.white70 : null,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: isDark ? const Color(0xFF0D1117) : null,
          child: ListView(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF161B22), const Color(0xFF21262D)]
                        : [Colors.blue, Colors.purple],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.article, size: 48, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)
                          .translate('drawer_header_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.edit_note,
                  color: isDark ? Colors.white70 : null,
                ),
                title: Text(
                  'Markdown Editor',
                  style: TextStyle(color: isDark ? Colors.white : null),
                ),
                subtitle: Text(
                  'Scratch-style editing preview',
                  style: TextStyle(color: isDark ? Colors.white54 : null),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openEditorPreview();
                },
              ),
              const Divider(),
              ...List.generate(_examples.length, (index) {
                return ListTile(
                  leading: Icon(
                    _getIconForExample(index),
                    color: _selectedIndex == index
                        ? (isDark ? Colors.blue[300] : Colors.blue)
                        : (isDark ? Colors.white70 : null),
                  ),
                  title: Text(
                    _examples[index].title,
                    style: TextStyle(
                      fontWeight: _selectedIndex == index
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                  selected: _selectedIndex == index,
                  selectedTileColor: isDark ? const Color(0xFF161B22) : null,
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  AppLocalizations.of(context).drawerDemos,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.calculate,
                  color: isDark ? Colors.white70 : null,
                ),
                title: Text(
                  AppLocalizations.of(context).demoMath,
                  style: TextStyle(
                    color: isDark ? Colors.white : null,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MathDemo(
                        styleSheet: _getStyleSheet(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.stream,
                  color: isDark ? Colors.white70 : null,
                ),
                title: Text(
                  AppLocalizations.of(context).demoStreaming,
                  style: TextStyle(
                    color: isDark ? Colors.white : null,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StreamingMarkdownDemo(
                        styleSheet: _getStyleSheet(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.note_add,
                  color: isDark ? Colors.white70 : null,
                ),
                title: Text(
                  AppLocalizations.of(context).demoFootnote,
                  style: TextStyle(
                    color: isDark ? Colors.white : null,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FootnoteDemo(
                        styleSheet: _getStyleSheet(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.chat,
                  color: isDark ? Colors.white70 : null,
                ),
                title: Text(
                  'Chat List Demo',
                  style: TextStyle(
                    color: isDark ? Colors.white : null,
                  ),
                ),
                subtitle: Text(
                  'Performance optimizations',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatListDemo(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.auto_awesome,
                  color: isDark ? Colors.white70 : null,
                ),
                title: Text(
                  'AI Chat Demo',
                  style: TextStyle(
                    color: isDark ? Colors.white : null,
                  ),
                ),
                subtitle: Text(
                  'Qwen API + Thinking/Artifact/Tool',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AIChatDemo(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.forum,
                  color: isDark ? Colors.white70 : null,
                ),
                title: Text(
                  'Conversation List',
                  style: TextStyle(
                    color: isDark ? Colors.white : null,
                  ),
                ),
                subtitle: Text(
                  '长按菜单 · 滑动操作 · 多选',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ConversationListDemo(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.extension,
                  color: isDark ? Colors.white70 : null,
                ),
                title: Text(
                  'Plugin System',
                  style: TextStyle(
                    color: isDark ? Colors.white : null,
                  ),
                ),
                subtitle: Text(
                  '@mention #hashtag :emoji:',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PluginDemo(
                        styleSheet: _getStyleSheet(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.schema,
                  color: isDark ? Colors.white70 : null,
                ),
                title: Text(
                  'Mermaid 图表',
                  style: TextStyle(
                    color: isDark ? Colors.white : null,
                  ),
                ),
                subtitle: Text(
                  '流程图、时序图',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MermaidDemo(),
                    ),
                  );
                },
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  AppLocalizations.of(context).language,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
              ),
              ...AppLanguage.values.map((lang) {
                return ListTile(
                  leading: Icon(
                    Icons.language,
                    color: isDark ? Colors.white70 : null,
                  ),
                  title: Text(
                    lang.nativeName,
                    style: TextStyle(
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                  onTap: () {
                    widget.onLanguageChange(lang.locale);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF161B22)
                    : Theme.of(context).colorScheme.primaryContainer,
                border: Border(
                  bottom: BorderSide(
                    color:
                        isDark ? const Color(0xFF30363D) : Colors.grey.shade300,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getIconForExample(_selectedIndex),
                    color: isDark
                        ? Colors.white
                        : Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      example.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: isDark
                                ? Colors.white
                                : Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                          ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF21262D)
                          : Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedTheme.brightness == Brightness.dark
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          size: 16,
                          color: isDark
                              ? Colors.white70
                              : Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedTheme.getLabel(context),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white70
                                : Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF0D1117) : Colors.white,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SmoothMarkdown(
                    data: example.markdown,
                    styleSheet: styleSheet,
                    plugins: _mermaidPlugins,
                    builderRegistry: _mermaidBuilders,
                    onTapLink: (url) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Link tapped: $url'),
                          duration: const Duration(seconds: 2),
                          backgroundColor:
                              isDark ? const Color(0xFF161B22) : null,
                        ),
                      );
                    },
                    // Enable enhanced code blocks with copy button
                    useEnhancedComponents: true,
                    selectable: true,
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (context) => Theme(
                data: isDark ? ThemeData.dark() : ThemeData.light(),
                child: AlertDialog(
                  backgroundColor:
                      isDark ? const Color(0xFF161B22) : Colors.white,
                  title: Text(
                    'Markdown Source',
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black),
                  ),
                  content: Container(
                    width: 600,
                    constraints: const BoxConstraints(maxHeight: 500),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        example.markdown,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            );
          },
          tooltip: 'View Markdown Source',
          child: const Icon(Icons.code),
        ),
      ),
    );
  }

  IconData _getIconForExample(int index) {
    switch (index) {
      case 0:
        return Icons.format_bold;
      case 1:
        return Icons.title;
      case 2:
        return Icons.list;
      case 3:
        return Icons.code;
      case 4:
        return Icons.format_quote;
      case 5:
        return Icons.link;
      case 6:
        return Icons.auto_awesome; // Enhanced UI
      case 7:
        return Icons.palette; // Theme Showcase
      case 8:
        return Icons.dashboard; // Complex Example
      default:
        return Icons.article;
    }
  }
}

class MarkdownExample {
  const MarkdownExample({
    required this.title,
    required this.markdown,
  });

  final String title;
  final String markdown;
}
