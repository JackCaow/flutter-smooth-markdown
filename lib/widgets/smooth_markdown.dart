import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../src/config/markdown_config.dart';
import '../src/config/style_sheet.dart';
import '../src/parser/ast/markdown_node.dart';
import '../src/parser/markdown_parser.dart';
import '../src/parser/parse_cache.dart';
import '../src/parser/parser_plugin.dart';
import '../src/renderer/builders/artifact_builder.dart';
import '../src/renderer/builders/block_math_builder.dart';
import '../src/renderer/builders/details_builder.dart';
import '../src/renderer/builders/enhanced_blockquote_builder.dart';
import '../src/renderer/builders/enhanced_code_block_builder.dart';
import '../src/renderer/builders/enhanced_header_builder.dart';
import '../src/renderer/builders/enhanced_link_builder.dart';
import '../src/renderer/builders/footnote_definition_builder.dart';
import '../src/renderer/builders/footnote_reference_builder.dart';
import '../src/renderer/builders/horizontal_rule_builder.dart';
import '../src/renderer/builders/image_builder.dart';
import '../src/renderer/builders/inline_code_builder.dart';
import '../src/renderer/builders/inline_math_builder.dart';
import '../src/renderer/builders/list_builder.dart';
import '../src/renderer/builders/paragraph_builder.dart';
import '../src/renderer/builders/table_builder.dart';
import '../src/renderer/builders/text_builder.dart';
import '../src/renderer/builders/text_style_builder.dart';
import '../src/renderer/builders/thinking_builder.dart';
import '../src/renderer/builders/tool_call_builder.dart';
import '../src/renderer/markdown_renderer.dart';
import '../src/renderer/widget_builder.dart';
import 'smooth_selection_region.dart';

