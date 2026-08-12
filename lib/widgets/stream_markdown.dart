import 'dart:async';

import 'package:flutter/widgets.dart';

import '../src/config/markdown_config.dart';
import '../src/config/style_sheet.dart';
import '../src/parser/parser_plugin.dart';
import '../src/renderer/widget_builder.dart';
import 'smooth_markdown.dart';
import 'smooth_selection_region.dart';

/// A widget that renders Markdown content from a stream in real-time.
///
/// [StreamMarkdown] is designed specifically for streaming scenarios where markdown
/// content arrives incrementally, such as AI chat responses, live documentation updates,
/// or collaborative editing. It efficiently accumulates and renders text chunks as they
/// arrive from a stream.
///
/// ## Basic Usage
///
/// ```dart
/// StreamController<String> controller = StreamController<String>();
///
/// // Display the streaming widget
/// StreamMarkdown(
///   stream: controller.stream,
///   styleSheet: MarkdownStyleSheet.light(),
/// )
///
/// // Later, send chunks to the stream
/// controller.add('# Hello\n\n');
/// await Future.delayed(Duration(milliseconds: 100));
/// controller.add('This is **streaming** ');
/// await Future.delayed(Duration(milliseconds: 100));
/// controller.add('markdown!');
/// ```
///
/// ## Use Cases
///
/// **AI Chat Applications**: Perfect for displaying streaming LLM responses
/// ```dart
/// StreamMarkdown(
///   stream: openAI.streamCompletion(prompt),
///   styleSheet: MarkdownStyleSheet.github(),
///   useEnhancedComponents: true,
/// )
/// ```
///
/// **Live Collaboration**: Show real-time updates from multiple users
/// ```dart
/// StreamMarkdown(
///   stream: firestore
///     .collection('documents')
///     .doc(docId)
///     .snapshots()
///     .map((doc) => doc.data()['content'] as String),
///   styleSheet: MarkdownStyleSheet.light(),
/// )
/// ```
///
/// **Progressive Loading**: Display content as it loads from network
/// ```dart
/// StreamMarkdown(
///   stream: fetchLargeDocument(),
///   loadingWidget: Center(child: CircularProgressIndicator()),
/// )
/// ```
///
/// ## How It Works
///
/// 1. The widget listens to the provided stream
/// 2. Each chunk received is appended to an internal buffer
/// 3. The accumulated text is parsed and rendered on each update
/// 4. The UI updates smoothly as new content arrives
///
/// ## Performance Considerations
///
/// - The widget re-parses and re-renders the entire accumulated content on each chunk
/// - For very large documents with frequent updates, consider batching chunks
/// - The parsing is fast (AST-based), but very large documents may cause frame drops
/// - Consider using [SmoothMarkdown] for static content instead
///
/// ## Error Handling
///
/// Currently, stream errors are silently ignored. The `errorBuilder` parameter is
/// available but not yet fully implemented. To handle errors:
///
/// ```dart
/// final stream = sourceStream.handleError((error) {
///   print('Stream error: $error');
///   // You can transform errors or rethrow
/// });
///
/// StreamMarkdown(stream: stream)
/// ```
///
/// See also:
///
/// - [SmoothMarkdown], for static markdown content
/// - [MarkdownStyleSheet], for customizing the visual appearance
/// - [MarkdownConfig], for configuring parsing behavior
class StreamMarkdown extends StatefulWidget {
  /// Creates a widget that renders streaming Markdown content.
  ///
  /// The [stream] parameter is required and should emit markdown text chunks.
  /// Each chunk is appended to the accumulated content and the entire content
  /// is re-rendered.
  ///
  /// All other parameters are optional and provide the same customization
  /// options as [SmoothMarkdown]:
  ///
  /// - [styleSheet]: Controls the visual styling of markdown elements. Defaults to
  ///   [MarkdownStyleSheet.light] if not provided.
  /// - [config]: Configuration options for markdown parsing behavior.
  /// - [onTapLink]: Callback function invoked when a link is tapped.
  /// - [imageBuilder]: Custom widget builder for rendering images.
  /// - [codeBuilder]: Custom widget builder for rendering code blocks.
  /// - [useEnhancedComponents]: When `true`, uses enhanced UI components.
  /// - [loadingWidget]: Widget to display while waiting for the first chunk.
  ///   Defaults to an empty container if not provided.
  /// - [errorBuilder]: Custom widget builder for displaying errors. Currently
  ///   not fully implemented - errors are silently ignored.
  ///
  /// Example:
  ///
  /// ```dart
  /// // AI chat response streaming
  /// StreamMarkdown(
  ///   stream: aiService.streamResponse(prompt),
  ///   styleSheet: MarkdownStyleSheet.github(),
  ///   useEnhancedComponents: true,
  ///   loadingWidget: Center(
  ///     child: Column(
  ///       mainAxisSize: MainAxisSize.min,
  ///       children: [
  ///         CircularProgressIndicator(),
  ///         SizedBox(height: 8),
  ///         Text('Waiting for response...'),
  ///       ],
  ///     ),
  ///   ),
  ///   onTapLink: (url) => launchUrl(Uri.parse(url)),
  /// )
  /// ```
  const StreamMarkdown({
    required this.stream,
    super.key,
    this.styleSheet,
    this.config,
    this.onTapLink,
    this.onTapImage,
    this.imageBuilder,
    this.codeBuilder,
    this.useEnhancedComponents = false,
    this.selectable = false,
    this.contextMenuBuilder,
    this.selectionController,
    this.selectableRegionKey,
    this.loadingWidget,
    this.errorBuilder,
    this.plugins,
    this.builderRegistry,
  });

