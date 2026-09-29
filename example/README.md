# Flutter Smooth Markdown Example

这是一个展示 `flutter_smooth_markdown` 包功能的示例应用。

## 功能展示

示例应用包含以下 Markdown 功能演示：

1. **基础格式化** - 粗体、斜体、删除线、行内代码
2. **标题** - H1-H6 各级标题
3. **列表** - 无序列表、有序列表、任务列表
4. **代码块** - 带语法高亮的代码块
5. **引用和分隔线** - 块引用和水平分隔线
6. **链接和图片** - 可点击的链接和图片展示
7. **综合示例** - 所有功能的组合使用

## 运行示例

### Web (Chrome)

```bash
cd example
flutter run -d chrome
```

### 使用本地 DeepSeek Key 开发 AI Chat

先确保 Key 已保存在 macOS Keychain 的 `smooth-markdown-deepseek-dev` 条目中，然后启动调试版（可把 `macos` 换成其他设备）：

```bash
cd example
./run_with_deepseek.sh -d macos
```

脚本从 Keychain 读取 Key，生成运行期间使用的临时 JSON 文件，并通过 Flutter 的 `--dart-define-from-file` 注入；临时文件被 Git 忽略，并在应用退出后删除。普通 `flutter run` 未注入 Key 时，AI Chat 自动使用模拟响应。调试产物会包含该 Key，请勿分发。也可以在 AI Chat 的设置中临时输入 Key，该输入只保留在当前运行的应用内存中。

### Markdown Editor Preview

```bash
cd example
flutter run -d chrome -t lib/editor_preview_main.dart
```

这个入口会直接打开 `SmoothMarkdownEditor` 预览页，适合调试 Scratch-style 编辑态、格式化块编辑、源码/预览切换和复制导出流程。
主示例应用也在侧边栏提供 Markdown Editor 页面，代码位于 `example/lib/editor_demo.dart`。

### macOS

```bash
cd example
flutter run -d macos
```

### iOS

```bash
cd example
flutter run -d ios
```

### Android

```bash
cd example
flutter run -d android
```

## 主要特性

- 🎨 **主题切换** - 支持亮色/暗色主题
- 📱 **响应式设计** - 适配不同屏幕尺寸
- 🔗 **链接点击** - 点击链接显示提示
- 📝 **源码查看** - 点击浮动按钮查看 Markdown 源码
- ✏️ **Markdown 编辑器** - 侧边栏入口和独立预览入口
- 🎯 **侧边栏导航** - 快速切换不同示例

## 代码示例

### 基本使用

```dart
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

SmoothMarkdown(
  data: '# Hello **World**',
  styleSheet: MarkdownStyleSheet.light(),
  onTapLink: (url) => print('Tapped: $url'),
)
```

### 自定义样式

```dart
SmoothMarkdown(
  data: markdownText,
  styleSheet: MarkdownStyleSheet(
    h1Style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    textStyle: TextStyle(fontSize: 16),
    codeBlockDecoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(8),
    ),
  ),
)
```

### 自定义构建器

```dart
SmoothMarkdown(
  data: markdownText,
  codeBuilder: (code, language) {
    return CustomCodeWidget(code: code, language: language);
  },
  imageBuilder: (url, alt, title) {
    return CustomImageWidget(url: url);
  },
)
```

## 项目结构

```
example/
├── lib/
│   ├── main.dart                 # 主示例应用和侧边栏入口
│   ├── editor_demo.dart          # SmoothMarkdownEditor 示例页面
│   └── editor_preview_main.dart  # 独立编辑器预览入口
├── pubspec.yaml            # 依赖配置
└── README.md               # 本文件
```

## 依赖

示例应用依赖于本地的 `flutter_smooth_markdown` 包：

```yaml
dependencies:
  flutter_smooth_markdown:
    path: ../
```

## 了解更多

- [Flutter Smooth Markdown 文档](../README.md)
- [Flutter 官方文档](https://flutter.dev)
- [Markdown 语法指南](https://www.markdownguide.org)