/// A widget that renders Markdown content with high performance and customizable styling.
///
/// [SmoothMarkdown] is a stateless widget that parses and renders Markdown text using
/// an AST-based parser and a flexible widget builder system. It supports full CommonMark
/// syntax plus GitHub Flavored Markdown (GFM) extensions.
///
/// ## Basic Usage
///
/// ```dart
/// SmoothMarkdown(
///   data: '# Hello **World**\n\nThis is a *markdown* document.',
///   styleSheet: MarkdownStyleSheet.light(),
/// )
/// ```
///
/// ## Features
///
/// - **Full Markdown Support**: Headers, lists, code blocks, tables, links, images, and more
/// - **Customizable Styling**: Use built-in themes or create custom styles
/// - **Enhanced Components**: Optional beautiful UI components with animations and effects
/// - **Syntax Highlighting**: Code blocks with language-specific syntax highlighting
/// - **Image Support**: Network images with caching, plus SVG support
/// - **Math Formulas**: LaTeX rendering with `$...$` (inline) and `$$...$$` (block)
/// - **Extensible**: Custom widget builders for any markdown element
///
/// ## Using Themes
///
/// ```dart
/// // Built-in light theme
/// SmoothMarkdown(
///   data: markdownText,
///   styleSheet: MarkdownStyleSheet.light(),
/// )
///
/// // GitHub theme
/// SmoothMarkdown(
///   data: markdownText,
///   styleSheet: MarkdownStyleSheet.github(),
/// )
///
/// // VS Code dark theme
/// SmoothMarkdown(
///   data: markdownText,
///   styleSheet: MarkdownStyleSheet.vscode(brightness: Brightness.dark),
/// )
///
/// // Adapt to Flutter theme
/// SmoothMarkdown(
///   data: markdownText,
///   styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
/// )
/// ```
///
/// ## Enhanced Components
///
/// Enable enhanced UI components for a more polished appearance:
///
/// ```dart
/// SmoothMarkdown(
///   data: markdownText,
///   useEnhancedComponents: true,
///   styleSheet: MarkdownStyleSheet.light(),
/// )
/// ```
///
/// Enhanced components include:
/// - **Code blocks**: Copy button, language tags, hover effects, syntax highlighting
/// - **Blockquotes**: Quote icons, gradient backgrounds, shadows
/// - **Links**: Hover animations, external link indicators, smooth transitions
/// - **Headers**: Decorative accents, gradient borders, color markers for H1/H2
///
/// ## Handling Links
///
/// ```dart
/// SmoothMarkdown(
///   data: markdownText,
///   onTapLink: (url) {
///     // Handle link navigation
///     if (url.startsWith('http')) {
///       launchUrl(Uri.parse(url));
///     } else {
///       // Handle internal navigation
///       Navigator.pushNamed(context, url);
///     }
///   },
/// )
/// ```
///
/// ## Custom Image Builder
///
/// Provide a custom widget builder for images:
///
/// ```dart
/// SmoothMarkdown(
///   data: markdownText,
///   imageBuilder: (url, alt, title) {
///     return CachedNetworkImage(
///       imageUrl: url,
///       placeholder: (context, url) => CircularProgressIndicator(),
///       errorWidget: (context, url, error) => Icon(Icons.error),
///     );
///   },
/// )
/// ```
///
/// ## Custom Code Block Builder
///
/// Customize how code blocks are rendered:
///
/// ```dart
/// SmoothMarkdown(
///   data: markdownText,
///   codeBuilder: (code, language) {
///     return Container(
///       padding: EdgeInsets.all(12),
///       decoration: BoxDecoration(
///         color: Colors.grey[900],
///         borderRadius: BorderRadius.circular(8),
///       ),
///       child: Text(code, style: TextStyle(fontFamily: 'monospace')),
///     );
///   },
/// )
/// ```
///
/// ## Performance Considerations
///
/// - The widget uses an AST-based parser for efficient parsing
/// - Rendering is optimized to minimize widget rebuilds
/// - For real-time streaming content, use `StreamMarkdown` instead
/// - Large documents (10k+ lines) may benefit from lazy loading techniques
///
/// See also:
///
/// - `StreamMarkdown`, for real-time streaming markdown rendering
/// - [MarkdownStyleSheet], for customizing the visual appearance
/// - [MarkdownConfig], for configuring parsing behavior
/// - [MarkdownRenderer], for advanced custom rendering
class SmoothMarkdown extends StatelessWidget {
  /// Creates a widget that renders Markdown content.
  ///
  /// The [data] parameter is required and contains the Markdown text to render.
  ///
  /// All other parameters are optional and provide customization options:
  ///
  /// - [styleSheet]: Controls the visual styling of markdown elements. Defaults to
  ///   [MarkdownStyleSheet.fromTheme] if not provided.
  /// - [config]: Configuration options for markdown parsing behavior. Most features
  ///   are enabled by default.
  /// - [onTapLink]: Callback function invoked when a link is tapped. Receives the
  ///   URL as a string parameter.
  /// - [imageBuilder]: Custom widget builder for rendering images. If not provided,
  ///   uses the default image renderer with network caching.
  /// - [codeBuilder]: Custom widget builder for rendering code blocks. If not provided,
  ///   uses the default code block renderer with syntax highlighting.
  /// - [useEnhancedComponents]: When `true`, uses enhanced UI components with additional
  ///   visual effects and interactions. Defaults to `false`.
  ///
  /// Example:
  ///
  /// ```dart
  /// SmoothMarkdown(
  ///   data: '# Title\n\nThis is **bold** text.',
  ///   styleSheet: MarkdownStyleSheet.github(),
  ///   useEnhancedComponents: true,
  ///   onTapLink: (url) => launchUrl(Uri.parse(url)),
  /// )
  /// ```
  const SmoothMarkdown({
    required this.data,
    super.key,
    this.styleSheet,
    this.config,
    this.onTapLink,
    this.onTapImage,
    this.imageBuilder,
    this.codeBuilder,
    this.useEnhancedComponents = false,
    this.enableCache = true,
    this.useRepaintBoundary = true,
    this.selectable = false,
    this.contextMenuBuilder,
    this.selectionController,
    this.selectableRegionKey,
    this.plugins,
    this.builderRegistry,
  });

  /// The Markdown text to render.
  ///
  /// This string will be parsed and rendered according to CommonMark and GFM specifications.
  /// Supports all standard markdown syntax including headers, lists, code blocks, tables,
  /// links, images, and inline formatting (bold, italic, code, etc.).
  ///
  /// Example:
  ///
  /// ```dart
  /// data: '''
  /// # Hello World
  ///
  /// This is a paragraph with **bold** and *italic* text.
  ///
  /// - List item 1
  /// - List item 2
  /// '''
  /// ```
  final String data;