  /// The stream of Markdown text chunks to render.
  ///
  /// Each string emitted by this stream is appended to the accumulated content.
  /// The widget will re-render the entire accumulated content on each emission.
  ///
  /// Example:
  ///
  /// ```dart
  /// // Creating a simple stream
  /// Stream<String> createMarkdownStream() async* {
  ///   yield '# Title\n\n';
  ///   await Future.delayed(Duration(milliseconds: 100));
  ///   yield 'First paragraph with **bold** text.\n\n';
  ///   await Future.delayed(Duration(milliseconds: 100));
  ///   yield '## Subtitle\n\n';
  ///   yield 'Second paragraph.';
  /// }
  ///
  /// StreamMarkdown(stream: createMarkdownStream())
  /// ```
  ///
  /// The stream can be a [StreamController], a network stream, or any other
  /// source that emits string chunks.
  final Stream<String> stream;

  /// The style sheet used to control the visual appearance of rendered markdown.
  ///
  /// See [SmoothMarkdown.styleSheet] for detailed documentation and examples.
  final MarkdownStyleSheet? styleSheet;

  /// Configuration options for Markdown parsing behavior.
  ///
  /// See [SmoothMarkdown.config] for detailed documentation and examples.
  final MarkdownConfig? config;

  /// Callback function invoked when a user taps on a link.
  ///
  /// See [SmoothMarkdown.onTapLink] for detailed documentation and examples.
  final void Function(String url)? onTapLink;

  /// Callback invoked when an image is tapped.
  ///
  /// See [SmoothMarkdown.onTapImage] for detailed documentation and examples.
  final void Function(String url, String? alt, String? title)? onTapImage;

  /// Custom widget builder for rendering images.
  ///
  /// See [SmoothMarkdown.imageBuilder] for detailed documentation and examples.
  final Widget Function(String url, String? alt, String? title)? imageBuilder;

  /// Custom widget builder for rendering code blocks.
  ///
  /// See [SmoothMarkdown.codeBuilder] for detailed documentation and examples.
  final Widget Function(String code, String? language)? codeBuilder;

  /// Whether to use enhanced UI components with additional visual effects.
  ///
  /// See [SmoothMarkdown.useEnhancedComponents] for detailed documentation.
  final bool useEnhancedComponents;

