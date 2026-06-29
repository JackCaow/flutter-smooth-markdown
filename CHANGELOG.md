# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- ✨ **Markdown editor** - Added `SmoothMarkdownEditor` with formatted/source/preview/split modes, formatting commands, slash commands, wikilinks, search, Markdown import/export callbacks, and Scratch-style example entry points.
- ✨ **Formatted blockquote range selection** - Added Shift-click selection, copy, delete, and inline formatting support for contiguous child text blocks inside formatted blockquotes.
- 🧪 **Experimental editor model entry point** - Added `flutter_smooth_markdown_editor_experimental.dart` for low-level editor document model and transaction APIs while keeping the main package root focused on stable renderer/editor widgets and controllers.
- 🧪 **Editor coverage** - Added document, controller, and widget tests for Markdown editing workflows.

## [0.7.4] - 2026-06-17

### Added
- ✨ **Selection controller** - Added `SmoothSelectionController` plus `SmoothMarkdown.selectionController` / `StreamMarkdown.selectionController` as the recommended programmatic selection API. Existing `selectableRegionKey` access remains supported for advanced integrations.
- 🧪 **Tests** - Added coverage for controller attach/detach lifecycle, controller-driven `selectAll`, `StreamMarkdown.selectionController` passthrough, and `selectParagraphAt` clearing an active select-all from padding-adjacent press points.

## [0.7.3] - 2026-06-16

### Changed
- ⚠️ **Selection API (minor breaking)** - `selectable: true` now wraps content in a new `SmoothSelectionRegion` (wraps `SelectableRegion` via composition). `selectableRegionKey` is now typed `GlobalKey<SmoothSelectionRegionState>` (was `GlobalKey<SelectableRegionState>`); `contextMenuBuilder`'s state parameter is now `SmoothSelectionRegionState`. Existing calls (`selectAll`, `contextMenuButtonItems`, `contextMenuAnchors`) work unchanged.
- ⚠️ **Selection controls** - Switched the internal selection controls to the platform-specific handle controls used by `SelectionArea`, so that the user-provided `contextMenuBuilder` is actually consulted by the framework (previously it was never invoked).

