# Flutter Smooth Markdown

[![pub package](https://img.shields.io/pub/v/flutter_smooth_markdown.svg)](https://pub.dev/packages/flutter_smooth_markdown)
[![popularity](https://img.shields.io/pub/popularity/flutter_smooth_markdown.svg)](https://pub.dev/packages/flutter_smooth_markdown/score)
[![likes](https://img.shields.io/pub/likes/flutter_smooth_markdown.svg)](https://pub.dev/packages/flutter_smooth_markdown/score)
[![GitHub stars](https://img.shields.io/github/stars/JackCaow/flutter-smooth-markdown?style=flat&logo=github)](https://github.com/JackCaow/flutter-smooth-markdown/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/JackCaow/flutter-smooth-markdown?style=flat&logo=github)](https://github.com/JackCaow/flutter-smooth-markdown/network/members)
[![GitHub issues](https://img.shields.io/github/issues/JackCaow/flutter-smooth-markdown)](https://github.com/JackCaow/flutter-smooth-markdown/issues)
[![GitHub license](https://img.shields.io/github/license/JackCaow/flutter-smooth-markdown)](https://github.com/JackCaow/flutter-smooth-markdown/blob/main/LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.0.0-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.0.0-0175C2?logo=dart)](https://dart.dev)

A high-performance Flutter markdown renderer with syntax highlighting, LaTeX math, tables, footnotes, SVG images, Mermaid diagrams, and real-time streaming support.

## Features

| Category | Features |
|----------|----------|
| **Rendering** | AST-based parsing, syntax highlighting, real-time streaming, text selection |
| **Editing** | Formatted/source/preview/split editor, formatting toolbar, slash commands, wikilinks, find |
| **Markdown** | Headers (with inline formatting), lists, tables, code blocks, blockquotes, links, images |
| **Math & Charts** | LaTeX formulas, Mermaid diagrams (flowcharts, Gantt, Kanban, Timeline, Radar, XY Chart, pie, sequence) |
| **Extras** | Footnotes, SVG support, collapsible sections, task lists |
| **Theming** | Light/dark modes, GitHub/VS Code presets, custom themes |
| **Plugins** | Mentions, hashtags, emojis, AI chat blocks (thinking, artifacts) |

## Demo

<table>
<tr>
<td><img src="https://raw.githubusercontent.com/JackCaow/flutter-smooth-markdown/main/screenshots/main.jpg" width="280" alt="Main Interface"></td>
<td><img src="https://raw.githubusercontent.com/JackCaow/flutter-smooth-markdown/main/screenshots/code.jpg" width="280" alt="Code Blocks"></td>
<td><img src="https://raw.githubusercontent.com/JackCaow/flutter-smooth-markdown/main/screenshots/latx.jpg" width="280" alt="LaTeX Math"></td>
</tr>
<tr>
<td align="center">Main Interface</td>
<td align="center">Code Blocks</td>
<td align="center">LaTeX Math</td>
</tr>
</table>

<img src="https://raw.githubusercontent.com/JackCaow/flutter-smooth-markdown/main/screenshots/streaming.gif" width="600" alt="Real-time Streaming">

> Run the example app: `cd example && flutter run`
>
> Run the editor preview directly in Chrome: `cd example && flutter run -d chrome -t lib/editor_preview_main.dart`
>
> The full example app also exposes the editor from the sidebar in `example/lib/editor_demo.dart`.

## Quick Start

### Installation

```yaml
dependencies:
  flutter_smooth_markdown: ^0.7.4
```

```bash
flutter pub get
```

### Basic Usage

```dart
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

SmoothMarkdown(
  data: '# Hello Markdown\n\nThis is **bold** and *italic*.',
  styleSheet: MarkdownStyleSheet.light(),
  onTapLink: (url) => print('Tapped: $url'),
)
```

### Selectable Text

```dart
SmoothMarkdown(
  data: markdownText,
  selectable: true,
  onTapImage: (url, alt, title) {
    showImagePreview(context, url);
  },
)
```

Selection handles work across text and non-text blocks (images, tables, etc.). Copied content is automatically cleaned.

### Markdown Editor

```dart
final editorController = MarkdownEditorController(text: '# Scratch note');

SmoothMarkdownEditor(
  controller: editorController,
  initialMode: MarkdownEditorMode.formatted,
  wikilinkSuggestions: const ['Daily Notes', 'Project Plan'],
  onChanged: (markdown) => saveDraft(markdown),
  onTapWikilink: (target) => openNote(target),
  onExportMarkdown: (markdown) => saveMarkdownFile(markdown),
)
```

`SmoothMarkdownEditor` keeps Markdown source as the document of record and renders
the preview with `SmoothMarkdown`. It includes Scratch-inspired editor controls:
formatting commands, `Cmd/Ctrl+B`, `Cmd/Ctrl+I`, `Cmd/Ctrl+K`, `Cmd/Ctrl+F`,
`Cmd/Ctrl+Shift+M`, `Cmd/Ctrl+Shift+Enter`, `/` commands, `[[wikilink]]`
autocomplete, formatted block editing, code-block language selection, Mermaid
preview/source toggling, block math editing, copy-as-Markdown/plain-text/HTML,
Markdown import/export callbacks, focus mode, and source, preview, or split layouts.

File-oriented editor actions are intentionally callback-based so apps can choose
their own desktop, mobile, or web integrations. When callbacks are omitted,
`Export Markdown` copies Markdown to the clipboard, `Print as PDF` copies the
generated HTML fallback, `Import Markdown` is hidden, and image insertion uses
the built-in URL dialog. Provide `onExportMarkdown`, `onExportPdf`,
`onImportMarkdown`, and `onPickImage` to connect file pickers, print/PDF
packages, asset uploads, or platform share sheets.

The core package does not ship default file picker, printing, share, upload, or
platform image picker adapters; keep those integrations in the host app and
route them through the callbacks above. The exported editor document model
types are available for advanced integrations, but should be treated as
experimental until the editor API is finalized.

### Programmatic Selection

When `selectable: true`, the content is wrapped in a `SmoothSelectionRegion` (a thin `SelectableRegion` adapter). Pass a `selectionController` to drive selection programmatically:

```dart
final controller = SmoothSelectionController();

SmoothMarkdown(
  data: markdownText,
  selectable: true,
  selectionController: controller,
)

// Later — enter selection mode with handles + toolbar:
controller.selectAll(SelectionChangedCause.toolbar);

// Or select text around a press position:
controller.selectParagraphAt(details.globalPosition);
```

The selection rule lives in your application code. For example, a chat bubble
menu can choose paragraph selection while an editor toolbar chooses select-all:

```dart
void handleSelectText(Offset pressPosition) {
  switch (selectionMode) {
    case SelectionMode.word:
      controller.selectWordAt(pressPosition);
      return;
    case SelectionMode.paragraph:
      controller.selectParagraphAt(pressPosition);
      return;
    case SelectionMode.message:
      controller.selectAll(SelectionChangedCause.toolbar);
      return;
  }
}
```

For lower-level control, `SmoothSelectionController` exposes the underlying `SelectionContainer` + `SelectionEvent` machinery:

```dart
// Clear the current selection (hides handles + toolbar):
controller.clearSelection();

// Dispatch an arbitrary SelectionEvent straight to the SelectionContainer
// (fans out to every text selectable). Does not drive the overlay by itself.
controller.dispatchEvent(const SelectAllSelectionEvent());

// Reach the SelectionRegistrar collecting the text selectables.
final registrar = controller.registrar;
```

`contextMenuBuilder` (if provided) now receives a `SmoothSelectionRegionState`, giving the menu access to `dispatchEvent`, `registrar`, `contextMenuButtonItems`, and `contextMenuAnchors`.

`selectableRegionKey` is still available for advanced integrations that need direct access to `SmoothSelectionRegionState`.

> **Migration (minor breaking):** `selectableRegionKey` is now typed `GlobalKey<SmoothSelectionRegionState>` (was `GlobalKey<SelectableRegionState>`), and `contextMenuBuilder`'s second parameter is now `SmoothSelectionRegionState`. Rename the type and the new methods become available; existing calls (`selectAll`, `contextMenuButtonItems`, `contextMenuAnchors`) work unchanged. New code should prefer `selectionController`.

### Streaming (Real-time)

```dart
StreamMarkdown(
  stream: yourMarkdownStream,
  styleSheet: MarkdownStyleSheet.dark(),
)
```

### Enhanced Components

```dart
final renderer = MarkdownRenderer(styleSheet: MarkdownStyleSheet.light());

renderer.builderRegistry
  ..register('code_block', const EnhancedCodeBlockBuilder())
  ..register('blockquote', const EnhancedBlockquoteBuilder())
  ..register('link', const EnhancedLinkBuilder())
  ..register('header', const EnhancedHeaderBuilder());

final nodes = MarkdownParser().parse(markdownText);
final widget = renderer.render(nodes);
```

## Theming

```dart
// Built-in themes
MarkdownStyleSheet.light()
MarkdownStyleSheet.dark()
MarkdownStyleSheet.github(brightness: Brightness.light)
MarkdownStyleSheet.vscode(brightness: Brightness.dark)

// From Flutter theme
MarkdownStyleSheet.fromTheme(Theme.of(context))

// Custom
MarkdownStyleSheet.light().copyWith(
  h1Style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
  linkStyle: TextStyle(color: Colors.blue),
)
```

## Plugins

```dart
// Custom syntax plugins
final registry = ParserPluginRegistry();
registry.register(const MentionPlugin());    // @username
registry.register(const HashtagPlugin());    // #topic
registry.register(const EmojiPlugin());      // :smile:

final parser = MarkdownParser(plugins: registry);
```

### AI Chat Plugins

```dart
registry.register(const ThinkingPlugin());   // <thinking>...</thinking>
registry.register(const ArtifactPlugin());   // <artifact>...</artifact>
registry.register(const ToolCallPlugin());   // <tool_use>...</tool_use>
```

## Mermaid Diagrams

```dart
MermaidDiagram(
  code: '''
  graph TD
    A[Start] --> B{Decision}
    B -->|Yes| C[Action]
    B -->|No| D[End]
  ''',
  style: MermaidStyle.dark(),
)
```

Supports: Flowcharts, Sequence Diagrams, Pie Charts, Gantt Charts, Kanban Boards, Timeline Diagrams, Radar Charts, **XY Charts**

### XY Chart Example

```dart
MermaidDiagram(
  code: '''
  xychart-beta
    title "Sales Revenue"
    x-axis [Q1, Q2, Q3, Q4]
    y-axis "Revenue" 0 --> 100
    bar [23, 45, 67, 89]
    line [20, 50, 60, 85]
  ''',
)
```

### Radar Chart Example

```dart
MermaidDiagram(
  code: '''
  radar-beta
    title Skills Assessment
    axis Programming, Design, Communication, Management, Innovation
    curve Alice{5, 3, 4, 2, 4}
    curve Bob{3, 5, 3, 4, 3}
    showLegend true
    max 5
    graticule polygon
  ''',
)
```

## Markdown Syntax

<details>
<summary>Text Formatting</summary>

```markdown
**Bold** or __Bold__
*Italic* or _Italic_
~~Strikethrough~~
`Inline code`
```
</details>

<details>
<summary>Lists & Tasks</summary>

```markdown
- Unordered item
1. Ordered item
- [ ] Task
- [x] Completed task
```
</details>

<details>
<summary>Code Blocks</summary>

````markdown
```dart
void main() {
  print('Hello, World!');
}
```
````
</details>

<details>
<summary>Tables</summary>

```markdown
| Header 1 | Header 2 |
|----------|----------|
| Cell 1   | Cell 2   |
```
</details>

<details>
<summary>Math (LaTeX)</summary>

```markdown
Inline: $E = mc^2$

Block:
$$
\int_{a}^{b} f(x) dx = F(b) - F(a)
$$
```
</details>

<details>
<summary>Footnotes</summary>

```markdown
Text with footnote[^1].

[^1]: Footnote content.
```
</details>

<details>
<summary>Collapsible Sections</summary>

```markdown
<details>
<summary>Click to expand</summary>
Hidden content here.
</details>
```
</details>

## Use Cases

- Documentation apps with code examples
- Chat applications with rich text
- Note-taking apps
- Educational platforms with LaTeX
- AI chat interfaces with streaming

## Documentation

| Document | Description |
|----------|-------------|
| [Plugin System](doc/插件系统.md) | Custom parser plugins |
| [Theme System](doc/主题系统.md) | Theming guide |
| [Enhanced Components](doc/使用增强组件.md) | Rich UI components |
| [Architecture](doc/架构设计.md) | System architecture |

## Roadmap

**Completed**: Core parser, renderer, themes, streaming, math, tables, footnotes, SVG, plugins, Mermaid diagrams, AI chat plugins, i18n (6 languages)

**In Progress**: Performance optimization, API documentation

**Planned**: More themes, advanced tables, accessibility

## Contributing

Contributions welcome! Please read our guidelines before submitting PRs.

## License

MIT License

## Links

- [GitHub](https://github.com/JackCaow/flutter-smooth-markdown)
- [Issues](https://github.com/JackCaow/flutter-smooth-markdown/issues)
- [pub.dev](https://pub.dev/packages/flutter_smooth_markdown)

---

Made with love for the Flutter community.