  /// Whether the rendered text content is selectable.
  ///
  /// See [SmoothMarkdown.selectable] for detailed documentation.
  final bool selectable;

  /// Custom context menu builder for text selection.
  ///
  /// See [SmoothMarkdown.contextMenuBuilder] for detailed documentation.
  final Widget Function(BuildContext context,
      SmoothSelectionRegionState selectableRegionState)? contextMenuBuilder;

  /// Controller for programmatic text selection.
  ///
  /// See [SmoothMarkdown.selectionController] for detailed documentation.
  final SmoothSelectionController? selectionController;

  /// A key applied to the internal [SmoothSelectionRegion] for programmatic
  /// selection control.
  ///
  /// See [SmoothMarkdown.selectableRegionKey] for detailed documentation.
  final GlobalKey<SmoothSelectionRegionState>? selectableRegionKey;

  /// Widget to display while waiting for the first chunk from the stream.
  ///
  /// This widget is shown when the stream hasn't emitted any data yet.
  /// Once the first chunk arrives, this widget is replaced with the
  /// rendered markdown content.
  ///
  /// If not provided, an empty invisible container is shown (SizedBox.shrink).
  ///
  /// Example:
  ///
  /// ```dart
  /// loadingWidget: Center(
  ///   child: Column(
  ///     mainAxisAlignment: MainAxisAlignment.center,
  ///     children: [
  ///       CircularProgressIndicator(),
  ///       SizedBox(height: 16),
  ///       Text('Loading content...'),
  ///     ],
  ///   ),
  /// )
  /// ```
  final Widget? loadingWidget;

  /// Custom widget builder for displaying stream errors.
  ///
  /// **Note**: This parameter is currently not fully implemented. Stream errors
  /// are caught but not displayed. To handle errors, use stream error handling:
  ///
  /// ```dart
  /// final errorHandledStream = originalStream.handleError((error) {
  ///   print('Error: $error');
  ///   // Return empty or error message
  /// });
  ///
  /// StreamMarkdown(stream: errorHandledStream)
  /// ```
  ///
  /// Future implementation may use this builder to display errors inline:
  ///
  /// ```dart
  /// errorBuilder: (error) => Container(
  ///   padding: EdgeInsets.all(16),
  ///   color: Colors.red[100],
  ///   child: Text('Error: $error'),
  /// )
  /// ```
  final Widget Function(Object error)? errorBuilder;

  /// Parser plugins for extending markdown syntax.
  ///
  /// See [SmoothMarkdown.plugins] for detailed documentation.
  final ParserPluginRegistry? plugins;

  /// Custom widget builder registry for rendering plugin nodes.
  ///
  /// See [SmoothMarkdown.builderRegistry] for detailed documentation.
  final BuilderRegistry? builderRegistry;

  @override
  State<StreamMarkdown> createState() => _StreamMarkdownState();
}

class _StreamMarkdownState extends State<StreamMarkdown> {
  final StringBuffer _buffer = StringBuffer();
  String _currentText = '';
  DateTime _lastUpdateTime = DateTime.now();
  bool _hasPendingUpdate = false;
  StreamSubscription<String>? _subscription;
  Timer? _throttleTimer;
  Object? _error;

  /// Throttle duration to batch rapid updates
  static const _throttleDuration = Duration(milliseconds: 50);

  @override
  void initState() {
    super.initState();
    _listenToStream();
  }