### Added
- ✨ **Programmatic selection** - `SmoothSelectionRegionState` exposes `dispatchEvent(SelectionEvent)` (forward any `SelectionEvent`, e.g. `SelectAllSelectionEvent`, to the inner `SelectionContainer`) and `registrar` / `innerRegionState` for advanced control. See README → Programmatic Selection.
- ✨ **Press-positioned selection** - `SmoothSelectionRegionState.selectWordAt(Offset)` / `selectParagraphAt(Offset)` select the word/paragraph under a press point (e.g. a long-press menu's "select text" action) with handles + toolbar, instead of selecting the whole document.
- 🧪 **Tests** - New `test/widgets/smooth_selection_region_test.dart` covering programmatic select-all, `dispatchEvent(SelectAllSelectionEvent)`, registrar exposure, custom `contextMenuBuilder`, and press-positioned word/paragraph selection.

### Fixed
- 🐛 **Custom context menu never shown** - `contextMenuBuilder` was ignored because the legacy `materialTextSelectionControls` path bypasses it; now routed correctly via `materialTextSelectionHandleControls`.
- 🐛 **Example "选择文字" no-op** - `conversation_list_demo` `_triggerSelectAll` relied on a select-all context-menu button that does not exist before any selection exists; replaced with a direct `selectAll(SelectionChangedCause.toolbar)` call (which also reliably summons handles + toolbar).

## [0.7.2] - 2026-04-01

### Fixed
- 🐛 **StreamMarkdown memory leak** - Store and cancel `StreamSubscription` in `dispose()` and on stream change; replace `Future.delayed` throttle with cancellable `Timer`
- 🐛 **StreamMarkdown error handling** - Implement `errorBuilder` support with proper error state management
- 🐛 **Future.delayed leak** in `EnhancedCodeBlockBuilder` and `ArtifactBuilder` - Replace with `Timer` and cancel in `dispose()`
- 🐛 **Selectable text inconsistency** - Fix inverted selectable/non-selectable logic in code block builder when syntax highlighting is off
- 🐛 **Footnote newline loss** - Fix `contentLines.join(' ')` → `join('\n')` to preserve line breaks in multi-line footnotes
- 🐛 **Link/image URL parentheses** - Support nested parentheses in URLs (e.g. `[wiki](https://en.wikipedia.org/wiki/Dart_(language))`)

### Added
- ✨ **Backslash escape support** - CommonMark-compliant `\*`, `\[`, `\]`, `` \` ``, `\~`, `\$`, `\\` etc.
- ♿ **Accessibility semantics** - Add `Semantics` wrappers to links (`link: true`) and images (`image: true`) for screen reader support
- 🧪 **New tests** - 43 new tests covering Math formulas, footnotes, StreamMarkdown widget, backslash escapes, URL parentheses nesting, and recursion depth limits

### Improved
- ⚡ **RegExp performance** - Extract 11 regex patterns to `static final` constants in `BlockParser`, avoiding recompilation on every call
- ⚡ **Recursion depth limit** - Add `_maxDepth = 16` to `InlineParser` to prevent stack overflow on deeply nested input
- 🎨 **Theme consistency** - Replace 6 hard-coded hex colors in `ArtifactBuilder` with `Theme.of(context).colorScheme` tokens
- 🧹 **Magic number cleanup** - Replace `substring(9)` with `substring('<summary>'.length)` in details block parser
- 🏷️ **README badges** - Add GitHub stars, forks, issues, license, Flutter, and Dart shields.io badges

## [0.7.1] - 2026-02-12

### Added
- 📊 **Mermaid XY Chart Support** - Bar and line chart rendering
  - `XYChartData` model with series, axes, categories, and orientation
  - `XYChartParser` for parsing `xychart-beta` / `xychart` syntax
  - `XYChartPainter` for native Flutter rendering with bar and line series
  - Support for categorical x-axis (`[Q1, Q2, Q3, Q4]`) and numeric range (`0 --> 100`)
  - Support for mixed bar + line series in a single chart
  - Grouped bar layout for multiple bar series
  - Chart title, axis titles, and axis labels
  - Horizontal orientation support (`xychart-beta horizontal`)
  - Quoted category labels (`["Q1 2024", "Q2 2024"]`)
  - Negative and decimal values
  - Horizontal grid lines for readability
  - Responsive layout with mobile/tablet/desktop support
  - 3 XY chart examples in demo app
  - 15 unit tests covering parsing and data model

### Fixed
- 🐛 **XY Chart Y-axis scaling** - Fixed `_roundUpToNice` using proper `log10` math instead of string length heuristic

## [0.7.0] - 2026-02-12

### Added
- **Selectable Text Enhancement** - Selection handles now work across non-text blocks
  - Transparent selectable overlay on image-only paragraphs for handle anchoring
  - `DefaultSelectionStyle` with transparent selection color to hide overlay artifacts
  - Automatic clipboard filtering to remove overlay placeholder content on copy
  - Supports both context menu copy and keyboard shortcut (Cmd/Ctrl+C)
- **Image Tap Callback** - New `onTapImage` API for handling image taps
  - `SmoothMarkdown.onTapImage` and `StreamMarkdown.onTapImage` parameters
  - Callback receives `url`, `alt`, and `title` for full image context
  - Works with all image types: network, asset, SVG
  - Compatible with selectable mode (`IgnorePointer` on overlay preserves tap events)

## [0.6.1] - 2026-01-07

### Added
- 📊 **Mermaid Radar Chart Support** - Full radar chart diagram rendering
  - `RadarChartData` model with axes, curves, and configuration options
  - `RadarParser` for parsing Mermaid radar-beta syntax
  - `RadarPainter` for native Flutter rendering with polygon/circle graticules
  - Support for multiple data curves with customizable colors
  - Support for labeled axes (e.g., `axis A["Label A"]`)
  - Support for labeled curves (e.g., `curve c1["Dataset 1"]`)
  - Configuration options: title, showLegend, max, min, graticule (circle/polygon), ticks
  - Full Unicode support including Chinese characters (编程, 设计, etc.)
  - 3 comprehensive radar chart examples in demo app
  - Responsive layout with mobile/tablet/desktop support
  - 14 unit tests covering parsing and data model functionality

### Fixed
- 🐛 **Radar Chart Parsing** - Fixed Unicode character support
  - Changed regex from `\w+` to `.+?` to support non-ASCII characters
  - Now correctly parses Chinese labels (张三, 李四, etc.)
  - Fixed demo app code examples with proper string formatting

### Improved
- Enhanced demo app sidebar with dedicated "Radar Chart" section
- Updated README with radar chart examples and features
- Comprehensive test coverage for Chinese/Unicode label parsing

## [0.6.0] - 2026-01-06

### Added
- ✨ **Header Inline Formatting** - Headers now support all inline formats
  - Headers (H1-H6) can now contain **bold**, *italic*, `code`, [links](url), and ~~strikethrough~~
  - Works with both standard and enhanced header builders
  - Example: `## 📝 **My Suggestion**` renders with proper bold formatting
  - Added comprehensive test coverage for header inline formatting
  - Updated demo examples to showcase the feature

- 📊 **Mermaid Kanban Support** - Full Kanban board diagram rendering
  - `KanbanChartData` model with columns, tasks, and WIP limits
  - `KanbanParser` for parsing Kanban syntax with YAML frontmatter support
  - `KanbanPainter` for native Flutter rendering with card-style design
  - Support for task priorities, assignments, and ticket IDs
  - Visual WIP limit indicators with color-coded warnings
  - 6 comprehensive Kanban examples in demo app
  - Responsive layout for mobile, tablet, and desktop

### Fixed
- 🐛 **Mermaid YAML Frontmatter** - Fixed diagram type detection with YAML config
  - Kanban diagrams with YAML frontmatter now parse correctly
  - Type detection now skips YAML blocks to find actual diagram type
  - Added integration tests for YAML frontmatter support

### Improved
- Enhanced demo app with new header formatting examples
- Better documentation for inline formatting features
- Improved test coverage for parser and renderer components

## [0.5.2] - 2025-12-04

### Added
- 📅 **Mermaid Timeline Support** - Timeline diagram rendering
  - `TimelineChartData` model with sections, periods, and events
  - `TimelineParser` for parsing timeline syntax
  - `TimelinePainter` for native Flutter rendering
  - Support for timeline titles and period labels
  - Multiple events per period
  - 5 new timeline examples in demo app

### Fixed
- 🎯 **Mermaid Diagram Centering** - Fixed initial position not centered
  - Auto-scale diagram to fit viewport while maintaining aspect ratio
  - Proper centering calculation for InteractiveMermaidDiagram
  - Diagram now displays centered on initial load

### Improved
- Better UX for interactive diagrams with smart initial zoom level

## [0.5.1] - 2025-11-26

### Added
- 🎯 **Mermaid Diagram Interactive Mode** - Pan/zoom support for embedded Mermaid diagrams
  - Adaptive height based on diagram content (no fixed 400px)
  - Two-phase rendering: measure first, then apply InteractiveViewer
  - Zoom range: 0.5x to 3.0x scale
  - Infinite boundary margin for free pan/drag movement

### Improved
- 📊 **MermaidBuilder** - Enhanced diagram rendering in markdown
  - `_ScrollableMermaidDiagram` now auto-measures diagram height
  - `_EnhancedMermaidContainer._buildDiagramView()` with same adaptive behavior
  - Better UX for Complex Example demo with all 4 Mermaid types

### Fixed
- Fixed lint warning for unnecessary double literal (5.0 → 5)

## [0.5.0] - 2025-11-26

### Added
- 📊 **Mermaid Gantt Chart Support** - Complete Gantt chart diagram rendering
  - `GanttTask` model with id, name, start/end dates, status, and dependencies
  - `GanttSection` for organizing tasks into groups
  - `GanttChartData` for complete chart configuration
  - Task status support: `done`, `active`, `critical`, `milestone`, `normal`
  - Task dependencies with `after` keyword
  - Multiple date formats and duration formats (30d, 2w, 1M)
  - Timeline header with automatic day/week/month view switching
  - Today marker line
  - Responsive layout support for mobile/tablet/desktop

- 🎨 **Gantt Chart Painter** - Native Flutter rendering
  - Color-coded task bars by status
  - Diamond markers for milestones
  - Section-based alternating row backgrounds
  - Grid lines and timeline headers

- 📱 **Mermaid Demo Updates** - 4 new Gantt chart examples
  - Basic Gantt chart
  - Gantt chart with sections
  - Task status demonstration
  - Product release timeline

### Changed
- Updated topics in pubspec.yaml to include `mermaid` and `charts`
- Added `DiagramType.ganttChart` to diagram type enum
- Integrated Gantt parser and painter into MermaidDiagram widget

### Tests
- 13 comprehensive Gantt chart tests covering parser, data model, and integration

## [0.4.1] - 2025-11-26

### Fixed
- 📝 Fixed package description length to meet pub.dev requirements (60-180 characters)

## [0.4.0] - 2025-11-25

### Added
- 🔌 **Plugin System** - Extensible parser plugins for custom markdown syntax
  - `ParserPluginRegistry` for managing and registering plugins
  - `BlockParserPlugin` and `InlineParserPlugin` base classes
  - Built-in plugins: `MentionPlugin`, `HashtagPlugin`, `EmojiPlugin`, `AdmonitionPlugin`
  - Full documentation in `doc/插件系统.md`

- 🤖 **AI Chat Plugins** - Specialized plugins for AI response parsing
  - `ThinkingPlugin` - Parse `<thinking>` blocks for AI reasoning process
  - `ArtifactPlugin` - Parse `<artifact>` blocks for code/document artifacts
  - `ToolCallPlugin` - Parse `<tool_use>` blocks for AI tool invocations
  - Custom widget builders: `ThinkingBuilder`, `ArtifactBuilder`, `ToolCallBuilder`

- 🎯 **AI Chat Demo** - Production-ready AI chat interface
  - Qwen3 Max model integration with thinking mode (`enable_thinking`)
  - Real-time streaming response with SSE support
  - Model selection dropdown (Qwen3 Max, Qwen Max, Qwen Plus, Qwen Turbo)
  - Thinking mode toggle for Qwen3 models
  - Quick prompt buttons for testing AI plugins
  - Dark/light theme support

- 🔐 **Environment Variables** - Secure API key management
  - `.env` file support via `flutter_dotenv`
  - API keys excluded from version control

### Changed
- Enhanced `SmoothMarkdown` and `StreamMarkdown` widgets to accept `plugins` parameter
- Updated example app with AI Chat Demo entry

### Documentation
- Added plugin system documentation (`doc/插件系统.md`)
- Updated README with plugin system and AI chat features
- Added code examples for custom plugin creation

## [0.3.2] - 2025-11-20

### Added
- ✅ **Details & Summary Support** - Collapsible content sections with interactive expand/collapse
  - Support for HTML `<details>` and `<summary>` tags
  - Automatic parsing of nested markdown content
  - Click-to-expand/collapse functionality with animated arrow icons
  - Default open state via `open` attribute
  - Seamless integration with both standard and enhanced component modes

### Implementation
- Added `DetailsNode` to AST for representing collapsible sections
- Implemented `DetailsBuilder` widget with stateful expand/collapse behavior
- Parser logic for `<details>` and `<summary>` HTML tags
- Registered builder in both default and enhanced component registries
- Comprehensive test coverage (11 parser tests + 7 renderer tests)

### Examples
```markdown
<details>
<summary>Click to expand</summary>
Hidden content that shows on click
</details>

<details open>
<summary>Expanded by default</summary>
This section starts expanded
</details>
```

## [0.3.1] - 2025-11-18

### Fixed
- 🐛 **Table rendering crash** - Fixed "irregular row lengths" error
  - Tables with inconsistent column counts now render correctly
  - Automatically fills missing cells with empty content
  - Calculates correct column count from headers, alignments, and data rows
  - Handles edge cases (empty tables, varying row lengths)

### Technical Details
- Improved table column count calculation logic in `TableBuilder`
- Replaced problematic `double.infinity.toInt()` with safe max calculation
- Added defensive checks to ensure at least 1 column in all tables

## [0.3.0] - 2025-11-18

### 🚀 Major Performance Improvements
- **32x Faster Rendering** - LRU parse cache dramatically improves performance
- **Smooth Scrolling** - 60 FPS in chat/list scenarios with 50+ messages
- **Memory Efficient** - Smart caching with automatic eviction

### Added
- ✅ **MarkdownParseCache** - LRU cache for parsed AST nodes
  - Cache hit: ~0.1ms vs ~3.6ms parsing (32x faster)
  - Configurable size (default: 100 entries)
  - Automatic LRU eviction
  - Cache statistics API
- ✅ **SmoothMarkdown enhancements**:
  - `enableCache` parameter (default: true) - Enable/disable parse caching
  - `useRepaintBoundary` parameter (default: true) - Isolate widget repaints
  - `SmoothMarkdown.clearCache()` - Clear global cache
  - `SmoothMarkdown.cacheStatistics` - Get cache usage stats
- ✅ **StreamMarkdown optimizations**:
  - Throttling mechanism (50ms) - Batch rapid stream updates
  - Automatic RepaintBoundary - Reduce overdraw
  - Smart cache management - Disable cache for streaming content
- ✅ **Performance Testing**:
  - Comprehensive cache performance tests (8 test cases)
  - Benchmark results included in documentation
  - Chat scenario simulation tests
- ✅ **Chat List Demo** - Production-ready chat interface example
  - ChatGPT-like UI with message bubbles
  - Real-time AI streaming responses
  - Dark/light theme support
  - Performance optimizations showcase
  - Cache statistics viewer

### Documentation
- 📚 Complete performance optimization guide (`doc/AI聊天列表性能优化.md`)
- 📊 Performance benchmarks and comparisons
- 💡 Best practices for list/chat scenarios
- 🎯 Optimization implementation summary (`doc/性能优化总结.md`)

### Performance Impact
- **List Scrolling**: 45 FPS → 60 FPS (+33%)
- **Repeated Rendering**: 3.6ms → 0.11ms (32x faster)
- **Chat Scenario**: 99.5% cache hit rate
- **Memory Overhead**: ~50KB per cached entry

### Breaking Changes
None - All optimizations are opt-in or enabled by default without breaking existing code.

## [0.2.0] - 2025-11-18

### Major Improvements
- 📚 **Complete API Documentation** - Comprehensive dartdoc for all public APIs
- 🎯 **Developer Experience** - Significantly improved IDE code completion
- 📖 **Production Ready** - Professional-grade documentation quality

### Added
- Extensive documentation for SmoothMarkdown and StreamMarkdown widgets
- Complete MarkdownStyleSheet documentation with all factory methods
- Detailed MarkdownConfig documentation with security and performance notes
- Full MarkdownRenderer documentation including custom builder examples
- Multiple code examples and usage scenarios throughout the codebase
- Performance considerations and best practices in documentation
- Cross-references between related classes for better navigation

### Improved
- API documentation quality elevated to production standards
- Better IDE experience with detailed parameter descriptions
- Structured documentation with clear sections and examples
- Enhanced developer onboarding experience

## [0.1.9] - 2025-11-18

### Added
- Comprehensive dartdoc documentation for all public APIs
- Detailed documentation for core widgets (SmoothMarkdown, StreamMarkdown)
- Complete documentation for MarkdownStyleSheet with all factory methods
- Extensive documentation for MarkdownConfig with security and performance notes
- Full documentation for MarkdownRenderer including custom builder examples
- Multiple code examples and usage scenarios for each API
- Performance considerations and best practices throughout

### Improved
- API documentation quality significantly enhanced
- Better IDE code completion experience with detailed parameter descriptions
- Added "See also" cross-references between related classes
- Structured documentation with sections for features, usage, and examples

## [0.1.8] - 2025-11-18

### Removed
- Removed unused `markdown: ^7.0.0` dependency (package uses custom parser implementation)

### Changed
- Reduced package size by removing unnecessary dependencies

## [0.1.7] - 2025-11-18

### Changed
- Package maintenance release
- Ensure all documentation is synchronized

## [0.1.6] - 2024-11-18

### Changed
- Enhanced package description with more keywords for better discoverability
- Added topics/tags to pubspec.yaml (markdown, renderer, syntax-highlighting, latex, streaming, widget, ui)
- Added pub.dev badges to README
- Added use cases section to README
- Added keywords section for SEO optimization

## [0.1.5] - 2024-11-18

### Documentation
- Updated installation instructions to reference version 0.1.4
- Ensured README shows latest version for new users

## [0.1.4] - 2024-11-18

### Changed
- Adjusted README screenshot display size to 600px width for better readability

## [0.1.3] - 2024-11-18

### Added
- Demo screenshots showcasing package features:
  - Main interface (main.jpg)
  - Code blocks with syntax highlighting (code.jpg)
  - LaTeX math formula rendering (latx.jpg)
  - Streaming markdown rendering (streaming.gif)

### Documentation
- Updated README with actual demo screenshots
- Improved visual presentation of package capabilities

## [0.1.2] - 2024-11-18

### Documentation
- Replaced example.com placeholder image links with real, working URLs
- Added Demo section showcasing package features
- Created screenshots directory structure for future demo images
- Updated image examples with Flutter logo and SVG icon
- Added streaming support to features list in README

## [0.1.1] - 2024-11-18

### Documentation
- Updated README to reflect Phase 4 (Stream support) completion status
- Clarified that streaming functionality is fully implemented with StreamMarkdown widget
- Added streaming demo reference in roadmap

## [0.1.0] - 2024-11-18

### Added
- Initial release of Flutter Smooth Markdown
- AST-based markdown parser with full CommonMark support
- Widget builder system for extensible rendering
- Built-in themes: Default (Light/Dark), GitHub (Light/Dark), VS Code (Light/Dark)
- Enhanced UI components:
  - Code blocks with syntax highlighting and copy functionality
  - Blockquotes with gradient backgrounds and quote icons
  - Links with hover animations and external indicators
  - Headers with decorative accents
- Basic markdown syntax support:
  - Headers (H1-H6)
  - Text formatting (bold, italic, strikethrough, inline code)
  - Lists (ordered, unordered, task lists)
  - Code blocks with syntax highlighting
  - Links and images
  - Blockquotes
  - Horizontal rules
- Customizable style sheets with theme inheritance
- Example application demonstrating all features
- Comprehensive documentation in Chinese

### Technical
- Minimum SDK version: Dart >=3.0.0, Flutter >=3.0.0
- Dependencies:
  - markdown: ^7.0.0
  - flutter_highlight: ^0.7.0
  - cached_network_image: ^3.3.0
  - url_launcher: ^6.2.0
  - flutter_math_fork: ^0.7.2
  - flutter_svg: ^2.0.10+1
- 87+ unit tests with comprehensive coverage
- Flutter lints enabled for code quality

[Unreleased]: https://github.com/JackCaow/flutter-smooth-markdown/compare/v0.7.4...HEAD
[0.7.4]: https://github.com/JackCaow/flutter-smooth-markdown/compare/v0.7.3...v0.7.4
[0.7.3]: https://github.com/JackCaow/flutter-smooth-markdown/compare/v0.7.2...v0.7.3
[0.1.8]: https://github.com/JackCaow/flutter-smooth-markdown/compare/v0.1.7...v0.1.8
[0.1.7]: https://github.com/JackCaow/flutter-smooth-markdown/compare/v0.1.6...v0.1.7
[0.1.6]: https://github.com/JackCaow/flutter-smooth-markdown/compare/v0.1.5...v0.1.6
[0.1.5]: https://github.com/JackCaow/flutter-smooth-markdown/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/JackCaow/flutter-smooth-markdown/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/JackCaow/flutter-smooth-markdown/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/JackCaow/flutter-smooth-markdown/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/JackCaow/flutter-smooth-markdown/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/JackCaow/flutter-smooth-markdown/releases/tag/v0.1.0