  /// The style sheet used to control the visual appearance of rendered markdown.
  ///
  /// If not provided, defaults to [MarkdownStyleSheet.fromTheme]. You can use one of the
  /// built-in factory constructors:
  ///
  /// - [MarkdownStyleSheet.light] - Clean light theme
  /// - [MarkdownStyleSheet.dark] - Dark theme for dark mode apps
  /// - [MarkdownStyleSheet.github] - GitHub-style light or dark theme
  /// - [MarkdownStyleSheet.vscode] - VS Code editor-style theme
  /// - [MarkdownStyleSheet.fromTheme] - Adapts to Flutter's theme
  ///
  /// You can also create custom styles using [MarkdownStyleSheet.copyWith]:
  ///
  /// ```dart
  /// styleSheet: MarkdownStyleSheet.light().copyWith(
  ///   h1Style: TextStyle(fontSize: 40, color: Colors.purple),
  ///   codeBlockDecoration: BoxDecoration(
  ///     color: Colors.grey[100],
  ///     borderRadius: BorderRadius.circular(8),
  ///   ),
  /// )
  /// ```
  final MarkdownStyleSheet? styleSheet;

  /// Configuration options for Markdown parsing behavior.
  ///
  /// Controls which markdown features are enabled and how they are parsed.
  /// If not provided, uses default configuration with most features enabled.
  ///
  /// Example:
  ///
  /// ```dart
  /// config: MarkdownConfig(
  ///   enableCodeHighlight: true,
  ///   enableTables: true,
  ///   enableTaskLists: true,
  ///   enableLatex: true,
  ///   syntaxHighlightTheme: 'monokai',
  /// )
  /// ```
  ///
  /// See [MarkdownConfig] for all available options.
  final MarkdownConfig? config;

  /// Callback function invoked when a user taps on a link.
  ///
  /// The callback receives the URL string as a parameter. Use this to handle
  /// navigation to external URLs or internal routes.
  ///
  /// Example:
  ///
  /// ```dart
  /// onTapLink: (url) {
  ///   if (url.startsWith('http')) {
  ///     // Open external URL
  ///     launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  ///   } else if (url.startsWith('#')) {
  ///     // Handle anchor link
  ///     scrollToSection(url.substring(1));
  ///   } else {
  ///     // Handle internal navigation
  ///     Navigator.pushNamed(context, url);
  ///   }
  /// }
  /// ```
  ///
  /// If not provided, links will be rendered but tapping them will have no effect.
  final void Function(String url)? onTapLink;

  /// Callback invoked when an image is tapped.
  ///
  /// Receives the image URL, alt text, and title attribute.
  /// Useful for implementing image preview, zoom, or download.
  ///
  /// ```dart
  /// SmoothMarkdown(
  ///   data: markdownText,
  ///   onTapImage: (url, alt, title) {
  ///     showImagePreview(context, url);
  ///   },
  /// )
  /// ```
  final void Function(String url, String? alt, String? title)? onTapImage;

  /// Custom widget builder for rendering images.
  ///
  /// This builder is called for each image in the markdown, receiving:
  /// - `url`: The image URL (can be network URL, asset path, or data URI)
  /// - `alt`: Alternative text for the image (null if not provided)
  /// - `title`: Image title attribute (null if not provided)
  ///
  /// If not provided, images are rendered using the default image builder which
  /// supports network images with caching (via `cached_network_image`) and SVG
  /// images (via `flutter_svg`).
  ///
  /// Example:
  ///
  /// ```dart
  /// imageBuilder: (url, alt, title) {
  ///   return GestureDetector(
  ///     onTap: () => showImageViewer(url),
  ///     child: CachedNetworkImage(
  ///       imageUrl: url,
  ///       placeholder: (context, url) => CircularProgressIndicator(),
  ///       errorWidget: (context, url, error) => Icon(Icons.broken_image),
  ///     ),
  ///   );
  /// }
  /// ```
  final Widget Function(String url, String? alt, String? title)? imageBuilder;

