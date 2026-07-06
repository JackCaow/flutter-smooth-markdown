# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Flutter Smooth Markdown** is a high-performance Flutter markdown renderer with syntax highlighting, LaTeX math, tables, footnotes, SVG images, and real-time streaming support. The package provides a custom AST-based parser and extensible widget builder system.

- **Version**: 0.2.0
- **Minimum SDK**: Dart >=3.0.0, Flutter >=3.0.0
- **Repository**: https://github.com/JackCaow/flutter-smooth-markdown

## Development Commands

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/parser/markdown_parser_test.dart

# Run tests with coverage
flutter test --coverage

# Run tests for a specific pattern
flutter test --name="header"
```

### Build and Analyze
```bash
# Analyze code quality
flutter analyze

# Get dependencies
flutter pub get

# Run example app (important for visual testing)
cd example && flutter run

# Check available devices
flutter devices
```

### Publishing
```bash
# Dry run publish (no actual upload)
flutter pub publish --dry-run

# Publish to pub.dev (requires authentication)
flutter pub publish
```

## Architecture

The codebase uses a **layered architecture** with clear separation of concerns:

### 1. Parser Layer (`lib/src/parser/`)
- **MarkdownParser**: Main parser that orchestrates block and inline parsing
- **BlockParser**: Handles block-level elements (headers, paragraphs, lists, code blocks, tables, blockquotes, horizontal rules)
- **InlineParser**: Handles inline elements (bold, italic, links, images, inline code, strikethrough, math formulas)
- **AST**: Abstract Syntax Tree nodes representing parsed markdown structure (`lib/src/parser/ast/markdown_node.dart`)

**Parsing Flow**:
```
Raw Markdown → BlockParser → Block AST Nodes → InlineParser processes text content → Final AST
```

### 2. Renderer Layer (`lib/src/renderer/`)
- **MarkdownRenderer**: Main renderer with builder registry system
- **WidgetBuilder**: Base interface for all element builders
- **BuilderRegistry**: Maps node types to builders
- **Builders** (`lib/src/renderer/builders/`): Individual builders for each markdown element type
  - Standard builders: text, header, paragraph, code_block, list, blockquote, link, image, table, etc.
  - Enhanced builders: enhanced_code_block, enhanced_blockquote, enhanced_link, enhanced_header (with rich UI features)
  - Math builders: inline_math, block_math (LaTeX rendering)
  - Footnote builders: footnote_reference, footnote_definition

**Rendering Flow**:
```
AST Nodes → MarkdownRenderer → BuilderRegistry lookup → Specific WidgetBuilder → Flutter Widget Tree
```

### 3. Widget Layer (`lib/widgets/`)
- **SmoothMarkdown**: Main widget for static markdown rendering
- **StreamMarkdown**: Widget for real-time streaming markdown (incremental rendering)

### 4. Configuration Layer (`lib/src/config/`)
- **MarkdownStyleSheet**: Theming system with presets (light, dark, GitHub, VS Code)
- **MarkdownConfig**: Feature toggles and parser configuration

## Key Design Patterns

### Builder Pattern with Registry
The renderer uses a builder registry system that allows customization:

```dart
final renderer = MarkdownRenderer(styleSheet: MarkdownStyleSheet.light());

// Register custom builders
renderer.builderRegistry
  ..register('code_block', const EnhancedCodeBlockBuilder())
  ..register('link', const CustomLinkBuilder());
```

### Immutable AST Nodes
All AST nodes are immutable with `copyWith()` methods for modifications. This ensures thread safety and enables efficient caching.

### Extensibility Points
1. **Custom Builders**: Implement `MarkdownWidgetBuilder` interface
2. **Custom Themes**: Extend `MarkdownStyleSheet` with `copyWith()`
3. **Parser Extensions**: Modify block/inline parser behavior

## Test Structure

Tests are organized by layer:
- `test/parser/`: Parser tests (ast_test.dart, block_parser_test.dart, inline_parser_test.dart, markdown_parser_test.dart)
- `test/renderer/`: Renderer tests (widget_builder_test.dart, smooth_markdown_test.dart, table_builder_test.dart)
- `test/integration/`: Integration tests (table_integration_test.dart)

**Running specific test suites**:
```bash
flutter test test/parser/          # All parser tests
flutter test test/renderer/        # All renderer tests
flutter test test/integration/     # Integration tests
```

## Code Quality Standards

The project uses strict linting with `flutter_lints` and additional rules:
- **Strict mode enabled**: `strict-casts`, `strict-inference`, `strict-raw-types`
- **130+ lint rules** enforced (see `analysis_options.yaml`)
- **All public APIs require documentation comments** using `///`
- **Type annotations required** for public APIs

**Before committing**:
```bash
flutter analyze    # Must pass with no issues
flutter test       # All tests must pass
```

## Key Dependencies