  void _listenToStream() {
    _subscription?.cancel();
    _throttleTimer?.cancel();
    _subscription = widget.stream.listen(
      (chunk) {
        if (!mounted) return;

        _buffer.write(chunk);
        _hasPendingUpdate = true;

        // Throttle updates to improve performance
        final now = DateTime.now();
        final timeSinceLastUpdate = now.difference(_lastUpdateTime);

        if (timeSinceLastUpdate >= _throttleDuration) {
          // Immediate update
          _performUpdate();
        } else {
          // Schedule delayed update
          _throttleTimer?.cancel();
          _throttleTimer = Timer(
            _throttleDuration - timeSinceLastUpdate,
            () {
              if (mounted && _hasPendingUpdate) {
                _performUpdate();
              }
            },
          );
        }
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _error = error;
        });
      },
      onDone: () {
        if (!mounted) return;
        _throttleTimer?.cancel();
        setState(() {
          // Flush any withheld trailing tag now that the stream is complete.
          _currentText = _buffer.toString();
          _hasPendingUpdate = false;
        });
      },
    );
  }

  void _performUpdate() {
    if (!mounted) return;
    setState(() {
      // Only withhold a partially-arrived HTML tag when HTML rendering is
      // explicitly enabled. The withholding renders up to the last complete
      // tag boundary so a tag split across chunks (e.g. `<font colo` |
      // `r="red">`) is not flashed as literal text; the withheld tail stays
      // buffered and renders once its `>` arrives, or when the stream
      // completes (see [onDone]).
      //
      // When HTML is disabled (the default), sequences like `<font colo`, a
      // trailing `<`, or `<` followed by letters are ordinary prose and must
      // be rendered verbatim — withholding them would swallow streaming text.
      final enableHtml = widget.config?.enableHtml ?? false;
      _currentText = enableHtml
          ? _safeRenderText(_buffer.toString())
          : _buffer.toString();
      _lastUpdateTime = DateTime.now();
      _hasPendingUpdate = false;
    });
  }

  /// Returns the longest prefix of [full] that does not end inside an
  /// unclosed HTML tag, so a partially-arrived tag is withheld from
  /// rendering until it is complete.
  ///
  /// This is only invoked when HTML rendering is enabled (see
  /// [_performUpdate]); with HTML disabled, the buffer is rendered verbatim
  /// so prose like `<font colo`, a trailing `<`, or `<` followed by letters
  /// is never swallowed.
  ///
  /// A literal `<` in prose (as in `a < b` or `<3`) is kept, because the
  /// character following such a `<` is not an ASCII letter or `/` and so
  /// cannot be the start of a tag.
  static String _safeRenderText(String full) {
    final lt = full.lastIndexOf('<');
    if (lt < 0) return full;
    // A '>' after the last '<' means the tag is already closed.
    if (full.lastIndexOf('>') > lt) return full;
    // Unclosed '<': withhold only when it starts a tag (a letter or '/').
    if (lt + 1 < full.length) {
      final next = full.codeUnitAt(lt + 1);
      final isTagStart = (next >= 0x41 && next <= 0x5A) || // A-Z
          (next >= 0x61 && next <= 0x7A) || // a-z
          next == 0x2F; // '/'
      if (!isTagStart) return full;
    }
    return full.substring(0, lt);
  }

  @override
  void didUpdateWidget(StreamMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _buffer.clear();
      _currentText = '';
      _error = null;
      _listenToStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && widget.errorBuilder != null) {
      return widget.errorBuilder!(_error!);
    }

    if (_currentText.isEmpty) {
      return widget.loadingWidget ??
          const Center(
            child: SizedBox.shrink(),
          );
    }

    // Use RepaintBoundary and disable cache for streaming content
    return RepaintBoundary(
      child: SmoothMarkdown(
        data: _currentText,
        styleSheet: widget.styleSheet,
        config: widget.config,
        onTapLink: widget.onTapLink,
        onTapImage: widget.onTapImage,
        imageBuilder: widget.imageBuilder,
        codeBuilder: widget.codeBuilder,
        useEnhancedComponents: widget.useEnhancedComponents,
        selectable: widget.selectable,
        contextMenuBuilder: widget.contextMenuBuilder,
        selectionController: widget.selectionController,
        selectableRegionKey: widget.selectableRegionKey,
        enableCache: false, // Disable cache for constantly changing content
        useRepaintBoundary: false, // Already wrapped in RepaintBoundary
        plugins: widget.plugins,
        builderRegistry: widget.builderRegistry,
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _throttleTimer?.cancel();
    _buffer.clear();
    super.dispose();
  }
}