  /// Custom widget builder for rendering code blocks.
  ///
  /// This builder is called for each fenced code block in the markdown, receiving:
  /// - `code`: The code content as a string
  /// - `language`: The language identifier (e.g., 'dart', 'javascript'), or null if not specified
  ///
  /// If not provided, code blocks are rendered using the default builder which
  /// includes syntax highlighting via `flutter_highlight`.
  ///
  /// Example:
  ///
  /// ```dart
  /// codeBuilder: (code, language) {
  ///   return Container(
  ///     padding: EdgeInsets.all(16),
  ///     decoration: BoxDecoration(
  ///       color: Colors.black87,
  ///       borderRadius: BorderRadius.circular(8),
  ///     ),
  ///     child: SelectableText(
  ///       code,
  ///       style: TextStyle(
  ///         fontFamily: 'Courier New',
  ///         color: Colors.white,
  ///       ),
  ///     ),
  ///   );
  /// }
  /// ```
  final Widget Function(String code, String? language)? codeBuilder;

  /// Whether to use enhanced UI components with additional visual effects.
  ///
  /// When set to `true`, the widget uses enhanced builders that provide:
  ///
  /// **Enhanced Code Blocks** ([EnhancedCodeBlockBuilder]):
  /// - Copy-to-clipboard button (appears on hover or always visible on mobile)
  /// - Language tag display in top-right corner
  /// - Subtle shadow and border effects
  /// - Smooth hover animations
  ///
  /// **Enhanced Blockquotes** ([EnhancedBlockquoteBuilder]):
  /// - Quote icon (💭) at the start
  /// - Gradient background with theme-aware colors
  /// - Drop shadow for depth
  /// - Colored left border accent
  ///
  /// **Enhanced Links** ([EnhancedLinkBuilder]):
  /// - Smooth hover animations with scale effect
  /// - Animated underline on hover
  /// - External link indicator icon (🔗)
  /// - Color transitions
  ///
  /// **Enhanced Headers** ([EnhancedHeaderBuilder]):
  /// - Colored accent markers for H1 and H2
  /// - Gradient bottom border
  /// - Improved spacing and visual hierarchy
  ///
  /// Defaults to `false` for standard rendering.
  ///
  /// Example:
  ///
  /// ```dart
  /// // Standard rendering
  /// SmoothMarkdown(
  ///   data: markdownText,
  ///   useEnhancedComponents: false, // default
  /// )
  ///
  /// // Enhanced rendering with visual effects
  /// SmoothMarkdown(
  ///   data: markdownText,
  ///   useEnhancedComponents: true,
  /// )
  /// ```
  ///
  /// Note: Enhanced components may have slightly higher rendering cost due to
  /// additional decorations and animations. For maximum performance with large
  /// documents, keep this set to `false`.
  final bool useEnhancedComponents;

  /// Whether to enable parsing cache for improved performance.
  ///
  /// When enabled (default), parsed markdown AST is cached using an LRU cache.
  /// This significantly improves performance when:
  /// - The same markdown content is rendered multiple times
  /// - Widgets rebuild frequently (e.g., during list scrolling)
  /// - Multiple messages with identical content are displayed
  ///
  /// **Performance Impact**:
  /// - Cache hit: ~0.1ms (vs ~15ms for re-parsing)
  /// - Memory overhead: ~50KB per cached entry
  /// - Recommended for list views and chat applications
  ///
  /// Set to `false` if:
  /// - Content changes frequently (e.g., streaming updates)
  /// - Memory is extremely constrained
  /// - Each markdown text is unique and won't be reused
  ///
  /// Example:
  ///
  /// ```dart
  /// // Enable cache for static content in lists
  /// SmoothMarkdown(
  ///   data: message.content,
  ///   enableCache: true, // default
  /// )
  ///
  /// // Disable for frequently changing content
  /// SmoothMarkdown(
  ///   data: liveEditingContent,
  ///   enableCache: false,
  /// )
  /// ```
  ///
  /// See also: [useRepaintBoundary] for additional performance optimizations.
  final bool enableCache;