**Production**:
- `flutter_highlight` (^0.7.0): Syntax highlighting for code blocks
- `cached_network_image` (^3.3.0): Image caching and network loading
- `flutter_math_fork` (^0.7.2): LaTeX math formula rendering
- `flutter_svg` (^2.0.10+1): SVG image support

**Development**:
- `flutter_test`: Testing framework
- `flutter_lints` (^5.0.0): Code quality enforcement
- `mockito` (^5.4.0): Mocking for tests
- `build_runner` (^2.4.0): Code generation

## Documentation

Chinese documentation is located in `doc/`:
- `核心需求文档.md`: Core requirements and specifications
- `开发计划.md`: Development roadmap with phases
- `架构设计.md`: Detailed architecture documentation
- `主题系统.md`: Theme system guide
- `使用增强组件.md`: Enhanced UI components guide
- `UI优化方案.md`: UI optimization strategies
- `Phase2完成总结.md`: Phase 2 completion summary

## Example App

The `example/` directory contains a comprehensive demo app showcasing:
- All markdown features (headers, lists, code blocks, tables, math, footnotes)
- Theme switching (light/dark, GitHub, VS Code)
- Streaming markdown demo
- Multi-language support (6 languages: Chinese, English, Japanese, Spanish, French, Korean)

**To test changes visually**:
```bash
cd example
flutter run
```

## Important Implementation Notes

1. **Parser is custom, not using `markdown` package**: Although listed as a dependency in early versions, the package implements its own parser from scratch using the AST system.

2. **Enhanced vs Standard Builders**: Standard builders provide basic rendering. Enhanced builders add rich UI features like copy buttons, hover effects, gradients, and animations. Users can choose which to use.

3. **Streaming Support**: `StreamMarkdown` widget handles real-time markdown rendering by buffering incoming text and incrementally parsing/rendering as complete markdown elements are detected.

4. **Math Formula Rendering**: Uses `flutter_math_fork` for LaTeX rendering. Inline math uses `$...$` and block math uses `$$...$$` syntax.

5. **SVG Support**: Native SVG rendering via `flutter_svg` for image nodes with `.svg` extension.

6. **Table Rendering**: Full table support with headers, alignment (left, center, right), and proper styling.

## Common Tasks

### Adding a New Markdown Element (via Plugin System)

The recommended way to add custom markdown syntax is through the plugin system:

1. Define AST node extending `MarkdownNode`
2. Create plugin extending `BlockParserPlugin` or `InlineParserPlugin`
3. Register plugin with `ParserPluginRegistry`
4. Create builder in `lib/src/renderer/builders/`
5. Register builder in `MarkdownRenderer`
6. Add tests in `test/parser/`

**Example:**
```dart
// Create registry and register plugins
final registry = ParserPluginRegistry();
registry.register(const MentionPlugin());
registry.register(const HashtagPlugin());

// Create parser with plugins
final parser = MarkdownParser(plugins: registry);
```

See `doc/插件系统.md` for detailed documentation.

### Adding a New Markdown Element (Core Parser)

For built-in syntax extensions:

1. Define AST node in `lib/src/parser/ast/markdown_node.dart`
2. Add parsing logic in `BlockParser` or `InlineParser`
3. Create builder in `lib/src/renderer/builders/`
4. Register builder in `MarkdownRenderer` constructor
5. Add tests in `test/parser/` and `test/renderer/`
6. Update documentation

### Modifying Themes

Themes are defined in `lib/src/config/style_sheet.dart`. Use factory constructors:
- `MarkdownStyleSheet.light()`
- `MarkdownStyleSheet.dark()`
- `MarkdownStyleSheet.github(brightness: Brightness.light)`
- `MarkdownStyleSheet.vscode(brightness: Brightness.dark)`
- `MarkdownStyleSheet.fromTheme(Theme.of(context))`

### Performance Optimization

Key areas for optimization:
- Parser caching (AST results)
- Widget memoization with `RepaintBoundary`
- Lazy loading for long documents
- Image caching (already implemented with `cached_network_image`)

## Project Status

**Completed Features** (as of v0.3.2):
- ✅ Complete AST-based parser (block + inline)
- ✅ Widget builder system with registry
- ✅ All standard markdown syntax (CommonMark)
- ✅ Enhanced UI components
- ✅ Theme system with multiple presets
- ✅ Syntax highlighting
- ✅ LaTeX math rendering
- ✅ Table support
- ✅ Footnotes
- ✅ SVG images
- ✅ Streaming support
- ✅ Comprehensive API documentation
- ✅ Details/Summary collapsible blocks
- ✅ Plugin system for custom parsers (MentionPlugin, HashtagPlugin, EmojiPlugin, AdmonitionPlugin)

**Future Enhancements**:
- Performance optimization and benchmarking
- More theme presets
- Advanced table features
- Accessibility improvements