  /// Whether to wrap the rendered widget in a [RepaintBoundary].
  ///
  /// When enabled (default), the widget is wrapped in a [RepaintBoundary],
  /// which isolates it from parent widget repaints. This improves performance
  /// in list views and scrollable containers by preventing unnecessary redraws.
  ///
  /// **Performance Impact**:
  /// - Reduces overdraw in scrolling lists
  /// - Isolates expensive rendering operations
  /// - ~20-30% FPS improvement in list scenarios
  ///
  /// Set to `false` if:
  /// - The widget is very small and simple
  /// - You're experiencing layout issues
  /// - The widget is already inside a [RepaintBoundary]
  ///
  /// Example:
  ///
  /// ```dart
  /// // Enable for list items (default)
  /// ListView.builder(
  ///   itemBuilder: (context, index) {
  ///     return SmoothMarkdown(
  ///       data: messages[index],
  ///       useRepaintBoundary: true, // default
  ///     );
  ///   },
  /// )
  ///
  /// // Disable for simple standalone widgets
  /// SmoothMarkdown(
  ///   data: '**Bold text**',
  ///   useRepaintBoundary: false,
  /// )
  /// ```
  ///
  /// See also: [enableCache] for parsing performance optimization.
  final bool useRepaintBoundary;

  /// Whether the rendered text content is selectable.
  ///
  /// When `true`, wraps the output in a [SmoothSelectionRegion] (a thin
  /// [SelectableRegion] adapter that additionally exposes programmatic
  /// selection control) and renders text using `Text.rich()` instead of
  /// `RichText`, enabling cross-block text selection and copy across
  /// paragraphs, headers, code blocks, etc.
  ///
  /// ```dart
  /// SmoothMarkdown(
  ///   data: markdownText,
  ///   selectable: true,
  /// )
  /// ```
  ///
  /// Defaults to `false`.
  final bool selectable;

  /// Custom context menu builder for text selection.
  ///
  /// When [selectable] is `true`, this builder replaces the default
  /// [SelectionArea.contextMenuBuilder]. Receives the current [BuildContext]
  /// and the [SmoothSelectionRegionState], which provides `contextMenuAnchors`,
  /// `contextMenuButtonItems`, `dispatchEvent`, `registrar`, and other methods
  /// to control text selection.
  ///
  /// If `null` (default), the built-in adaptive toolbar with clipboard
  /// filter is used.
  ///
  /// Example:
  ///
  /// ```dart
  /// SmoothMarkdown(
  ///   data: markdownText,
  ///   selectable: true,
  ///   contextMenuBuilder: (context, state) {
  ///     return AdaptiveTextSelectionToolbar.buttonItems(
  ///       anchors: state.contextMenuAnchors,
  ///       buttonItems: [
  ///         ...state.contextMenuButtonItems,
  ///         ContextMenuButtonItem(
  ///           label: '自定义操作',
  ///           onPressed: () {
  ///             // Custom action
  ///           },
  ///         ),
  ///       ],
  ///     );
  ///   },
  /// )
  /// ```
  ///
  /// Defaults to `null`.
  final Widget Function(BuildContext context,
      SmoothSelectionRegionState selectableRegionState)? contextMenuBuilder;

  /// Controller for programmatic text selection.
  ///
  /// This is the preferred way to drive selection from application code because
  /// it avoids exposing widget state through a [GlobalKey]. It is only attached
  /// when [selectable] is `true`.
  ///
  /// ```dart
  /// final controller = SmoothSelectionController();
  ///
  /// SmoothMarkdown(
  ///   data: markdownText,
  ///   selectable: true,
  ///   selectionController: controller,
  /// )
  ///
  /// // Later, select the paragraph under a long-press point:
  /// controller.selectParagraphAt(details.globalPosition);
  /// ```
  ///
  /// Defaults to `null`.
  final SmoothSelectionController? selectionController;

  /// A key applied to the internal [SmoothSelectionRegion] widget.
  ///
  /// Prefer [selectionController] for new code. This key remains available for
  /// advanced integrations that need direct access to [SmoothSelectionRegionState].
  ///
  /// ```dart
  /// final regionKey = GlobalKey<SmoothSelectionRegionState>();
  ///
  /// SmoothMarkdown(
  ///   data: markdownText,
  ///   selectable: true,
  ///   selectableRegionKey: regionKey,
  /// )
  ///
  /// // Later, trigger full-text selection (shows handles + toolbar):
  /// regionKey.currentState?.selectAll(SelectionChangedCause.toolbar);
  ///
  /// // Or dispatch a raw SelectionEvent to the SelectionContainer:
  /// regionKey.currentState?.dispatchEvent(const SelectAllSelectionEvent());
  /// ```
  ///
  /// Only meaningful when [selectable] is `true`.
  /// Defaults to `null`.
  final GlobalKey<SmoothSelectionRegionState>? selectableRegionKey;

  /// Parser plugins for extending markdown syntax.
  ///
  /// Use this to add custom inline and block-level syntax extensions like
  /// @mentions, #hashtags, :emoji: shortcodes, or custom callout blocks.
  ///
  /// Example:
  ///
  /// ```dart
  /// final plugins = ParserPluginRegistry()
  ///   ..register(MentionPlugin())
  ///   ..register(HashtagPlugin())
  ///   ..register(EmojiPlugin());
  ///
  /// SmoothMarkdown(
  ///   data: 'Hello @user :wave:',
  ///   plugins: plugins,
  ///   builderRegistry: customBuilders, // Register builders for plugin nodes
  /// )
  /// ```
  ///
  /// Note: When using plugins, you also need to register custom builders
  /// via [builderRegistry] to render the plugin nodes.
  final ParserPluginRegistry? plugins;

  /// Custom widget builder registry for rendering plugin nodes.
  ///
  /// When using parser [plugins], you need to register custom builders here
  /// to define how the plugin nodes should be rendered.
  ///
  /// Example:
  ///
  /// ```dart
  /// final builders = BuilderRegistry()
  ///   ..register('mention', MentionBuilder())
  ///   ..register('hashtag', HashtagBuilder())
  ///   ..register('emoji', EmojiBuilder());
  ///
  /// SmoothMarkdown(
  ///   data: '@user #tag :smile:',
  ///   plugins: plugins,
  ///   builderRegistry: builders,
  /// )
  /// ```
  ///
  /// If provided, these builders will be merged with the default/enhanced builders.
  /// Plugin builders take precedence.
  final BuilderRegistry? builderRegistry;

  /// Global shared parse cache for all SmoothMarkdown instances
  static final _parseCache = MarkdownParseCache(maxSize: 100);

  @override
  Widget build(BuildContext context) {
    // Create parser (with plugins and HTML support if configured)
    final enableHtml = config?.enableHtml ?? false;
    final parser = MarkdownParser(plugins: plugins, enableHtml: enableHtml);

    // Parse markdown with optional caching
    // Note: When plugins are used, caching is based on data only.
    // If plugin configuration changes, you should disable caching.
    // The cache key carries the enableHtml flag (NUL-delimited prefix,
    // which cannot occur in real markdown) so results never leak
    // across differently configured widgets.
    final cacheKey = enableHtml ? '\u0000html\u0000$data' : data;
    final List<MarkdownNode> nodes;
    if (enableCache && plugins == null) {
      final cached = _parseCache.get(cacheKey);
      if (cached != null) {
        nodes = cached;
      } else {
        nodes = parser.parse(data);
        _parseCache.put(cacheKey, nodes);
      }
    } else {
      nodes = parser.parse(data);
    }

    // Create custom registry if enhanced components are enabled
    BuilderRegistry? customRegistry;
    if (useEnhancedComponents) {
      customRegistry = BuilderRegistry()
        // Standard builders
        ..register('text', const TextBuilder())
        ..register('paragraph', const ParagraphBuilder())
        ..register('list', const ListBuilder())
        ..register('horizontal_rule', const HorizontalRuleBuilder())
        ..register('inline_code', const InlineCodeBuilder())
        ..register('inline_math', const InlineMathBuilder())
        ..register('block_math', const BlockMathBuilder())
        ..register('footnote_reference', const FootnoteReferenceBuilder())
        ..register('footnote_definition', const FootnoteDefinitionBuilder())
        ..register('bold', const BoldBuilder())
        ..register('italic', const ItalicBuilder())
        ..register('strikethrough', const StrikethroughBuilder())
        ..register('image', const ImageBuilder())
        ..register('table', const TableBuilder())
        ..register('details', const DetailsBuilder())
        // Enhanced builders (override standard ones)
        ..register('code_block', const EnhancedCodeBlockBuilder())
        ..register('blockquote', const EnhancedBlockquoteBuilder())
        ..register('link', const EnhancedLinkBuilder())
        ..register('header', const EnhancedHeaderBuilder())
        // AI chat builders
        ..register('thinking', const ThinkingBuilder())
        ..register('artifact', const ArtifactBuilder())
        ..register('tool_call', const ToolCallBuilder());
    }

    // Render nodes
    final effectiveStyleSheet =
        styleSheet ?? MarkdownStyleSheet.fromTheme(Theme.of(context));
    final renderer = MarkdownRenderer(
      styleSheet: effectiveStyleSheet,
      builderRegistry: customRegistry,
    );

    // Register custom builders from plugins on top of the default/enhanced builders
    if (builderRegistry != null) {
      for (final entry in builderRegistry!.entries) {
        renderer.registerBuilder(entry.key, entry.value);
      }
    }

    final renderContext = MarkdownRenderContext(
      onTapLink: onTapLink,
      onTapImage: onTapImage,
      imageBuilder: imageBuilder,
      codeBuilder: codeBuilder,
      selectable: selectable,
    );

    final widget = renderer.render(nodes, context: renderContext);

    // Wrap in SmoothSelectionRegion if selectable.
    //
    // SmoothSelectionRegion composes the framework SelectableRegion while
    // exposing controller/state APIs for programmatic selection.
    final content = selectable
        ? _SelectionCopyFilter(
            child: SmoothSelectionRegion(
              key: selectableRegionKey,
              contextMenuBuilder:
                  contextMenuBuilder ?? _defaultContextMenuBuilder,
              controller: selectionController,
              child: widget,
            ),
          )
        : widget;

    // Wrap in RepaintBoundary if enabled
    if (useRepaintBoundary) {
      return RepaintBoundary(child: content);
    }
    return content;
  }

  /// Clears the global parse cache.
  ///
  /// Use this when you want to force re-parsing of all content,
  /// for example after a theme change or when memory needs to be freed.
  ///
  /// Example:
  ///
  /// ```dart
  /// // Clear cache when app theme changes
  /// void onThemeChanged() {
  ///   SmoothMarkdown.clearCache();
  /// }
  /// ```
  static void clearCache() {
    _parseCache.clear();
  }

  /// Returns cache statistics for monitoring and tuning.
  ///
  /// Returns a map containing:
  /// - `size`: Current number of cached entries
  /// - `maxSize`: Maximum cache capacity
  /// - `utilization`: Cache utilization (0.0 to 1.0)
  ///
  /// Example:
  ///
  /// ```dart
  /// final stats = SmoothMarkdown.cacheStatistics;
  /// print('Cache usage: ${stats['utilization'] * 100}%');
  /// ```
  static Map<String, dynamic> get cacheStatistics => _parseCache.statistics;

  /// Schedules a post-frame clipboard filter to remove overlay content.
  static void _scheduleClipboardFilter() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null) {
        final filtered = _removeOverlayLines(data!.text!);
        await Clipboard.setData(ClipboardData(text: filtered));
      }
    });
  }

  /// Strips lines that consist entirely of non-breaking spaces (\u00A0),
  /// which are generated by the selectable overlay on non-text widgets.
  static String _removeOverlayLines(String text) {
    return text
        .split('\n')
        .where((line) => !RegExp(r'^\u00A0+$').hasMatch(line))
        .join('\n');
  }

  /// Default context menu builder: adaptive toolbar with clipboard filter.
  ///
  /// Overrides the Copy button to strip non-breaking-space overlay lines
  /// from the clipboard after the default copy action runs.
  static Widget _defaultContextMenuBuilder(
    BuildContext context,
    SmoothSelectionRegionState selectableRegionState,
  ) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: selectableRegionState.contextMenuButtonItems.map((item) {
        if (item.type == ContextMenuButtonType.copy) {
          final originalOnPressed = item.onPressed;
          return ContextMenuButtonItem(
            label: item.label,
            type: ContextMenuButtonType.copy,
            onPressed: () {
              originalOnPressed?.call();
              _scheduleClipboardFilter();
            },
          );
        }
        return item;
      }).toList(),
    );
  }
}

/// Detects Cmd/Ctrl+C and filters overlay content from the clipboard
/// after the default copy action has run.
class _SelectionCopyFilter extends StatelessWidget {
  const _SelectionCopyFilter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyC &&
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed)) {
          SmoothMarkdown._scheduleClipboardFilter();
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
