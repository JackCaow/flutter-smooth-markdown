// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../src/config/markdown_config.dart';
import '../src/config/style_sheet.dart';
import '../src/editor/document/markdown_document.dart';
import '../src/editor/document/markdown_document_codec.dart';
import '../src/editor/markdown_editor_controller.dart';
import '../src/editor/markdown_editor_export.dart';
import '../src/editor/wikilink.dart';
import '../src/parser/ast/markdown_node.dart';
import '../src/parser/parser_plugin.dart';
import '../src/parser/plugins/mermaid_plugin.dart';
import '../src/renderer/builders/block_math_builder.dart';
import '../src/renderer/builders/mermaid_builder.dart';
import '../src/renderer/widget_builder.dart';
import 'smooth_markdown.dart';

/// Display mode for [SmoothMarkdownEditor].
enum MarkdownEditorMode {
  /// Rendered Markdown blocks that become editable when focused.
  formatted,

  /// Raw Markdown source only.
  source,

  /// Rendered Markdown preview only.
  preview,

  /// Source editor and rendered preview side by side when space allows.
  split,
}

/// Image data returned by [SmoothMarkdownEditor.onPickImage].
class MarkdownEditorImageSelection {
  /// Creates image data for insertion.
  const MarkdownEditorImageSelection({
    required this.url,
    this.alt = '',
    this.title,
  });

  /// URL or asset path to write into the Markdown image.
  final String url;

  /// Optional alt text. When empty, the current selected text is used.
  final String alt;

  /// Optional Markdown image title.
  final String? title;
}

/// Called when a custom slash command is selected.
typedef MarkdownEditorSlashCommandCallback = FutureOr<String?> Function(
  String query,
);

/// Host-provided slash command that inserts Markdown when selected.
class MarkdownEditorSlashCommand {
  /// Creates a custom slash command.
  const MarkdownEditorSlashCommand({
    required this.title,
    required this.searchText,
    required this.icon,
    this.markdown,
    this.onSelected,
  }) : assert(markdown != null || onSelected != null);

  /// Label shown in the slash menu.
  final String title;

  /// Lower-priority aliases used for slash-menu filtering.
  final String searchText;

  /// Icon shown next to [title].
  final IconData icon;

  /// Markdown inserted when selected.
  final String? markdown;

  /// Dynamic Markdown producer used when [markdown] is not fixed.
  final MarkdownEditorSlashCommandCallback? onSelected;
}

/// Called when the editor requests a Scratch-style PDF/print export.
///
/// The callback receives the Markdown source and a simple HTML rendering so host
/// apps can route the request to a platform print/PDF implementation.
typedef MarkdownEditorPdfExportCallback = FutureOr<void> Function(
  String markdown,
  String html,
);

/// Called when the editor should import Markdown from a host-provided file.
typedef MarkdownEditorMarkdownImportCallback = FutureOr<String?> Function();

/// A Markdown source editor with formatted editing, live preview, and
/// Scratch-inspired commands.
///
/// The document source remains plain Markdown. Formatting buttons and keyboard
/// shortcuts edit that source, while [SmoothMarkdown] renders preview output.
class SmoothMarkdownEditor extends StatefulWidget {
  /// Creates a Markdown editor.
  const SmoothMarkdownEditor({
    super.key,
    this.controller,
    this.data = '',
    this.onChanged,
    this.initialMode = MarkdownEditorMode.formatted,
    this.onModeChanged,
    this.styleSheet,
    this.config,
    this.onTapLink,
    this.onTapImage,
    this.onPickImage,
    this.imageBuilder,
    this.codeBuilder,
    this.useEnhancedComponents = true,
    this.enableCache = true,
    this.plugins,
    this.builderRegistry,
    this.showToolbar = true,
    this.initialFocusMode = false,
    this.onFocusModeChanged,
    this.enableSlashCommands = true,
    this.customSlashCommands = const [],
    this.enableWikilinks = true,
    this.wikilinkSuggestions = const [],
    this.onTapWikilink,
    this.onExportMarkdown,
    this.onExportPdf,
    this.onImportMarkdown,
    this.height,
    this.minHeight = 360,
    this.autofocus = false,
    this.enabled = true,
    this.focusNode,
    this.textStyle,
    this.placeholder,
    this.decoration,
    this.sourceDecoration,
    this.previewDecoration,
  });

  /// Optional controller. If omitted, the editor owns an internal controller.
  final MarkdownEditorController? controller;

  /// Initial Markdown text used when [controller] is omitted.
  final String data;

  /// Called whenever the Markdown source changes.
  final ValueChanged<String>? onChanged;

  /// Initial editor display mode.
  final MarkdownEditorMode initialMode;

  /// Called when the display mode changes.
  final ValueChanged<MarkdownEditorMode>? onModeChanged;

  /// Style sheet forwarded to [SmoothMarkdown].
  final MarkdownStyleSheet? styleSheet;

  /// Parser config forwarded to [SmoothMarkdown].
  final MarkdownConfig? config;

  /// Called when an external link is activated with Scratch's Cmd/Ctrl+click
  /// editor gesture.
  final void Function(String url)? onTapLink;

  /// Image tap callback forwarded to [SmoothMarkdown].
  final void Function(String url, String? alt, String? title)? onTapImage;

  /// Called when the image command should pick/import an image.
  ///
  /// This lets host apps provide Scratch-style local file picking and asset
  /// copying. If omitted, the editor falls back to the built-in URL dialog.
  final FutureOr<MarkdownEditorImageSelection?> Function()? onPickImage;

  /// Image builder forwarded to [SmoothMarkdown].
  final Widget Function(String url, String? alt, String? title)? imageBuilder;

  /// Code block builder forwarded to [SmoothMarkdown].
  final Widget Function(String code, String? language)? codeBuilder;

  /// Whether preview should use enhanced markdown components.
  final bool useEnhancedComponents;

  /// Whether preview parsing may use the shared cache.
  final bool enableCache;

  /// Parser plugins forwarded to [SmoothMarkdown].
  final ParserPluginRegistry? plugins;

  /// Builder registry forwarded to [SmoothMarkdown].
  final BuilderRegistry? builderRegistry;

  /// Whether to show the formatting toolbar.
  final bool showToolbar;

  /// Whether the editor starts in distraction-free focus mode.
  final bool initialFocusMode;

  /// Called when focus mode changes.
  final ValueChanged<bool>? onFocusModeChanged;

  /// Whether `/` at the start of the current line opens command suggestions.
  final bool enableSlashCommands;

  /// Extra host-provided slash commands appended after built-in commands.
  final List<MarkdownEditorSlashCommand> customSlashCommands;

  /// Whether preview parses and renders `[[wikilinks]]`.
  final bool enableWikilinks;

  /// Candidate note titles for `[[` autocomplete.
  final List<String> wikilinkSuggestions;

  /// Called when a rendered wikilink is tapped.
  final void Function(String target)? onTapWikilink;

  /// Called when the export menu requests a Markdown file export.
  ///
  /// If omitted, the export action copies the Markdown source to the clipboard.
  final FutureOr<void> Function(String markdown)? onExportMarkdown;

  /// Called when the export menu or Cmd/Ctrl+Shift+P requests PDF/print export.
  ///
  /// If omitted, the action copies an HTML rendering to the clipboard as a
  /// platform-neutral fallback.
  final MarkdownEditorPdfExportCallback? onExportPdf;

  /// Called when the import menu requests host-provided Markdown content.
  ///
  /// Host apps can wire this to file picker, paste, or drop integrations and
  /// return the Markdown text that should be inserted at the active selection.
  final MarkdownEditorMarkdownImportCallback? onImportMarkdown;

  /// Fixed source/preview area height. Defaults to [minHeight].
  final double? height;

  /// Default content area height when [height] is omitted.
  final double minHeight;

  /// Whether the source editor should autofocus.
  final bool autofocus;

  /// Whether source editing and commands are enabled.
  final bool enabled;

  /// Optional focus node for the source editor.
  final FocusNode? focusNode;

  /// Source text style.
  final TextStyle? textStyle;

  /// Source editor placeholder.
  final String? placeholder;

  /// Decoration for the whole editor.
  final Decoration? decoration;

  /// Decoration for the source pane.
  final Decoration? sourceDecoration;

  /// Decoration for the preview pane.
  final Decoration? previewDecoration;

  @override
  State<SmoothMarkdownEditor> createState() => _SmoothMarkdownEditorState();
}

class _SmoothMarkdownEditorState extends State<SmoothMarkdownEditor> {
  static const _sourceKey = ValueKey('smooth_markdown_editor_source');
  static const _formattedScrollKey =
      ValueKey('smooth_markdown_editor_formatted_scroll');
  static const _codeCopyFeedbackDuration = Duration(milliseconds: 1500);
  static const _toolbarHeight = 48.0;
  static const _searchBarHeight = 64.0;

  late MarkdownEditorController _controller;
  late FocusNode _focusNode;
  late MarkdownEditorMode _mode;
  MarkdownEditorMode _lastNonSourceMode = MarkdownEditorMode.formatted;
  bool _ownsController = false;
  bool _ownsFocusNode = false;
  bool _searchOpen = false;
  late bool _focusMode;
  List<TextRange> _searchMatches = const [];
  var _currentSearchMatchIndex = 0;
  var _lastSearchQuery = '';
  _TriggerMatch? _slashMatch;
  _TriggerMatch? _wikilinkMatch;
  var _slashSelectedIndex = 0;
  var _wikilinkSelectedIndex = 0;
  TextRange? _activeFormattedRange;
  String? _activeFormattedBlockId;
  String? _activeFormattedContainerBlockId;
  var _activeFormattedBlockSourceOffset = 0;
  bool _activeFormattedPlainText = false;
  _TableCellSelection? _activeTableCell;
  bool _syncingFormattedBlock = false;
  bool _syncingTableCell = false;
  _StoredMarkTarget? _storedMarkTarget;
  Set<MarkdownEditorCommand> _storedMarks = const {};
  final Set<int> _mermaidSourceBlocks = <int>{};
  final MenuController _copyMenuController = MenuController();
  int? _copiedCodeBlockStart;
  Timer? _copiedCodeBlockResetTimer;
  final ScrollController _formattedScrollController = ScrollController();
  final ScrollController _sourceScrollController = ScrollController();
  final GlobalKey _formattedViewportKey = GlobalKey();
  final Map<String, GlobalKey> _formattedSegmentKeys = <String, GlobalKey>{};

  final TextEditingController _searchController = TextEditingController();
  final _FormattedBlockTextController _formattedBlockController =
      _FormattedBlockTextController();
  final _FormattedInlineTextController _tableCellController =
      _FormattedInlineTextController();
  final FocusNode _formattedBlockFocusNode = FocusNode();
  final FocusNode _tableCellFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _focusMode = widget.initialFocusMode;
    if (_mode != MarkdownEditorMode.source) {
      _lastNonSourceMode = _mode;
    }
    _attachController(widget.controller);
    _attachFocusNode(widget.focusNode);
    _formattedBlockFocusNode.onKeyEvent = _handleFormattedBlockKeyEvent;
    _tableCellFocusNode.onKeyEvent = _handleTableCellKeyEvent;
    _searchFocusNode.onKeyEvent = _handleSearchKeyEvent;
    _formattedBlockController.addListener(_handleFormattedBlockChanged);
    _tableCellController.addListener(_handleTableCellChanged);
    _searchController.addListener(_refreshSearchMatches);
    _refreshInlineSuggestions();
  }

  @override
  void didUpdateWidget(covariant SmoothMarkdownEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    final shouldRecreateOwnedControllerForPlugins =
        oldWidget.controller == null &&
            widget.controller == null &&
            oldWidget.plugins != widget.plugins;
    if (oldWidget.controller != widget.controller ||
        shouldRecreateOwnedControllerForPlugins) {
      final preservedText =
          shouldRecreateOwnedControllerForPlugins ? _controller.text : null;
      _detachController();
      _attachController(widget.controller, text: preservedText);
    } else if (widget.controller == null &&
        oldWidget.data != widget.data &&
        _controller.text != widget.data) {
      _controller.text = widget.data;
    }

    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNode();
      _attachFocusNode(widget.focusNode);
    }

    if (oldWidget.wikilinkSuggestions != widget.wikilinkSuggestions) {
      _refreshInlineSuggestions();
    }
  }

  @override
  void dispose() {
    _copiedCodeBlockResetTimer?.cancel();
    _detachController();
    _detachFocusNode();
    _formattedScrollController.dispose();
    _sourceScrollController.dispose();
    _formattedBlockController
      ..removeListener(_handleFormattedBlockChanged)
      ..dispose();
    _formattedBlockFocusNode.dispose();
    _tableCellController
      ..removeListener(_handleTableCellChanged)
      ..dispose();
    _tableCellFocusNode
      ..onKeyEvent = null
      ..dispose();
    _searchFocusNode
      ..onKeyEvent = null
      ..dispose();
    _searchController
      ..removeListener(_refreshSearchMatches)
      ..dispose();
    super.dispose();
  }

  void _attachController(MarkdownEditorController? controller, {String? text}) {
    _controller = controller ??
        MarkdownEditorController(
          text: text ?? widget.data,
          plugins: widget.plugins,
        );
    _ownsController = controller == null;
    _controller.addListener(_handleControllerChanged);
  }

  void _detachController() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
  }

  void _attachFocusNode(FocusNode? focusNode) {
    _focusNode = focusNode ?? FocusNode();
    _ownsFocusNode = focusNode == null;
  }

  void _detachFocusNode() {
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
  }

  bool _hasActiveComposing(TextEditingValue value) {
    final composing = value.composing;
    return composing.isValid &&
        !composing.isCollapsed &&
        composing.start >= 0 &&
        composing.end <= value.text.length;
  }

  void _handleControllerChanged() {
    _refreshInlineSuggestions();
    _refreshSearchMatches();
    widget.onChanged?.call(_controller.text);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.dividerColor.withOpacity(0.55);
    final editorDecoration = widget.decoration ??
        BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        );

    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: DecoratedBox(
        decoration: editorDecoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final suggestionMaxHeight =
                  _suggestionPanelMaxHeight(context, constraints);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showToolbar && !_focusMode) _buildToolbar(context),
                  if (_searchOpen) _buildSearchBar(context),
                  if (_shouldShowSlashCommands)
                    _buildSlashCommands(
                      context,
                      maxHeight: suggestionMaxHeight,
                    ),
                  if (_shouldShowWikilinkSuggestions)
                    _buildWikilinkSuggestions(
                      context,
                      maxHeight: suggestionMaxHeight,
                    ),
                  SizedBox(
                    height: widget.height ?? widget.minHeight,
                    child: _buildBody(context),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double _suggestionPanelMaxHeight(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final viewportHeight = MediaQuery.maybeOf(context)?.size.height ?? 700;
    final fallback = (viewportHeight * 0.4).clamp(160.0, 280.0).toDouble();
    if (!constraints.hasBoundedHeight) {
      return fallback;
    }

    var occupiedHeight = widget.height ?? widget.minHeight;
    if (widget.showToolbar && !_focusMode) {
      occupiedHeight += _toolbarHeight;
    }
    if (_searchOpen) {
      occupiedHeight += _searchBarHeight;
    }

    final availableHeight = constraints.maxHeight - occupiedHeight;
    return availableHeight.clamp(0.0, fallback).toDouble();
  }

  Widget _buildToolbar(BuildContext context) {
    final color = Theme.of(context).dividerColor.withOpacity(0.6);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: _toolbarHeight,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            _modeButton(
              MarkdownEditorMode.formatted,
              Icons.article_outlined,
              'Formatted',
            ),
            _modeButton(
              MarkdownEditorMode.source,
              Icons.edit_note,
              'Source',
            ),
            _modeButton(
              MarkdownEditorMode.preview,
              Icons.visibility_outlined,
              'Preview',
            ),
            _modeButton(
              MarkdownEditorMode.split,
              Icons.splitscreen,
              'Split',
            ),
            _separator(color),
            _historyButton(
              key: const ValueKey('smooth_markdown_editor_undo'),
              icon: Icons.undo,
              tooltip: 'Undo ($_shortcutModifierLabel+Z)',
              enabled: _controller.canUndo,
              onPressed: _undo,
            ),
            _historyButton(
              key: const ValueKey('smooth_markdown_editor_redo'),
              icon: Icons.redo,
              tooltip: 'Redo ($_redoShortcutLabel)',
              enabled: _controller.canRedo,
              onPressed: _redo,
            ),
            _separator(color),
            _commandButton(
                Icons.format_bold, 'Bold', MarkdownEditorCommand.bold),
            _commandButton(
              Icons.format_italic,
              'Italic',
              MarkdownEditorCommand.italic,
            ),
            _commandButton(
              Icons.strikethrough_s,
              'Strikethrough ($_shortcutModifierLabel+Shift+S)',
              MarkdownEditorCommand.strikethrough,
            ),
            _commandButton(
              Icons.code,
              'Inline code',
              MarkdownEditorCommand.inlineCode,
            ),
            _separator(color),
            _buildHeadingMenuButton(),
            _commandButton(
              Icons.format_list_bulleted,
              'Bulleted list',
              MarkdownEditorCommand.unorderedList,
            ),
            _commandButton(
              Icons.format_list_numbered,
              'Numbered list',
              MarkdownEditorCommand.orderedList,
            ),
            _commandButton(
              Icons.check_box_outlined,
              'Task list',
              MarkdownEditorCommand.taskList,
            ),
            _commandButton(
              Icons.format_quote,
              'Quote',
              MarkdownEditorCommand.blockquote,
            ),
            _separator(color),
            _commandButton(
              Icons.link,
              'Link',
              MarkdownEditorCommand.link,
            ),
            _commandButton(
              Icons.image_outlined,
              'Image',
              MarkdownEditorCommand.image,
            ),
            _commandButton(
              Icons.data_object,
              'Code Block',
              MarkdownEditorCommand.codeBlock,
            ),
            _commandButton(
              Icons.functions,
              'Block Math',
              MarkdownEditorCommand.blockMath,
            ),
            _commandButton(
              Icons.account_tree_outlined,
              'Mermaid Diagram',
              MarkdownEditorCommand.mermaidDiagram,
            ),
            _buildTablePickerButton(context),
            _commandButton(
              Icons.horizontal_rule,
              'Horizontal rule',
              MarkdownEditorCommand.horizontalRule,
            ),
            _separator(color),
            _buildCopyMenu(),
            Tooltip(
              message: 'Focus mode ($_shortcutModifierLabel+Shift+Enter)',
              child: IconButton(
                icon: const Icon(Icons.fullscreen),
                onPressed: _toggleFocusMode,
              ),
            ),
            Tooltip(
              message: 'Find in note ($_shortcutModifierLabel+F)',
              child: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _openSearch,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyMenu() {
    return MenuAnchor(
      controller: _copyMenuController,
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.copy),
          onPressed: () {
            _copyMarkdown();
          },
          child: const Text('Copy Markdown'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.notes_outlined),
          onPressed: () {
            _copyPlainText();
          },
          child: const Text('Copy Plain Text'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.code),
          onPressed: () {
            _copyHtml();
          },
          child: const Text('Copy HTML'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: () {
            _exportPdf();
          },
          child: const Text('Print as PDF'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.file_download_outlined),
          onPressed: () {
            _exportMarkdown();
          },
          child: const Text('Export Markdown'),
        ),
        if (widget.onImportMarkdown != null)
          MenuItemButton(
            leadingIcon: const Icon(Icons.upload_file_outlined),
            onPressed: widget.enabled
                ? () {
                    unawaited(_importMarkdown());
                  }
                : null,
            child: const Text('Import Markdown'),
          ),
      ],
      builder: (context, controller, child) {
        return Tooltip(
          message: 'Export ($_shortcutModifierLabel+Shift+C)',
          child: IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
          ),
        );
      },
    );
  }

  Widget _modeButton(
    MarkdownEditorMode mode,
    IconData icon,
    String tooltip,
  ) {
    final selected = _mode == mode;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Tooltip(
          message: tooltip,
          child: IconButton(
            icon: Icon(icon),
            color: selected ? theme.colorScheme.primary : null,
            onPressed: () => _setMode(mode),
          ),
        ),
      ),
    );
  }

  String get _shortcutModifierLabel {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 'Cmd',
      _ => 'Ctrl',
    };
  }

  String get _redoShortcutLabel {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS ||
      TargetPlatform.macOS =>
        '$_shortcutModifierLabel+Shift+Z',
      _ => '$_shortcutModifierLabel+Shift+Z / $_shortcutModifierLabel+Y',
    };
  }

  Widget _historyButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 6),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          key: key,
          icon: Icon(icon),
          onPressed: widget.enabled && enabled ? onPressed : null,
        ),
      ),
    );
  }

  Widget _commandButton(
    IconData icon,
    String tooltip,
    MarkdownEditorCommand command,
  ) {
    final active = _isToolbarCommandActive(command);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Tooltip(
          message: tooltip,
          child: IconButton(
            key: ValueKey(
              'smooth_markdown_editor_command_${command.name}',
            ),
            icon: Icon(icon),
            color: active ? theme.colorScheme.primary : null,
            onPressed: widget.enabled ? () => _applyCommand(command) : null,
          ),
        ),
      ),
    );
  }

  bool _isToolbarCommandActive(MarkdownEditorCommand command) {
    final storedMarkActive = _storedMarkToolbarActive(command);
    if (storedMarkActive != null) return storedMarkActive;

    return switch (command) {
      MarkdownEditorCommand.bold => _activeInlineSelectionContains(
          (node) => node is MarkdownStrong,
        ),
      MarkdownEditorCommand.italic => _activeInlineSelectionContains(
          (node) => node is MarkdownEmphasis,
        ),
      MarkdownEditorCommand.strikethrough => _activeInlineSelectionContains(
          (node) => node is MarkdownStrikethrough,
        ),
      MarkdownEditorCommand.inlineCode => _activeInlineSelectionContains(
          (node) => node is MarkdownInlineCode,
        ),
      MarkdownEditorCommand.link => _activeInlineSelectionContains(
          (node) => node is MarkdownLink,
        ),
      MarkdownEditorCommand.image => _activeInlineSelectionContains(
          (node) => node is MarkdownImage,
        ),
      MarkdownEditorCommand.unorderedList =>
        _activeListKind() == MarkdownListKind.bullet,
      MarkdownEditorCommand.orderedList =>
        _activeListKind() == MarkdownListKind.ordered,
      MarkdownEditorCommand.taskList =>
        _activeListKind() == MarkdownListKind.task,
      MarkdownEditorCommand.blockquote =>
        _activeTopLevelBlock() is MarkdownBlockquoteBlock,
      MarkdownEditorCommand.codeBlock =>
        _activeTopLevelBlock() is MarkdownCodeBlock,
      MarkdownEditorCommand.mermaidDiagram =>
        _activeTopLevelBlock() is MarkdownMermaidBlock,
      MarkdownEditorCommand.blockMath =>
        _activeTopLevelBlock() is MarkdownBlockMathBlock,
      MarkdownEditorCommand.table =>
        _activeTopLevelBlock() is MarkdownTableBlock,
      MarkdownEditorCommand.heading1 => _activeHeadingLevel() == 1,
      MarkdownEditorCommand.heading2 => _activeHeadingLevel() == 2,
      MarkdownEditorCommand.heading3 => _activeHeadingLevel() == 3,
      MarkdownEditorCommand.heading4 => _activeHeadingLevel() == 4,
      MarkdownEditorCommand.heading5 => _activeHeadingLevel() == 5,
      MarkdownEditorCommand.heading6 => _activeHeadingLevel() == 6,
      MarkdownEditorCommand.paragraph =>
        _activeEditableBlock() is MarkdownParagraphBlock,
      MarkdownEditorCommand.horizontalRule ||
      MarkdownEditorCommand.wikilink =>
        false,
    };
  }

  bool? _storedMarkToolbarActive(MarkdownEditorCommand command) {
    if (!_isStoredMarkCommand(command)) return null;
    if (!_storedMarkTargetMatchesCurrentSelection()) return null;
    return _storedMarks.contains(command);
  }

  Widget _buildHeadingMenuButton() {
    return PopupMenuButton<MarkdownEditorCommand>(
      tooltip: 'Headings',
      enabled: widget.enabled,
      icon: const Icon(Icons.title),
      onSelected: _applyCommand,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: MarkdownEditorCommand.heading1,
          child: _HeadingMenuItem(label: 'H1', title: 'Heading 1'),
        ),
        PopupMenuItem(
          value: MarkdownEditorCommand.heading2,
          child: _HeadingMenuItem(label: 'H2', title: 'Heading 2'),
        ),
        PopupMenuItem(
          value: MarkdownEditorCommand.heading3,
          child: _HeadingMenuItem(label: 'H3', title: 'Heading 3'),
        ),
        PopupMenuItem(
          value: MarkdownEditorCommand.heading4,
          child: _HeadingMenuItem(label: 'H4', title: 'Heading 4'),
        ),
        PopupMenuItem(
          value: MarkdownEditorCommand.heading5,
          child: _HeadingMenuItem(label: 'H5', title: 'Heading 5'),
        ),
        PopupMenuItem(
          value: MarkdownEditorCommand.heading6,
          child: _HeadingMenuItem(label: 'H6', title: 'Heading 6'),
        ),
      ],
    );
  }

  Widget _buildTablePickerButton(BuildContext context) {
    return PopupMenuButton<_TableDimensions>(
      key: const ValueKey('smooth_markdown_editor_table_picker_button'),
      tooltip: 'Table',
      enabled: widget.enabled,
      icon: const Icon(Icons.table_chart_outlined),
      onSelected: (dimensions) => _insertTable(
        rows: dimensions.rows,
        columns: dimensions.columns,
      ),
      itemBuilder: (context) => const [
        _TablePickerMenuEntry(),
      ],
    );
  }

  Widget _separator(Color color) {
    return Center(
      child: Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: color,
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Find in note...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _selectNextSearchMatch(),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _searchMatches.isEmpty
                  ? 'Not found'
                  : '${_currentSearchMatchIndex + 1}/${_searchMatches.length}',
            ),
            IconButton(
              tooltip: 'Previous match',
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed:
                  _searchMatches.isEmpty ? null : _selectPreviousSearchMatch,
            ),
            IconButton(
              tooltip: 'Next match',
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: _searchMatches.isEmpty ? null : _selectNextSearchMatch,
            ),
            IconButton(
              tooltip: 'Close find',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _searchOpen = false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlashCommands(
    BuildContext context, {
    required double maxHeight,
  }) {
    final commands = _visibleSlashCommands();
    return _SuggestionPanel(
      label: 'Slash command suggestions',
      maxHeight: maxHeight,
      children: [
        for (var index = 0; index < commands.length; index++)
          Semantics(
            key: ValueKey('smooth_markdown_editor_slash_command_$index'),
            selected: index == _slashSelectedIndex,
            button: true,
            label: commands[index].title,
            onTap: () => _runSlashCommand(commands[index]),
            child: ListTile(
              dense: true,
              selected: index == _slashSelectedIndex,
              leading: Icon(commands[index].icon),
              title: Text(commands[index].title),
              onTap: () => _runSlashCommand(commands[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildWikilinkSuggestions(
    BuildContext context, {
    required double maxHeight,
  }) {
    final suggestions = _visibleWikilinkSuggestions();
    return _SuggestionPanel(
      label: 'Wikilink suggestions',
      maxHeight: maxHeight,
      children: [
        if (suggestions.isEmpty)
          Semantics(
            key: const ValueKey(
              'smooth_markdown_editor_wikilink_empty_state',
            ),
            label: 'No matching notes',
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: ExcludeSemantics(
                child: Text(
                  'No matching notes',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          )
        else
          for (var index = 0; index < suggestions.length; index++)
            Semantics(
              key: ValueKey(
                'smooth_markdown_editor_wikilink_suggestion_$index',
              ),
              selected: index == _wikilinkSelectedIndex,
              button: true,
              label: suggestions[index],
              onTap: () => _insertWikilinkSuggestion(suggestions[index]),
              child: ListTile(
                dense: true,
                selected: index == _wikilinkSelectedIndex,
                leading: const Icon(Icons.notes_outlined),
                title: Text(suggestions[index]),
                onTap: () => _insertWikilinkSuggestion(suggestions[index]),
              ),
            ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_mode) {
      case MarkdownEditorMode.formatted:
        return _buildFormattedPane(context);
      case MarkdownEditorMode.source:
        return _buildSourcePane(context);
      case MarkdownEditorMode.preview:
        return _buildPreviewPane(context);
      case MarkdownEditorMode.split:
        return LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 720;
            if (narrow) {
              return Column(
                children: [
                  Expanded(child: _buildSourcePane(context)),
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                  Expanded(child: _buildPreviewPane(context)),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: _buildSourcePane(context)),
                VerticalDivider(
                    width: 1, color: Theme.of(context).dividerColor),
                Expanded(child: _buildPreviewPane(context)),
              ],
            );
          },
        );
    }
  }

  Widget _buildFormattedPane(BuildContext context) {
    final theme = Theme.of(context);
    final segments = _documentBlockSegments();

    return DecoratedBox(
      key: _formattedViewportKey,
      decoration: widget.previewDecoration ??
          BoxDecoration(color: theme.colorScheme.surface),
      child: SingleChildScrollView(
        key: _formattedScrollKey,
        controller: _formattedScrollController,
        padding: const EdgeInsets.all(16),
        child: segments.isEmpty
            ? _buildEmptyFormattedEditor(context)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < segments.length; i++) ...[
                    KeyedSubtree(
                      key: _formattedSegmentGlobalKey(segments[i]),
                      child: _buildFormattedSegment(context, segments[i]),
                    ),
                    if (i < segments.length - 1)
                      SizedBox(
                        height: widget.styleSheet?.blockSpacing ??
                            MarkdownStyleSheet.light().blockSpacing ??
                            16,
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyFormattedEditor(BuildContext context) {
    return TextField(
      key: _sourceKey,
      controller: _controller.textController,
      focusNode: _focusNode,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      minLines: 8,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      style: _sourceTextStyle(context),
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: widget.placeholder ?? 'Start writing...',
      ),
    );
  }

  Widget _buildFormattedSegment(
    BuildContext context,
    _MarkdownBlockSegment segment,
  ) {
    final block = segment.block;
    if (block is MarkdownFrontmatterBlock) {
      return _buildFormattedFrontmatterSegment(context, segment, block);
    }

    final active = block?.id != null
        ? _activeFormattedBlockId == block!.id
        : _activeFormattedRange?.start == segment.range.start &&
            _activeFormattedRange?.end == segment.range.end;

    if (active) {
      return _buildActiveFormattedTextField(context, segment);
    }

    final codeBlock = switch (block) {
      MarkdownCodeBlock() => _FencedCodeBlock(
          fence: block.fence,
          language: block.language,
          info: block.info,
          code: block.code,
        ),
      MarkdownMermaidBlock() => _FencedCodeBlock(
          fence: block.fence,
          language: 'mermaid',
          info: block.info ?? 'mermaid',
          code: block.code,
        ),
      _ => _parseFencedCodeSegment(segment.source),
    };
    if (codeBlock != null) {
      return _buildFormattedCodeBlockSegment(context, segment, codeBlock);
    }

    final blockMath = block is MarkdownBlockMathBlock
        ? block.latex
        : _parseBlockMathSegment(segment.source);
    if (blockMath != null) {
      return _buildFormattedBlockMathSegment(context, segment, blockMath);
    }

    if (block is MarkdownImageBlock) {
      return _buildFormattedImageSegment(context, segment, block);
    }

    if (block is MarkdownTableBlock) {
      return _buildFormattedTableSegment(context, segment, block);
    }

    if (block is MarkdownListBlock) {
      return _buildFormattedListSegment(context, segment, block);
    }

    if (block is MarkdownBlockquoteBlock) {
      return _buildFormattedBlockquoteSegment(context, segment, block);
    }

    return InkWell(
      key: ValueKey(
          'smooth_markdown_editor_formatted_block_${segment.range.start}'),
      borderRadius: BorderRadius.circular(6),
      onTap: widget.enabled ? () => _activateFormattedSegment(segment) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: _renderMarkdown(segment.source),
      ),
    );
  }

  Widget _buildActiveFormattedTextField(
    BuildContext context,
    _MarkdownBlockSegment segment,
  ) {
    return TextField(
      key: ValueKey(
        'smooth_markdown_editor_formatted_active_${segment.range.start}',
      ),
      controller: _formattedBlockController,
      focusNode: _formattedBlockFocusNode,
      enabled: widget.enabled,
      autofocus: true,
      minLines: 1,
      maxLines: null,
      style: _formattedEditingTextStyle(context, segment.block),
      keyboardType: TextInputType.multiline,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildFormattedListSegment(
    BuildContext context,
    _MarkdownBlockSegment segment,
    MarkdownListBlock list, {
    String? keyPrefix,
  }) {
    final effectiveKeyPrefix = keyPrefix ?? '${segment.range.start}';
    return Column(
      key: ValueKey('smooth_markdown_editor_list_block_$effectiveKeyPrefix'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < list.items.length; index++)
          _buildFormattedListItem(
            context,
            segment,
            list,
            index,
            keyPrefix: effectiveKeyPrefix,
          ),
      ],
    );
  }

  Widget _buildFormattedListItem(
    BuildContext context,
    _MarkdownBlockSegment segment,
    MarkdownListBlock list,
    int index, {
    required String keyPrefix,
  }) {
    final item = list.items[index];
    final editableBlock = _firstEditableListItemBlock(item);
    final primaryBlockId = editableBlock?.id ??
        (item.blocks.isEmpty ? null : item.blocks.first.id);
    final itemSegment = editableBlock == null
        ? null
        : _MarkdownBlockSegment(
            range: segment.range,
            source: editableBlock.toMarkdown(),
            block: editableBlock,
            containerBlockId: segment.containerBlockId ?? list.id,
            blockSourceOffset: segment.blockSourceOffset +
                _listItemPrimaryBlockSourceOffset(list, index),
          );
    final active =
        editableBlock != null && _activeFormattedBlockId == editableBlock.id;
    final theme = Theme.of(context);
    final primaryContent = active && itemSegment != null
        ? _buildActiveFormattedTextField(context, itemSegment)
        : editableBlock == null && item.blocks.isNotEmpty
            ? _buildFormattedListItemChildBlock(
                context,
                segment,
                list,
                itemIndex: index,
                childIndex: 0,
                keyPrefix: keyPrefix,
              )
            : InkWell(
                key: ValueKey(
                  'smooth_markdown_editor_list_item_${keyPrefix}_$index',
                ),
                borderRadius: BorderRadius.circular(6),
                onTap: widget.enabled && itemSegment != null
                    ? () => _activateFormattedSegment(itemSegment)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: itemSegment == null
                      ? _renderMarkdown(item.toMarkdown())
                      : DefaultTextStyle.merge(
                          style: theme.textTheme.bodyMedium,
                          child: _renderMarkdown(itemSegment.source),
                        ),
                ),
              );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: _buildListMarker(context, list, item, index),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                primaryContent,
                if (editableBlock != null)
                  for (var childIndex = 0;
                      childIndex < item.blocks.length;
                      childIndex++)
                    if (item.blocks[childIndex].id != primaryBlockId)
                      _buildFormattedListItemChildBlock(
                        context,
                        segment,
                        list,
                        itemIndex: index,
                        childIndex: childIndex,
                        keyPrefix: keyPrefix,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedListItemChildBlock(
    BuildContext context,
    _MarkdownBlockSegment segment,
    MarkdownListBlock list, {
    required int itemIndex,
    required int childIndex,
    required String keyPrefix,
  }) {
    final child = list.items[itemIndex].blocks[childIndex];
    final childSegment = _MarkdownBlockSegment(
      range: segment.range,
      source: child.toMarkdown(),
      block: child,
      containerBlockId: segment.containerBlockId ?? list.id,
      blockSourceOffset: segment.blockSourceOffset +
          _listItemChildBlockSourceOffset(list, itemIndex, childIndex),
    );

    if (child is MarkdownListBlock) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: _buildFormattedListSegment(
          context,
          childSegment,
          child,
          keyPrefix: '${keyPrefix}_${child.id}',
        ),
      );
    }

    if (!_usesPlainTextEditing(child)) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _buildFormattedSegment(context, childSegment),
      );
    }

    final active = _activeFormattedBlockId == child.id;
    if (active) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _buildActiveFormattedTextField(context, childSegment),
      );
    }

    return InkWell(
      key: ValueKey(
        'smooth_markdown_editor_list_child_${keyPrefix}_${itemIndex}_$childIndex',
      ),
      borderRadius: BorderRadius.circular(6),
      onTap:
          widget.enabled ? () => _activateFormattedSegment(childSegment) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _renderMarkdown(childSegment.source),
      ),
    );
  }

  Widget _buildListMarker(
    BuildContext context,
    MarkdownListBlock list,
    MarkdownListItem item,
    int index,
  ) {
    if (list.kind == MarkdownListKind.task) {
      return Checkbox(
        key: ValueKey('smooth_markdown_editor_task_checkbox_${list.id}_$index'),
        value: item.checked,
        onChanged: widget.enabled
            ? (checked) {
                _controller.documentEditor.updateListItemChecked(
                  item.id,
                  checked ?? false,
                );
              }
            : null,
        visualDensity: VisualDensity.compact,
      );
    }

    final marker = list.kind == MarkdownListKind.ordered
        ? '${list.startIndex + index}.'
        : '•';
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Text(
        marker,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  MarkdownBlock? _firstEditableListItemBlock(MarkdownListItem item) {
    for (final block in item.blocks) {
      if (_usesPlainTextEditing(block)) return block;
    }
    return null;
  }

  int _listItemPrimaryBlockSourceOffset(MarkdownListBlock list, int itemIndex) {
    var offset = 0;
    for (var index = 0; index < itemIndex; index++) {
      offset += _serializedListItemLines(list, index)
          .map((line) => line.length + 1)
          .fold<int>(0, (sum, length) => sum + length);
    }
    return offset + _listMarkerSource(list, itemIndex).length;
  }

  int _listItemChildBlockSourceOffset(
    MarkdownListBlock list,
    int itemIndex,
    int childIndex,
  ) {
    final item = list.items[itemIndex];
    var offset = _listItemPrimaryBlockSourceOffset(list, itemIndex);
    for (var index = 0; index < childIndex; index++) {
      final current = item.blocks[index];
      final next = item.blocks[index + 1];
      offset += current.toMarkdown().length;
      offset +=
          current is MarkdownListBlock || next is MarkdownListBlock ? 1 : 2;
      offset += 2;
    }
    return offset;
  }

  List<String> _serializedListItemLines(MarkdownListBlock list, int index) {
    final itemMarkdown = list.items[index].toMarkdown();
    final itemLines = itemMarkdown.isEmpty ? [''] : itemMarkdown.split('\n');
    return [
      '${_listMarkerSource(list, index)}${itemLines.first}',
      for (final line in itemLines.skip(1)) '  $line',
    ];
  }

  String _listMarkerSource(MarkdownListBlock list, int index) {
    return switch (list.kind) {
      MarkdownListKind.bullet => '- ',
      MarkdownListKind.ordered => '${list.startIndex + index}. ',
      MarkdownListKind.task => list.items[index].checked ? '- [x] ' : '- [ ] ',
    };
  }

  Widget _buildFormattedBlockquoteSegment(
    BuildContext context,
    _MarkdownBlockSegment segment,
    MarkdownBlockquoteBlock blockquote,
  ) {
    final theme = Theme.of(context);
    return DecoratedBox(
      key: ValueKey(
        'smooth_markdown_editor_blockquote_block_${segment.range.start}',
      ),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.45),
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < blockquote.blocks.length; index++) ...[
              _buildFormattedBlockquoteChild(
                context,
                segment,
                blockquote,
                index,
              ),
              if (index < blockquote.blocks.length - 1)
                SizedBox(
                  height: widget.styleSheet?.blockSpacing ??
                      MarkdownStyleSheet.light().blockSpacing ??
                      16,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedBlockquoteChild(
    BuildContext context,
    _MarkdownBlockSegment segment,
    MarkdownBlockquoteBlock blockquote,
    int index,
  ) {
    final child = blockquote.blocks[index];
    final childSegment = _MarkdownBlockSegment(
      range: segment.range,
      source: child.toMarkdown(),
      block: child,
      containerBlockId: blockquote.id,
      blockSourceOffset: _blockquoteChildSourceOffset(blockquote, index),
    );
    final active = _activeFormattedBlockId == child.id;

    if (!_usesPlainTextEditing(child)) {
      return _buildFormattedSegment(context, childSegment);
    }

    if (active) {
      return _buildActiveFormattedTextField(context, childSegment);
    }

    return InkWell(
      key: ValueKey(
        'smooth_markdown_editor_blockquote_child_${segment.range.start}_$index',
      ),
      borderRadius: BorderRadius.circular(6),
      onTap:
          widget.enabled ? () => _activateFormattedSegment(childSegment) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _renderMarkdown(childSegment.source),
      ),
    );
  }

  int _blockquoteChildSourceOffset(
    MarkdownBlockquoteBlock blockquote,
    int childIndex,
  ) {
    var offset = 0;
    for (var index = 0; index < childIndex; index++) {
      final quotedBlock = MarkdownBlockquoteBlock(
        id: '${blockquote.id}-offset-$index',
        blocks: [blockquote.blocks[index]],
      ).toMarkdown();
      offset += quotedBlock.length + 3;
    }
    return offset + 2;
  }

  Widget _buildFormattedTableSegment(
    BuildContext context,
    _MarkdownBlockSegment segment,
    MarkdownTableBlock table,
  ) {
    final theme = Theme.of(context);
    return DecoratedBox(
      key:
          ValueKey('smooth_markdown_editor_table_block_${segment.range.start}'),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor.withOpacity(0.55)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  IconButton(
                    key: ValueKey(
                      'smooth_markdown_editor_table_add_row_${segment.range.start}',
                    ),
                    tooltip: 'Add row below',
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: widget.enabled
                        ? () => _insertTableRowAfterActive(table)
                        : null,
                  ),
                  IconButton(
                    key: ValueKey(
                      'smooth_markdown_editor_table_add_row_above_${segment.range.start}',
                    ),
                    tooltip: 'Add row above',
                    icon: const Icon(Icons.vertical_align_top, size: 18),
                    onPressed: widget.enabled
                        ? () => _insertTableRowBeforeActive(table)
                        : null,
                  ),
                  IconButton(
                    key: ValueKey(
                      'smooth_markdown_editor_table_add_column_${segment.range.start}',
                    ),
                    tooltip: 'Add column after',
                    icon: const Icon(Icons.view_column_outlined, size: 18),
                    onPressed: widget.enabled
                        ? () => _insertTableColumnAfterActive(table)
                        : null,
                  ),
                  IconButton(
                    key: ValueKey(
                      'smooth_markdown_editor_table_add_column_before_${segment.range.start}',
                    ),
                    tooltip: 'Add column before',
                    icon: const Icon(Icons.keyboard_tab, size: 18),
                    onPressed: widget.enabled
                        ? () => _insertTableColumnBeforeActive(table)
                        : null,
                  ),
                  IconButton(
                    key: ValueKey(
                      'smooth_markdown_editor_table_delete_row_${segment.range.start}',
                    ),
                    tooltip: 'Delete row',
                    icon: const Icon(Icons.table_rows_outlined, size: 18),
                    onPressed: widget.enabled && _canDeleteActiveTableRow(table)
                        ? () => _deleteActiveTableRow(table)
                        : null,
                  ),
                  IconButton(
                    key: ValueKey(
                      'smooth_markdown_editor_table_delete_column_${segment.range.start}',
                    ),
                    tooltip: 'Delete column',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed:
                        widget.enabled && _canDeleteActiveTableColumn(table)
                            ? () => _deleteActiveTableColumn(table)
                            : null,
                  ),
                  IconButton(
                    key: ValueKey(
                      'smooth_markdown_editor_table_toggle_header_row_${segment.range.start}',
                    ),
                    tooltip:
                        table.headerRow ? 'Unset header row' : 'Set header row',
                    icon: Icon(
                      Icons.view_week_outlined,
                      size: 18,
                      color: table.headerRow ? theme.colorScheme.primary : null,
                    ),
                    onPressed: widget.enabled
                        ? () => _toggleTableHeaderRow(table)
                        : null,
                  ),
                  IconButton(
                    key: ValueKey(
                      'smooth_markdown_editor_table_toggle_header_column_${segment.range.start}',
                    ),
                    tooltip: table.headerColumn
                        ? 'Unset header column'
                        : 'Set header column',
                    icon: Icon(
                      Icons.view_column_outlined,
                      size: 18,
                      color:
                          table.headerColumn ? theme.colorScheme.primary : null,
                    ),
                    onPressed: widget.enabled
                        ? () => _toggleTableHeaderColumn(table)
                        : null,
                  ),
                  IconButton(
                    key: ValueKey(
                      'smooth_markdown_editor_table_delete_${segment.range.start}',
                    ),
                    tooltip: 'Delete table',
                    icon: const Icon(Icons.delete_forever_outlined, size: 18),
                    onPressed:
                        widget.enabled ? () => _deleteActiveTable(table) : null,
                  ),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.table_chart_outlined, size: 18),
                  ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Table(
              border: TableBorder.all(
                color: theme.dividerColor.withOpacity(0.55),
              ),
              defaultColumnWidth: const IntrinsicColumnWidth(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: table.headerRow
                        ? theme.colorScheme.surfaceVariant.withOpacity(0.25)
                        : null,
                  ),
                  children: [
                    for (var column = 0; column < table.columnCount; column++)
                      _buildFormattedTableCell(
                        context,
                        table,
                        rowIndex: 0,
                        columnIndex: column,
                        header: true,
                      ),
                  ],
                ),
                for (var row = 0; row < table.rows.length; row++)
                  TableRow(
                    children: [
                      for (var column = 0; column < table.columnCount; column++)
                        _buildFormattedTableCell(
                          context,
                          table,
                          rowIndex: row,
                          columnIndex: column,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedTableCell(
    BuildContext context,
    MarkdownTableBlock table, {
    required int rowIndex,
    required int columnIndex,
    bool header = false,
  }) {
    final theme = Theme.of(context);
    final children = _tableCellChildren(
      table,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      header: header,
    );
    final active = _activeTableCell?.matches(
          table.id,
          rowIndex: rowIndex,
          columnIndex: columnIndex,
          header: header,
        ) ??
        false;
    final keyPrefix = header ? 'header' : 'row_$rowIndex';
    final semanticHeader =
        (header && table.headerRow) || (table.headerColumn && columnIndex == 0);
    final textStyle = semanticHeader
        ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    final cellColor = semanticHeader && !(header && table.headerRow)
        ? theme.colorScheme.surfaceVariant.withOpacity(0.18)
        : null;
    final textAlign = _tableCellTextAlign(table, columnIndex);
    final contentAlignment = _tableCellContentAlignment(table, columnIndex);

    if (active) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: widget.enabled
            ? (details) => _showTableCellContextMenu(
                  context,
                  details,
                  table,
                  rowIndex: rowIndex,
                  columnIndex: columnIndex,
                  header: header,
                )
            : null,
        child: ColoredBox(
          color: cellColor ?? Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: TextField(
              key: ValueKey(
                'smooth_markdown_editor_table_cell_active_${table.id}_${keyPrefix}_$columnIndex',
              ),
              controller: _tableCellController,
              focusNode: _tableCellFocusNode,
              enabled: widget.enabled,
              autofocus: true,
              minLines: 1,
              maxLines: null,
              textAlign: textAlign,
              style: textStyle,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: widget.enabled
          ? (details) => _showTableCellContextMenu(
                context,
                details,
                table,
                rowIndex: rowIndex,
                columnIndex: columnIndex,
                header: header,
              )
          : null,
      child: InkWell(
        key: ValueKey(
          'smooth_markdown_editor_table_cell_${table.id}_${keyPrefix}_$columnIndex',
        ),
        onTap: widget.enabled
            ? () => _activateTableCell(
                  table.id,
                  rowIndex: rowIndex,
                  columnIndex: columnIndex,
                  header: header,
                  children: children,
                )
            : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 96),
          alignment: contentAlignment,
          color: cellColor,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: _renderFormattedInlineCell(
            context,
            children,
            textStyle,
            textAlign,
          ),
        ),
      ),
    );
  }

  Future<void> _showTableCellContextMenu(
    BuildContext context,
    TapDownDetails details,
    MarkdownTableBlock table, {
    required int rowIndex,
    required int columnIndex,
    required bool header,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );
    final action = await showMenu<_TableContextAction>(
      context: context,
      position: position,
      items: [
        if (columnIndex > 0)
          const PopupMenuItem(
            value: _TableContextAction.addColumnBefore,
            child: Text('Add Column Before'),
          ),
        const PopupMenuItem(
          value: _TableContextAction.addColumnAfter,
          child: Text('Add Column After'),
        ),
        PopupMenuItem(
          value: _TableContextAction.deleteColumn,
          enabled: table.columnCount > 1,
          child: const Text('Delete Column'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _TableContextAction.alignColumnDefault,
          child: Text('Default Alignment'),
        ),
        const PopupMenuItem(
          value: _TableContextAction.alignColumnLeft,
          child: Text('Align Left'),
        ),
        const PopupMenuItem(
          value: _TableContextAction.alignColumnCenter,
          child: Text('Align Center'),
        ),
        const PopupMenuItem(
          value: _TableContextAction.alignColumnRight,
          child: Text('Align Right'),
        ),
        const PopupMenuDivider(),
        if (!header)
          const PopupMenuItem(
            value: _TableContextAction.addRowAbove,
            child: Text('Add Row Above'),
          ),
        const PopupMenuItem(
          value: _TableContextAction.addRowBelow,
          child: Text('Add Row Below'),
        ),
        PopupMenuItem(
          value: _TableContextAction.deleteRow,
          enabled: !header || table.rows.isNotEmpty,
          child: const Text('Delete Row'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _TableContextAction.toggleHeaderRow,
          child: Text('Toggle Header Row'),
        ),
        const PopupMenuItem(
          value: _TableContextAction.toggleHeaderColumn,
          child: Text('Toggle Header Column'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _TableContextAction.deleteTable,
          child: Text('Delete Table'),
        ),
      ],
    );
    if (action == null) return;
    _runTableContextAction(
      table,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      header: header,
      action: action,
    );
  }

  void _runTableContextAction(
    MarkdownTableBlock table, {
    required int rowIndex,
    required int columnIndex,
    required bool header,
    required _TableContextAction action,
  }) {
    final editor = _controller.documentEditor;
    switch (action) {
      case _TableContextAction.addColumnBefore:
        editor.insertTableColumnBefore(table.id, columnIndex);
        break;
      case _TableContextAction.addColumnAfter:
        editor.insertTableColumnAfter(table.id, columnIndex);
        break;
      case _TableContextAction.deleteColumn:
        editor.deleteTableColumn(table.id, columnIndex);
        setState(() => _activeTableCell = null);
        break;
      case _TableContextAction.alignColumnDefault:
        editor.setTableColumnAlignment(
          blockId: table.id,
          columnIndex: columnIndex,
          alignment: null,
        );
        break;
      case _TableContextAction.alignColumnLeft:
        editor.setTableColumnAlignment(
          blockId: table.id,
          columnIndex: columnIndex,
          alignment: MarkdownTableAlignment.left,
        );
        break;
      case _TableContextAction.alignColumnCenter:
        editor.setTableColumnAlignment(
          blockId: table.id,
          columnIndex: columnIndex,
          alignment: MarkdownTableAlignment.center,
        );
        break;
      case _TableContextAction.alignColumnRight:
        editor.setTableColumnAlignment(
          blockId: table.id,
          columnIndex: columnIndex,
          alignment: MarkdownTableAlignment.right,
        );
        break;
      case _TableContextAction.addRowAbove:
        if (!header) {
          editor.insertTableRowBefore(table.id, rowIndex);
        }
        break;
      case _TableContextAction.addRowBelow:
        if (header) {
          editor.insertTableRowBefore(table.id, 0);
        } else {
          editor.insertTableRowAfter(table.id, rowIndex);
        }
        break;
      case _TableContextAction.deleteRow:
        if (header) {
          _deleteTableHeaderRow(table);
        } else {
          editor.deleteTableRow(table.id, rowIndex);
        }
        setState(() => _activeTableCell = null);
        break;
      case _TableContextAction.toggleHeaderRow:
        editor.toggleTableHeaderRow(table.id);
        break;
      case _TableContextAction.toggleHeaderColumn:
        editor.toggleTableHeaderColumn(table.id);
        break;
      case _TableContextAction.deleteTable:
        editor.deleteTable(table.id);
        setState(() => _activeTableCell = null);
        break;
    }
  }

  void _deleteTableHeaderRow(MarkdownTableBlock table) {
    _controller.documentEditor.updateTable(table.id, (current) {
      if (current.rows.isEmpty) return current;
      return current.copyWith(
        headers: current.rows.first,
        rows: current.rows.skip(1).toList(growable: false),
      );
    });
  }

  List<MarkdownInlineNode> _tableCellChildren(
    MarkdownTableBlock table, {
    required int rowIndex,
    required int columnIndex,
    required bool header,
  }) {
    if (columnIndex < 0 || columnIndex >= table.columnCount) {
      return const [MarkdownText('')];
    }
    if (header) {
      return columnIndex < table.headers.length
          ? table.headers[columnIndex]
          : const [MarkdownText('')];
    }
    if (rowIndex < 0 || rowIndex >= table.rows.length) {
      return const [MarkdownText('')];
    }
    final row = table.rows[rowIndex];
    return columnIndex < row.length
        ? row[columnIndex]
        : const [MarkdownText('')];
  }

  String _inlineMarkdown(List<MarkdownInlineNode> children) {
    return children.map((child) => child.toMarkdown()).join();
  }

  String _inlinePlainText(List<MarkdownInlineNode> children) {
    return children.map((child) => child.plainText).join();
  }

  MarkdownTableAlignment? _tableColumnAlignment(
    MarkdownTableBlock table,
    int columnIndex,
  ) {
    if (columnIndex < 0 || columnIndex >= table.alignments.length) return null;
    return table.alignments[columnIndex];
  }

  TextAlign _tableCellTextAlign(
    MarkdownTableBlock table,
    int columnIndex,
  ) {
    return switch (_tableColumnAlignment(table, columnIndex)) {
      MarkdownTableAlignment.left => TextAlign.left,
      MarkdownTableAlignment.center => TextAlign.center,
      MarkdownTableAlignment.right => TextAlign.right,
      null => TextAlign.left,
    };
  }

  AlignmentGeometry _tableCellContentAlignment(
    MarkdownTableBlock table,
    int columnIndex,
  ) {
    return switch (_tableColumnAlignment(table, columnIndex)) {
      MarkdownTableAlignment.left || null => AlignmentDirectional.centerStart,
      MarkdownTableAlignment.center => Alignment.center,
      MarkdownTableAlignment.right => AlignmentDirectional.centerEnd,
    };
  }

  Widget _renderFormattedInlineCell(
    BuildContext context,
    List<MarkdownInlineNode> children,
    TextStyle? style,
    TextAlign textAlign,
  ) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: baseStyle,
        children: _inlineCellSpans(context, children, baseStyle),
      ),
    );
  }

  List<InlineSpan> _inlineCellSpans(
    BuildContext context,
    List<MarkdownInlineNode> nodes,
    TextStyle style,
  ) {
    return [
      for (final node in nodes)
        ..._inlineCellSpansForNode(context, node, style),
    ];
  }

  List<InlineSpan> _inlineCellSpansForNode(
    BuildContext context,
    MarkdownInlineNode node,
    TextStyle style,
  ) {
    switch (node) {
      case MarkdownText():
        return [TextSpan(text: node.text, style: style)];
      case MarkdownStrong():
        return _inlineCellSpans(
          context,
          node.children,
          style.copyWith(fontWeight: FontWeight.w700),
        );
      case MarkdownEmphasis():
        return _inlineCellSpans(
          context,
          node.children,
          style.copyWith(fontStyle: FontStyle.italic),
        );
      case MarkdownStrikethrough():
        return _inlineCellSpans(
          context,
          node.children,
          style.copyWith(
            decoration: _mergeTextDecoration(
              style.decoration,
              TextDecoration.lineThrough,
            ),
          ),
        );
      case MarkdownInlineCode():
        return [
          TextSpan(
            text: node.code,
            style: style.copyWith(
              fontFamily: 'monospace',
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
            ),
          ),
        ];
      case MarkdownHardBreak():
        return [TextSpan(text: '\n', style: style)];
      case MarkdownInlineMath():
        return [
          TextSpan(
            text: node.latex,
            style: style.copyWith(
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ];
      case MarkdownLink():
        return _inlineCellSpans(
          context,
          node.children,
          style.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: _mergeTextDecoration(
              style.decoration,
              TextDecoration.underline,
            ),
          ),
        );
      case MarkdownImage():
        return [
          TextSpan(
            text: node.alt,
            style: style.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ];
      case MarkdownWikilink():
        return [
          TextSpan(
            text: node.label,
            style: style.copyWith(
              color: Theme.of(context).colorScheme.primary,
              decoration: _mergeTextDecoration(
                style.decoration,
                TextDecoration.underline,
              ),
            ),
          ),
        ];
      default:
        return [TextSpan(text: node.plainText, style: style)];
    }
  }

  TextDecoration _mergeTextDecoration(
    TextDecoration? current,
    TextDecoration added,
  ) {
    return TextDecoration.combine([
      if (current != null && current != TextDecoration.none) current,
      added,
    ]);
  }

  TextSelection _sourceSelectionForPlainTextSelection(
    MarkdownBlock block,
    String source,
    TextSelection selection, {
    required int sourceBaseOffset,
  }) {
    return _clampSourceSelection(
      TextSelection(
        baseOffset: sourceBaseOffset +
            _sourceOffsetForPlainTextOffset(
              block,
              source,
              selection.baseOffset,
            ),
        extentOffset: sourceBaseOffset +
            _sourceOffsetForPlainTextOffset(
              block,
              source,
              selection.extentOffset,
            ),
        affinity: selection.affinity,
        isDirectional: selection.isDirectional,
      ),
    );
  }

  TextSelection _plainTextSelectionForSourceSelection(
    MarkdownBlock block,
    String source,
    TextSelection selection, {
    required int textLength,
  }) {
    return TextSelection(
      baseOffset: _plainTextOffsetForSourceOffset(
        block,
        source,
        selection.baseOffset,
      ).clamp(0, textLength).toInt(),
      extentOffset: _plainTextOffsetForSourceOffset(
        block,
        source,
        selection.extentOffset,
      ).clamp(0, textLength).toInt(),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  int _sourceOffsetForPlainTextOffset(
    MarkdownBlock block,
    String source,
    int plainTextOffset,
  ) {
    final children = _inlineChildrenForBlock(block);
    final inlineStart = _plainTextSourceOffsetFor(block, source)
        .clamp(0, source.length)
        .toInt();
    final clampedPlain =
        plainTextOffset.clamp(0, block.plainText.length).toInt();
    if (children == null) {
      return (inlineStart + clampedPlain).clamp(0, source.length).toInt();
    }

    final inlineSourceLength = source.length - inlineStart;
    final inlineSourceOffset =
        _inlineSourceOffsetForPlainTextOffset(children, clampedPlain);
    return (inlineStart + inlineSourceOffset)
        .clamp(0, inlineStart + inlineSourceLength)
        .toInt();
  }

  int _plainTextOffsetForSourceOffset(
    MarkdownBlock block,
    String source,
    int sourceOffset,
  ) {
    final children = _inlineChildrenForBlock(block);
    final inlineStart = _plainTextSourceOffsetFor(block, source)
        .clamp(0, source.length)
        .toInt();
    final clampedSource = sourceOffset.clamp(0, source.length).toInt();
    final inlineSourceOffset =
        (clampedSource - inlineStart).clamp(0, source.length - inlineStart);
    if (children == null) return inlineSourceOffset.toInt();
    return _plainTextOffsetForInlineSourceOffset(
      children,
      inlineSourceOffset.toInt(),
    );
  }

  List<MarkdownInlineNode>? _inlineChildrenForBlock(MarkdownBlock block) {
    return switch (block) {
      MarkdownParagraphBlock() => block.children,
      MarkdownHeadingBlock() => block.children,
      _ => null,
    };
  }

  int _inlineSourceOffsetForPlainTextOffset(
    List<MarkdownInlineNode> children,
    int plainTextOffset,
  ) {
    final plainText = _inlinePlainText(children);
    final clampedPlain = plainTextOffset.clamp(0, plainText.length).toInt();
    var sourceCursor = 0;
    var plainCursor = 0;

    for (final child in children) {
      final childPlainLength = child.plainText.length;
      final childPlainEnd = plainCursor + childPlainLength;
      if (childPlainLength > 0 &&
          (clampedPlain == plainCursor || clampedPlain < childPlainEnd)) {
        return sourceCursor +
            _inlineNodeSourceOffsetForPlainTextOffset(
              child,
              clampedPlain - plainCursor,
            );
      }

      sourceCursor += child.toMarkdown().length;
      plainCursor = childPlainEnd;
    }

    return sourceCursor;
  }

  int _plainTextOffsetForInlineSourceOffset(
    List<MarkdownInlineNode> children,
    int sourceOffset,
  ) {
    final sourceLength = _inlineMarkdown(children).length;
    final clampedSource = sourceOffset.clamp(0, sourceLength).toInt();
    var sourceCursor = 0;
    var plainCursor = 0;

    for (final child in children) {
      final childSourceLength = child.toMarkdown().length;
      final childSourceEnd = sourceCursor + childSourceLength;
      if (clampedSource <= childSourceEnd) {
        return plainCursor +
            _inlineNodePlainTextOffsetForSourceOffset(
              child,
              clampedSource - sourceCursor,
            );
      }

      sourceCursor = childSourceEnd;
      plainCursor += child.plainText.length;
    }

    return plainCursor;
  }

  int _inlineNodeSourceOffsetForPlainTextOffset(
    MarkdownInlineNode node,
    int plainTextOffset,
  ) {
    final clampedPlain =
        plainTextOffset.clamp(0, node.plainText.length).toInt();
    switch (node) {
      case MarkdownText():
        return _escapedSourceOffsetForPlainTextOffset(
          node.toMarkdown(),
          clampedPlain,
        );
      case MarkdownStrong():
        return 2 +
            _inlineSourceOffsetForPlainTextOffset(
              node.children,
              clampedPlain,
            );
      case MarkdownEmphasis():
        return 1 +
            _inlineSourceOffsetForPlainTextOffset(
              node.children,
              clampedPlain,
            );
      case MarkdownStrikethrough():
        return 2 +
            _inlineSourceOffsetForPlainTextOffset(
              node.children,
              clampedPlain,
            );
      case MarkdownLink():
        return 1 +
            _inlineSourceOffsetForPlainTextOffset(
              node.children,
              clampedPlain,
            );
      case MarkdownInlineCode():
        return 1 + clampedPlain;
      case MarkdownInlineMath():
        return 1 + clampedPlain;
      case MarkdownImage():
        return 2 +
            _escapedSourceOffsetForPlainTextOffset(
              _escapeMarkdownInlineText(node.alt),
              clampedPlain,
            );
      case MarkdownWikilink():
        return 2 + clampedPlain;
      case MarkdownHardBreak():
        return clampedPlain == 0 ? 0 : node.toMarkdown().length;
      default:
        return clampedPlain.clamp(0, node.toMarkdown().length).toInt();
    }
  }

  int _inlineNodePlainTextOffsetForSourceOffset(
    MarkdownInlineNode node,
    int sourceOffset,
  ) {
    final sourceLength = node.toMarkdown().length;
    final clampedSource = sourceOffset.clamp(0, sourceLength).toInt();
    switch (node) {
      case MarkdownText():
        return _plainTextOffsetForEscapedSourceOffset(
          node.toMarkdown(),
          clampedSource,
        ).clamp(0, node.text.length).toInt();
      case MarkdownStrong():
        return _plainTextOffsetForDelimitedInlineSource(
          node.children,
          clampedSource,
          openingLength: 2,
          closingLength: 2,
        );
      case MarkdownEmphasis():
        return _plainTextOffsetForDelimitedInlineSource(
          node.children,
          clampedSource,
          openingLength: 1,
          closingLength: 1,
        );
      case MarkdownStrikethrough():
        return _plainTextOffsetForDelimitedInlineSource(
          node.children,
          clampedSource,
          openingLength: 2,
          closingLength: 2,
        );
      case MarkdownLink():
        final labelSourceLength = _inlineMarkdown(node.children).length;
        if (clampedSource <= 1) return 0;
        if (clampedSource >= 1 + labelSourceLength) {
          return node.plainText.length;
        }
        return _plainTextOffsetForInlineSourceOffset(
          node.children,
          clampedSource - 1,
        );
      case MarkdownInlineCode():
        return (clampedSource - 1).clamp(0, node.plainText.length).toInt();
      case MarkdownInlineMath():
        return (clampedSource - 1).clamp(0, node.plainText.length).toInt();
      case MarkdownImage():
        final altSource = _escapeMarkdownInlineText(node.alt);
        if (clampedSource <= 2) return 0;
        if (clampedSource >= 2 + altSource.length) {
          return node.plainText.length;
        }
        return _plainTextOffsetForEscapedSourceOffset(
          altSource,
          clampedSource - 2,
        ).clamp(0, node.plainText.length).toInt();
      case MarkdownWikilink():
        return (clampedSource - 2).clamp(0, node.plainText.length).toInt();
      case MarkdownHardBreak():
        return clampedSource >= sourceLength ? 1 : 0;
      default:
        return clampedSource.clamp(0, node.plainText.length).toInt();
    }
  }

  int _plainTextOffsetForDelimitedInlineSource(
    List<MarkdownInlineNode> children,
    int sourceOffset, {
    required int openingLength,
    required int closingLength,
  }) {
    final sourceLength =
        openingLength + _inlineMarkdown(children).length + closingLength;
    final clampedSource = sourceOffset.clamp(0, sourceLength).toInt();
    final childrenPlainTextLength = _inlinePlainText(children).length;
    if (clampedSource <= openingLength) return 0;
    if (clampedSource >= sourceLength - closingLength) {
      return childrenPlainTextLength;
    }
    return _plainTextOffsetForInlineSourceOffset(
      children,
      clampedSource - openingLength,
    );
  }

  int _escapedSourceOffsetForPlainTextOffset(
    String source,
    int plainTextOffset,
  ) {
    var sourceOffset = 0;
    var plainCursor = 0;
    while (sourceOffset < source.length && plainCursor < plainTextOffset) {
      if (source[sourceOffset] == '\\' && sourceOffset + 1 < source.length) {
        sourceOffset += 2;
      } else {
        sourceOffset++;
      }
      plainCursor++;
    }
    return sourceOffset.clamp(0, source.length).toInt();
  }

  int _plainTextOffsetForEscapedSourceOffset(
    String source,
    int sourceOffset,
  ) {
    final clampedSource = sourceOffset.clamp(0, source.length).toInt();
    var cursor = 0;
    var plainOffset = 0;
    while (cursor < clampedSource) {
      if (source[cursor] == '\\' && cursor + 1 < source.length) {
        if (cursor + 1 >= clampedSource) break;
        cursor += 2;
      } else {
        cursor++;
      }
      plainOffset++;
    }
    return plainOffset;
  }

  String _escapeMarkdownInlineText(String text) {
    return text
        .replaceAll('\\', r'\\')
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]')
        .replaceAll('`', r'\`')
        .replaceAll('*', r'\*');
  }

  MarkdownBlock? _activeEditableBlock() {
    final blockId = _activeFormattedBlockId;
    if (blockId == null) return null;
    return _controller.document.blockById(blockId);
  }

  MarkdownBlock? _activeTopLevelBlock() {
    final cell = _activeTableCell;
    if (cell != null) {
      return _controller.document.blockById(cell.tableId);
    }

    final activeBlock = _activeEditableBlock();
    if (activeBlock != null) {
      return _topLevelBlockContaining(activeBlock.id) ?? activeBlock;
    }

    final range = _activeFormattedRange;
    if (range == null) return null;
    for (final segment in _documentBlockSegments()) {
      if (segment.range == range) return segment.block;
    }
    return null;
  }

  MarkdownListKind? _activeListKind() {
    final block = _activeTopLevelBlock();
    return block is MarkdownListBlock ? block.kind : null;
  }

  int? _activeHeadingLevel() {
    final block = _activeEditableBlock();
    return block is MarkdownHeadingBlock ? block.level : null;
  }

  bool _activeInlineSelectionContains(
    bool Function(MarkdownInlineNode node) matches,
  ) {
    final active = _activeInlineSelectionData();
    if (active == null) return false;
    return _inlineSelectionContains(
      active.children,
      active.selection,
      matches,
    );
  }

  ({List<MarkdownInlineNode> children, TextSelection selection})?
      _activeInlineSelectionData() {
    if (_activeTableCell != null) {
      final children = _tableCellController.inlineNodes;
      if (children == null ||
          _inlinePlainText(children) != _tableCellController.text) {
        return null;
      }
      return (children: children, selection: _tableCellController.selection);
    }

    if (!_activeFormattedPlainText || _activeFormattedBlockId == null) {
      return null;
    }

    final block = _formattedBlockController.block ?? _activeEditableBlock();
    final children = switch (block) {
      MarkdownParagraphBlock() => block.children,
      MarkdownHeadingBlock() => block.children,
      _ => null,
    };
    if (children == null ||
        _inlinePlainText(children) != _formattedBlockController.text) {
      return null;
    }
    return (children: children, selection: _formattedBlockController.selection);
  }

  bool _inlineSelectionContains(
    List<MarkdownInlineNode> children,
    TextSelection selection,
    bool Function(MarkdownInlineNode node) matches,
  ) {
    if (!selection.isValid) return false;
    final length = _inlinePlainText(children).length;
    final start = selection.start.clamp(0, length).toInt();
    final end = selection.end.clamp(start, length).toInt();
    return _inlineSelectionContainsInRange(
      children,
      0,
      start,
      end,
      selection.isCollapsed,
      matches,
    );
  }

  bool _inlineSelectionContainsInRange(
    List<MarkdownInlineNode> children,
    int baseOffset,
    int selectionStart,
    int selectionEnd,
    bool collapsed,
    bool Function(MarkdownInlineNode node) matches,
  ) {
    var cursor = baseOffset;
    for (final node in children) {
      final nodeStart = cursor;
      final nodeEnd = nodeStart + node.plainText.length;
      cursor = nodeEnd;

      final overlaps = collapsed
          ? selectionStart > nodeStart && selectionStart <= nodeEnd
          : selectionStart < nodeEnd && selectionEnd > nodeStart;
      if (!overlaps) continue;

      if (matches(node)) return true;

      final nested = _inlineNodeChildren(node);
      if (nested != null &&
          _inlineSelectionContainsInRange(
            nested,
            nodeStart,
            selectionStart,
            selectionEnd,
            collapsed,
            matches,
          )) {
        return true;
      }
    }
    return false;
  }

  List<MarkdownInlineNode>? _inlineNodeChildren(MarkdownInlineNode node) {
    return switch (node) {
      MarkdownStrong() => node.children,
      MarkdownEmphasis() => node.children,
      MarkdownStrikethrough() => node.children,
      MarkdownLink() => node.children,
      _ => null,
    };
  }

  bool _isStoredMarkCommand(MarkdownEditorCommand command) {
    return command == MarkdownEditorCommand.bold ||
        command == MarkdownEditorCommand.italic ||
        command == MarkdownEditorCommand.strikethrough ||
        command == MarkdownEditorCommand.inlineCode;
  }

  _StoredMarkTarget? _currentStoredMarkTarget() {
    final cell = _activeTableCell;
    if (cell != null) {
      return _StoredMarkTarget.tableCell(
        tableId: cell.tableId,
        rowIndex: cell.rowIndex,
        columnIndex: cell.columnIndex,
        header: cell.header,
      );
    }

    final blockId = _activeFormattedBlockId;
    if (_activeFormattedPlainText && blockId != null) {
      return _StoredMarkTarget.formattedBlock(blockId);
    }
    return null;
  }

  bool _storedMarkTargetMatchesCurrentSelection() {
    final target = _storedMarkTarget;
    if (target == null) return false;
    if (target != _currentStoredMarkTarget()) return false;
    final selection = _activeTableCell != null
        ? _tableCellController.selection
        : _formattedBlockController.selection;
    return selection.isValid && selection.isCollapsed;
  }

  void _clearStoredMarks() {
    _storedMarkTarget = null;
    _storedMarks = const {};
  }

  void _clearStoredMarksForExpandedSelection() {
    final target = _currentStoredMarkTarget();
    if (_storedMarkTarget != target) return;
    final selection = _activeTableCell != null
        ? _tableCellController.selection
        : _formattedBlockController.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      _clearStoredMarks();
    }
  }

  bool _toggleStoredMarkCommand(MarkdownEditorCommand command) {
    if (!_isStoredMarkCommand(command)) return false;

    final target = _currentStoredMarkTarget();
    if (target == null) return false;
    final selection = _activeTableCell != null
        ? _tableCellController.selection
        : _formattedBlockController.selection;
    if (!selection.isValid || !selection.isCollapsed) return false;

    final nextMarks = target == _storedMarkTarget
        ? Set<MarkdownEditorCommand>.of(_storedMarks)
        : _effectiveStoredMarksAtCurrentSelection();

    if (command == MarkdownEditorCommand.inlineCode) {
      if (nextMarks.contains(command)) {
        nextMarks.clear();
      } else {
        nextMarks
          ..clear()
          ..add(command);
      }
    } else {
      nextMarks.remove(MarkdownEditorCommand.inlineCode);
      if (!nextMarks.add(command)) {
        nextMarks.remove(command);
      }
    }

    setState(() {
      _storedMarkTarget = target;
      _storedMarks = Set<MarkdownEditorCommand>.unmodifiable(nextMarks);
    });
    _requestActiveEditorFocus();
    return true;
  }

  Set<MarkdownEditorCommand> _effectiveStoredMarksAtCurrentSelection() {
    final marks = <MarkdownEditorCommand>{};
    if (_activeInlineSelectionContains((node) => node is MarkdownStrong)) {
      marks.add(MarkdownEditorCommand.bold);
    }
    if (_activeInlineSelectionContains((node) => node is MarkdownEmphasis)) {
      marks.add(MarkdownEditorCommand.italic);
    }
    if (_activeInlineSelectionContains(
      (node) => node is MarkdownStrikethrough,
    )) {
      marks.add(MarkdownEditorCommand.strikethrough);
    }
    if (_activeInlineSelectionContains((node) => node is MarkdownInlineCode)) {
      return {MarkdownEditorCommand.inlineCode};
    }
    return marks;
  }

  List<MarkdownInlineNode> _storedMarkedTextNodes(String text) {
    if (_storedMarks.contains(MarkdownEditorCommand.inlineCode)) {
      return [MarkdownInlineCode(text)];
    }

    var nodes = <MarkdownInlineNode>[MarkdownText(text)];
    if (_storedMarks.contains(MarkdownEditorCommand.bold)) {
      nodes = [MarkdownStrong(nodes)];
    }
    if (_storedMarks.contains(MarkdownEditorCommand.italic)) {
      nodes = [MarkdownEmphasis(nodes)];
    }
    if (_storedMarks.contains(MarkdownEditorCommand.strikethrough)) {
      nodes = [MarkdownStrikethrough(nodes)];
    }
    return nodes;
  }

  String? _inlineSelectionMarkdown(
    List<MarkdownInlineNode> children,
    TextSelection selection,
  ) {
    if (selection.isCollapsed) return null;

    final plainText = _inlinePlainText(children);
    final start = selection.start.clamp(0, plainText.length).toInt();
    final end = selection.end.clamp(start, plainText.length).toInt();
    if (start == end) return null;

    final selected =
        _sliceInlineNodes(children, TextRange(start: start, end: end));
    if (selected.isEmpty) return null;
    return _inlineMarkdown(selected);
  }

  List<MarkdownInlineNode> _sliceInlineNodes(
    List<MarkdownInlineNode> children,
    TextRange range,
  ) {
    final result = <MarkdownInlineNode>[];
    var cursor = 0;

    for (final child in children) {
      final childStart = cursor;
      final childEnd = childStart + child.plainText.length;
      cursor = childEnd;

      if (childEnd <= range.start) continue;
      if (childStart >= range.end) break;

      final localStart =
          (range.start - childStart).clamp(0, child.plainText.length).toInt();
      final localEnd = (range.end - childStart)
          .clamp(localStart, child.plainText.length)
          .toInt();
      final sliced = _sliceInlineNode(
        child,
        TextRange(start: localStart, end: localEnd),
      );
      if (sliced != null && sliced.plainText.isNotEmpty) {
        result.add(sliced);
      }
    }

    return result;
  }

  MarkdownInlineNode? _sliceInlineNode(
    MarkdownInlineNode node,
    TextRange range,
  ) {
    final length = node.plainText.length;
    final start = range.start.clamp(0, length).toInt();
    final end = range.end.clamp(start, length).toInt();
    if (start == end) return null;
    if (start == 0 && end == length) return node;

    switch (node) {
      case MarkdownText():
        return MarkdownText(node.text.substring(start, end));
      case MarkdownStrong():
        final children = _sliceInlineNodes(
          node.children,
          TextRange(start: start, end: end),
        );
        return children.isEmpty ? null : MarkdownStrong(children);
      case MarkdownEmphasis():
        final children = _sliceInlineNodes(
          node.children,
          TextRange(start: start, end: end),
        );
        return children.isEmpty ? null : MarkdownEmphasis(children);
      case MarkdownStrikethrough():
        final children = _sliceInlineNodes(
          node.children,
          TextRange(start: start, end: end),
        );
        return children.isEmpty ? null : MarkdownStrikethrough(children);
      case MarkdownLink():
        final children = _sliceInlineNodes(
          node.children,
          TextRange(start: start, end: end),
        );
        return children.isEmpty
            ? null
            : MarkdownLink(
                url: node.url,
                title: node.title,
                children: children,
              );
      case MarkdownInlineCode():
        return MarkdownInlineCode(node.code.substring(start, end));
      case MarkdownInlineMath():
        return MarkdownInlineMath(node.latex.substring(start, end));
      case MarkdownHardBreak() || MarkdownImage() || MarkdownWikilink():
        return start == 0 && end == length ? node : null;
      default:
        final text = node.plainText;
        return MarkdownText(text.substring(start, end));
    }
  }

  void _activateTableCell(
    String tableId, {
    required int rowIndex,
    required int columnIndex,
    required bool header,
    required List<MarkdownInlineNode> children,
  }) {
    final nextStoredTarget = _StoredMarkTarget.tableCell(
      tableId: tableId,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      header: header,
    );
    if (nextStoredTarget != _storedMarkTarget) {
      _clearStoredMarks();
    }

    _syncingTableCell = true;
    _tableCellController
      ..inlineNodes = children
      ..value = TextEditingValue(
        text: _inlinePlainText(children),
        selection: TextSelection.collapsed(
          offset: _inlinePlainText(children).length,
        ),
      );
    _syncingTableCell = false;

    setState(() {
      _clearActiveFormattedBlock();
      _activeTableCell = _TableCellSelection(
        tableId: tableId,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        header: header,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tableCellFocusNode.requestFocus();
      }
    });
  }

  void _handleTableCellChanged() {
    if (_syncingTableCell) return;
    if (_hasActiveComposing(_tableCellController.value)) return;

    final cell = _activeTableCell;
    if (cell == null) return;

    final table = _controller.document.blockById(cell.tableId);
    if (table is! MarkdownTableBlock) return;
    final currentChildren = _tableCellChildren(
      table,
      rowIndex: cell.rowIndex,
      columnIndex: cell.columnIndex,
      header: cell.header,
    );
    final currentText = _inlinePlainText(currentChildren);
    final nextText = _tableCellController.text;

    if (currentText == nextText) {
      _clearStoredMarksForExpandedSelection();
      return;
    }

    if (_applyTableCellLinkPaste(cell, currentText, nextText)) {
      return;
    }

    if (_applyTableCellInlineMarkdownPaste(
      cell,
      currentChildren,
      currentText,
      nextText,
    )) {
      return;
    }

    if (_applyTableCellStoredMarkInsertion(
      cell,
      currentText,
      nextText,
    )) {
      return;
    }

    if (!_controller.documentEditor.replaceTableCellText(
      blockId: cell.tableId,
      rowIndex: cell.rowIndex,
      columnIndex: cell.columnIndex,
      header: cell.header,
      text: nextText,
    )) {
      return;
    }

    if (_applyTableCellInlineInputRule(cell, nextText)) {
      return;
    }

    final nextTable = _controller.document.blockById(cell.tableId);
    if (nextTable is! MarkdownTableBlock) return;
    _tableCellController.inlineNodes = _tableCellChildren(
      nextTable,
      rowIndex: cell.rowIndex,
      columnIndex: cell.columnIndex,
      header: cell.header,
    );
  }

  bool _applyTableCellStoredMarkInsertion(
    _TableCellSelection cell,
    String currentText,
    String nextText,
  ) {
    if (!_storedMarkTargetMatchesCurrentSelection()) return false;

    final diff = _plainTextDiff(currentText, nextText);
    if (!diff.range.isCollapsed ||
        diff.replacement.isEmpty ||
        diff.replacement.contains('\n')) {
      return false;
    }

    final applied =
        _controller.documentEditor.replaceTableCellRangeWithInlineNodes(
      blockId: cell.tableId,
      rowIndex: cell.rowIndex,
      columnIndex: cell.columnIndex,
      header: cell.header,
      range: diff.range,
      replacement: _storedMarkedTextNodes(diff.replacement),
    );
    if (!applied) return false;

    _syncActiveTableCell(
      selectionOffset: diff.range.start + diff.replacement.length,
    );
    return true;
  }

  bool _applyTableCellInlineMarkdownPaste(
    _TableCellSelection cell,
    List<MarkdownInlineNode> currentChildren,
    String currentText,
    String nextText,
  ) {
    if (!_looksLikePastedMarkdown(nextText) ||
        nextText.trimRight().contains('\n') ||
        !_inlineChildrenHaveOnlyPlainText(currentChildren)) {
      return false;
    }

    final parsed = MarkdownDocumentCodec(plugins: widget.plugins).parse(
      nextText,
    );
    if (parsed.blocks.length != 1) return false;

    final parsedBlock = parsed.blocks.single;
    final children = switch (parsedBlock) {
      MarkdownParagraphBlock() => parsedBlock.children,
      MarkdownHeadingBlock() => parsedBlock.children,
      _ => null,
    };
    final normalizedChildren =
        children == null ? null : _normalizeInlinePasteNodes(children);
    if (normalizedChildren == null || normalizedChildren.isEmpty) return false;
    if (normalizedChildren.length == 1 &&
        normalizedChildren.single is MarkdownText &&
        normalizedChildren.single.plainText == nextText) {
      return false;
    }

    final replaced =
        _controller.documentEditor.replaceTableCellRangeWithInlineNodes(
      blockId: cell.tableId,
      rowIndex: cell.rowIndex,
      columnIndex: cell.columnIndex,
      header: cell.header,
      range: TextRange(start: 0, end: currentText.length),
      replacement: normalizedChildren,
    );
    if (!replaced) return false;

    final table = _controller.document.blockById(cell.tableId);
    if (table is! MarkdownTableBlock) return false;
    final nextChildren = _tableCellChildren(
      table,
      rowIndex: cell.rowIndex,
      columnIndex: cell.columnIndex,
      header: cell.header,
    );
    final plainText = _inlinePlainText(nextChildren);

    _syncingTableCell = true;
    _tableCellController
      ..inlineNodes = nextChildren
      ..value = TextEditingValue(
        text: plainText,
        selection: TextSelection.collapsed(offset: plainText.length),
      );
    _syncingTableCell = false;
    _tableCellFocusNode.requestFocus();
    setState(() {});
    return true;
  }

  bool _applyTableCellLinkPaste(
    _TableCellSelection cell,
    String currentText,
    String nextText,
  ) {
    final diff = _plainTextDiff(currentText, nextText);
    final url = _linkPasteUrl(diff.replacement);
    if (url == null) return false;

    final applied = diff.range.isCollapsed
        ? _controller.documentEditor.replaceTableCellRangeWithInlineNodes(
            blockId: cell.tableId,
            rowIndex: cell.rowIndex,
            columnIndex: cell.columnIndex,
            header: cell.header,
            range: diff.range,
            replacement: _linkPasteInsertedNodes(diff.replacement, url),
          )
        : _controller.documentEditor.applyTableCellInlineCommand(
            blockId: cell.tableId,
            rowIndex: cell.rowIndex,
            columnIndex: cell.columnIndex,
            header: cell.header,
            range: diff.range,
            command: MarkdownEditorCommand.link,
            argument: url,
          );
    if (!applied) return false;

    final table = _controller.document.blockById(cell.tableId);
    if (table is! MarkdownTableBlock) return false;
    final nextChildren = _tableCellChildren(
      table,
      rowIndex: cell.rowIndex,
      columnIndex: cell.columnIndex,
      header: cell.header,
    );
    final plainText = _inlinePlainText(nextChildren);
    final selectionOffset = (diff.range.isCollapsed
            ? diff.range.start + diff.replacement.length
            : diff.range.end)
        .clamp(0, plainText.length)
        .toInt();

    _syncingTableCell = true;
    _tableCellController
      ..inlineNodes = nextChildren
      ..value = TextEditingValue(
        text: plainText,
        selection: TextSelection.collapsed(offset: selectionOffset),
      );
    _syncingTableCell = false;
    _tableCellFocusNode.requestFocus();
    setState(() {});
    return true;
  }

  bool _applyTableCellInlineInputRule(
    _TableCellSelection cell,
    String text,
  ) {
    final selection = _tableCellController.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      return false;
    }

    final match = _inlineInputRuleMatch(text, selection.extentOffset);
    if (match == null) return false;

    final applied =
        _controller.documentEditor.replaceTableCellRangeWithInlineNodes(
      blockId: cell.tableId,
      rowIndex: cell.rowIndex,
      columnIndex: cell.columnIndex,
      header: cell.header,
      range: match.range,
      replacement: match.replacement,
    );
    if (!applied) return false;

    final table = _controller.document.blockById(cell.tableId);
    if (table is! MarkdownTableBlock) return false;
    final children = _tableCellChildren(
      table,
      rowIndex: cell.rowIndex,
      columnIndex: cell.columnIndex,
      header: cell.header,
    );
    final plainText = _inlinePlainText(children);
    final selectionOffset = match.range.start + match.plainText.length;

    _syncingTableCell = true;
    _tableCellController
      ..inlineNodes = children
      ..value = TextEditingValue(
        text: plainText,
        selection: TextSelection.collapsed(
          offset: selectionOffset.clamp(0, plainText.length),
        ),
      );
    _syncingTableCell = false;
    _tableCellFocusNode.requestFocus();
    setState(() {});
    return true;
  }

  KeyEventResult _handleTableCellKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final isModifierPressed = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed;
    if (isModifierPressed) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      final moved = _moveActiveTableCell(
        backward: HardwareKeyboard.instance.isShiftPressed,
      );
      return moved ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final moved = _moveActiveTableCellToNextRow();
      return moved ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  bool _moveActiveTableCell({required bool backward}) {
    final cell = _activeTableCell;
    if (cell == null || !widget.enabled) return false;

    final table = _controller.document.blockById(cell.tableId);
    if (table is! MarkdownTableBlock || table.columnCount == 0) return false;

    final nextCell = backward
        ? _previousTableCell(table, cell)
        : _nextTableCell(table, cell);
    if (nextCell == null) return true;

    var nextTable = table;
    if (!backward &&
        !nextCell.header &&
        nextCell.rowIndex == table.rows.length) {
      _controller.documentEditor.insertTableRowAfter(
        table.id,
        table.rows.length - 1,
      );
      final updated = _controller.document.blockById(table.id);
      if (updated is! MarkdownTableBlock) return true;
      nextTable = updated;
    }

    _activateTableCell(
      nextCell.tableId,
      rowIndex: nextCell.rowIndex,
      columnIndex: nextCell.columnIndex,
      header: nextCell.header,
      children: _tableCellChildren(
        nextTable,
        rowIndex: nextCell.rowIndex,
        columnIndex: nextCell.columnIndex,
        header: nextCell.header,
      ),
    );
    return true;
  }

  bool _moveActiveTableCellToNextRow() {
    final cell = _activeTableCell;
    if (cell == null || !widget.enabled) return false;

    final table = _controller.document.blockById(cell.tableId);
    if (table is! MarkdownTableBlock || table.columnCount == 0) return false;

    final columnIndex =
        cell.columnIndex.clamp(0, table.columnCount - 1).toInt();
    final rowIndex = cell.header ? 0 : cell.rowIndex + 1;
    var nextTable = table;

    if (rowIndex >= table.rows.length) {
      _controller.documentEditor.insertTableRowAfter(
        table.id,
        table.rows.length - 1,
      );
      final updated = _controller.document.blockById(table.id);
      if (updated is! MarkdownTableBlock) return true;
      nextTable = updated;
    }

    _activateTableCell(
      cell.tableId,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      header: false,
      children: _tableCellChildren(
        nextTable,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        header: false,
      ),
    );
    return true;
  }

  _TableCellSelection? _nextTableCell(
    MarkdownTableBlock table,
    _TableCellSelection cell,
  ) {
    if (cell.tableId != table.id || cell.columnIndex < 0) return null;

    if (cell.header) {
      if (cell.columnIndex + 1 < table.columnCount) {
        return cell.copyWith(columnIndex: cell.columnIndex + 1);
      }
      return cell.copyWith(rowIndex: 0, columnIndex: 0, header: false);
    }

    if (cell.rowIndex < 0) return null;
    if (cell.columnIndex + 1 < table.columnCount) {
      return cell.copyWith(columnIndex: cell.columnIndex + 1);
    }
    if (cell.rowIndex + 1 < table.rows.length) {
      return cell.copyWith(rowIndex: cell.rowIndex + 1, columnIndex: 0);
    }

    return cell.copyWith(rowIndex: table.rows.length, columnIndex: 0);
  }

  _TableCellSelection? _previousTableCell(
    MarkdownTableBlock table,
    _TableCellSelection cell,
  ) {
    if (cell.tableId != table.id || cell.columnIndex < 0) return null;

    if (!cell.header) {
      if (cell.columnIndex > 0) {
        return cell.copyWith(columnIndex: cell.columnIndex - 1);
      }
      if (cell.rowIndex > 0) {
        return cell.copyWith(
          rowIndex: cell.rowIndex - 1,
          columnIndex: table.columnCount - 1,
        );
      }
      return cell.copyWith(
        rowIndex: 0,
        columnIndex: table.columnCount - 1,
        header: true,
      );
    }

    if (cell.columnIndex > 0) {
      return cell.copyWith(columnIndex: cell.columnIndex - 1);
    }
    return null;
  }

  void _insertTableRowAfterActive(MarkdownTableBlock table) {
    final active = _activeTableCell;
    final rowIndex = active?.tableId == table.id && !active!.header
        ? active.rowIndex
        : table.rows.length - 1;
    _controller.documentEditor.insertTableRowAfter(table.id, rowIndex);
  }

  void _insertTableRowBeforeActive(MarkdownTableBlock table) {
    final active = _activeTableCell;
    final rowIndex =
        active?.tableId == table.id && !active!.header ? active.rowIndex : 0;
    _controller.documentEditor.insertTableRowBefore(table.id, rowIndex);
  }

  void _insertTableColumnAfterActive(MarkdownTableBlock table) {
    final active = _activeTableCell;
    final columnIndex = active?.tableId == table.id
        ? active!.columnIndex
        : table.columnCount - 1;
    _controller.documentEditor.insertTableColumnAfter(table.id, columnIndex);
  }

  void _insertTableColumnBeforeActive(MarkdownTableBlock table) {
    final active = _activeTableCell;
    final columnIndex = active?.tableId == table.id ? active!.columnIndex : 0;
    _controller.documentEditor.insertTableColumnBefore(table.id, columnIndex);
  }

  bool _canDeleteActiveTableRow(MarkdownTableBlock table) {
    final active = _activeTableCell;
    return active != null &&
        active.tableId == table.id &&
        !active.header &&
        table.rows.isNotEmpty;
  }

  bool _canDeleteActiveTableColumn(MarkdownTableBlock table) {
    final active = _activeTableCell;
    return active != null &&
        active.tableId == table.id &&
        table.columnCount > 1;
  }

  void _deleteActiveTableRow(MarkdownTableBlock table) {
    final active = _activeTableCell;
    if (active == null || active.tableId != table.id || active.header) return;
    _controller.documentEditor.deleteTableRow(table.id, active.rowIndex);
    setState(() => _activeTableCell = null);
  }

  void _deleteActiveTableColumn(MarkdownTableBlock table) {
    final active = _activeTableCell;
    if (active == null || active.tableId != table.id) return;
    _controller.documentEditor.deleteTableColumn(table.id, active.columnIndex);
    setState(() => _activeTableCell = null);
  }

  void _toggleTableHeaderRow(MarkdownTableBlock table) {
    _controller.documentEditor.toggleTableHeaderRow(table.id);
  }

  void _toggleTableHeaderColumn(MarkdownTableBlock table) {
    _controller.documentEditor.toggleTableHeaderColumn(table.id);
  }

  void _deleteActiveTable(MarkdownTableBlock table) {
    _controller.documentEditor.deleteTable(table.id);
    setState(() => _activeTableCell = null);
  }

  Widget _buildFormattedFrontmatterSegment(
    BuildContext context,
    _MarkdownBlockSegment segment,
    MarkdownFrontmatterBlock block,
  ) {
    final theme = Theme.of(context);
    final textStyle = _sourceTextStyle(context) ??
        theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace');

    return DecoratedBox(
      key: ValueKey(
        'smooth_markdown_editor_frontmatter_block_${segment.range.start}',
      ),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor.withOpacity(0.55)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: const SizedBox(
              height: 40,
              child: Row(
                children: [
                  SizedBox(width: 12),
                  Icon(Icons.data_object, size: 18),
                  SizedBox(width: 8),
                  Text('Frontmatter'),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _FrontmatterEditor(
              key: ValueKey(
                'smooth_markdown_editor_frontmatter_editor_${block.id}',
              ),
              fieldKey: ValueKey(
                'smooth_markdown_editor_frontmatter_source_${segment.range.start}',
              ),
              content: block.content,
              enabled: widget.enabled,
              textStyle: textStyle,
              onChanged: (content) {
                _controller.documentEditor.updateFrontmatter(
                  block.id,
                  content,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedCodeBlockSegment(
    BuildContext context,
    _MarkdownBlockSegment segment,
    _FencedCodeBlock codeBlock,
  ) {
    final theme = Theme.of(context);
    final selectedLanguage = _supportedCodeLanguages.any(
      (language) => language.value == codeBlock.language,
    )
        ? codeBlock.language
        : '';
    final isMermaid = codeBlock.language == 'mermaid';
    final showMermaidSource = isMermaid &&
        (_mermaidSourceBlocks.contains(segment.range.start) ||
            codeBlock.code.trim().isEmpty);
    final copied = _copiedCodeBlockStart == segment.range.start;

    return DecoratedBox(
      key: ValueKey('smooth_markdown_editor_code_block_${segment.range.start}'),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor.withOpacity(0.55)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Edit code',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: widget.enabled
                        ? () => _activateFormattedSegment(segment)
                        : null,
                  ),
                  IconButton(
                    tooltip: copied ? 'Copied' : 'Copy code',
                    icon: Icon(
                      copied ? Icons.check : Icons.copy,
                      size: 18,
                    ),
                    onPressed: codeBlock.code.trim().isEmpty
                        ? null
                        : () => _copyCodeBlock(segment, codeBlock),
                  ),
                  if (isMermaid)
                    IconButton(
                      key: ValueKey(
                        'smooth_markdown_editor_mermaid_toggle_${segment.range.start}',
                      ),
                      tooltip: showMermaidSource
                          ? 'Preview Mermaid'
                          : 'Edit Mermaid source',
                      icon: Icon(
                        showMermaidSource
                            ? Icons.visibility_outlined
                            : Icons.edit_outlined,
                        size: 18,
                      ),
                      onPressed: () => _toggleMermaidSource(segment),
                    ),
                  const Spacer(),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: ValueKey(
                        'smooth_markdown_editor_code_language_${segment.range.start}',
                      ),
                      value: selectedLanguage,
                      items: [
                        for (final language in _supportedCodeLanguages)
                          DropdownMenuItem(
                            value: language.value,
                            child: Text(language.label),
                          ),
                      ],
                      onChanged: widget.enabled
                          ? (language) => _updateCodeBlockLanguage(
                                segment,
                                codeBlock,
                                language ?? '',
                              )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: showMermaidSource
                ? _buildMermaidSourceView(context, segment, codeBlock)
                : _renderMarkdown(segment.source),
          ),
        ],
      ),
    );
  }

  Widget _buildMermaidSourceView(
    BuildContext context,
    _MarkdownBlockSegment segment,
    _FencedCodeBlock codeBlock,
  ) {
    final theme = Theme.of(context);
    final textStyle = _sourceTextStyle(context) ??
        theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace');

    return InkWell(
      key: ValueKey(
          'smooth_markdown_editor_mermaid_source_${segment.range.start}'),
      borderRadius: BorderRadius.circular(6),
      onTap: widget.enabled ? () => _activateFormattedSegment(segment) : null,
      child: DecoratedBox(
        decoration: widget.styleSheet?.codeBlockDecoration ??
            BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
              borderRadius: BorderRadius.circular(6),
            ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding:
              widget.styleSheet?.codeBlockPadding ?? const EdgeInsets.all(12),
          child: Text(
            codeBlock.code.isEmpty ? ' ' : codeBlock.code,
            style: textStyle,
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedBlockMathSegment(
    BuildContext context,
    _MarkdownBlockSegment segment,
    String latex,
  ) {
    final theme = Theme.of(context);
    final blockKey =
        ValueKey('smooth_markdown_editor_block_math_${segment.range.start}');
    final borderRadius = BorderRadius.circular(8);
    final openEditor =
        widget.enabled ? () => _showBlockMathEditor(segment, latex) : null;

    return Focus(
      key: blockKey,
      canRequestFocus: widget.enabled,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent || openEditor == null) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space) {
          openEditor();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        button: widget.enabled,
        label: 'Block Math',
        child: InkWell(
          key: ValueKey(
            'smooth_markdown_editor_block_math_action_${segment.range.start}',
          ),
          borderRadius: borderRadius,
          onTap: openEditor,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor.withOpacity(0.55)),
              borderRadius: borderRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  child: SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        const Icon(Icons.functions, size: 18),
                        const SizedBox(width: 8),
                        const Text('Block Math'),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Edit math',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: openEditor,
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _renderBlockMath(context, latex),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedImageSegment(
    BuildContext context,
    _MarkdownBlockSegment segment,
    MarkdownImageBlock block,
  ) {
    final theme = Theme.of(context);
    return DecoratedBox(
      key:
          ValueKey('smooth_markdown_editor_image_block_${segment.range.start}'),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor.withOpacity(0.55)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.image_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      block.alt.isEmpty ? block.url : block.alt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    key: ValueKey(
                      'smooth_markdown_editor_image_edit_${segment.range.start}',
                    ),
                    tooltip: 'Edit image',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: widget.enabled
                        ? () => unawaited(_showImageBlockEditor(block))
                        : null,
                  ),
                  IconButton(
                    key: ValueKey(
                      'smooth_markdown_editor_image_delete_${segment.range.start}',
                    ),
                    tooltip: 'Delete image',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: widget.enabled
                        ? () {
                            _controller.documentEditor.removeBlock(block.id);
                            setState(_clearActiveFormattedBlock);
                          }
                        : null,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _renderMarkdown(block.toMarkdown()),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcePane(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: widget.sourceDecoration ??
          BoxDecoration(color: theme.colorScheme.surface),
      child: TextField(
        key: _sourceKey,
        controller: _controller.textController,
        focusNode: _focusNode,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        scrollController: _sourceScrollController,
        expands: true,
        maxLines: null,
        minLines: null,
        textAlignVertical: TextAlignVertical.top,
        style: _sourceTextStyle(context),
        keyboardType: TextInputType.multiline,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: widget.placeholder,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildPreviewPane(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: widget.previewDecoration ??
          BoxDecoration(color: theme.colorScheme.surface),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _renderMarkdown(_controller.text),
      ),
    );
  }

  TextStyle? _sourceTextStyle(BuildContext context) {
    return widget.textStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              height: 1.5,
            );
  }

  TextStyle? _formattedEditingTextStyle(
    BuildContext context,
    MarkdownBlock? block,
  ) {
    final theme = Theme.of(context);
    if (block is MarkdownHeadingBlock) {
      final style = switch (block.level) {
        1 => theme.textTheme.headlineMedium,
        2 => theme.textTheme.headlineSmall,
        3 => theme.textTheme.titleLarge,
        4 => theme.textTheme.titleMedium,
        _ => theme.textTheme.titleSmall,
      };
      return style?.copyWith(fontWeight: FontWeight.w700, height: 1.25);
    }
    return widget.textStyle ??
        theme.textTheme.bodyMedium?.copyWith(height: 1.5);
  }

  Widget _renderMarkdown(String data) {
    return SmoothMarkdown(
      data: data,
      styleSheet: widget.styleSheet,
      config: widget.config,
      onTapLink: widget.onTapLink == null ? null : _handleEditorLinkTap,
      onTapImage: widget.onTapImage,
      imageBuilder: widget.imageBuilder,
      codeBuilder: widget.codeBuilder,
      useEnhancedComponents: widget.useEnhancedComponents,
      enableCache: widget.enableCache,
      useRepaintBoundary: false,
      plugins: _previewPlugins(),
      builderRegistry: _previewBuilderRegistry(),
    );
  }

  void _handleEditorLinkTap(String url) {
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isMetaPressed && !keyboard.isControlPressed) return;

    final normalizedUrl = _normalizeAllowedLinkUrl(url);
    if (normalizedUrl == null || normalizedUrl.isEmpty) return;

    widget.onTapLink?.call(normalizedUrl);
  }

  Widget _renderBlockMath(BuildContext context, String latex) {
    final styleSheet = widget.styleSheet ?? MarkdownStyleSheet.light();
    return const BlockMathBuilder().build(
      BlockMathNode(latex),
      styleSheet,
      MarkdownRenderContext(
        styleSheet: styleSheet,
        selectable: false,
      ),
    );
  }

  void _activateFormattedSegment(
    _MarkdownBlockSegment segment, {
    TextSelection? selection,
  }) {
    final plainTextEditing = _usesPlainTextEditing(segment.block);
    final editingText =
        plainTextEditing ? segment.block!.plainText : segment.source;
    final localSelection = _localSelectionForSegment(
      segment,
      selection,
      editingText.length,
      plainTextEditing: plainTextEditing,
    );
    final nextStoredTarget = plainTextEditing && segment.block != null
        ? _StoredMarkTarget.formattedBlock(segment.block!.id)
        : null;
    if (nextStoredTarget == null || nextStoredTarget != _storedMarkTarget) {
      _clearStoredMarks();
    }
    _syncingFormattedBlock = true;
    _formattedBlockController.block = plainTextEditing ? segment.block : null;
    _formattedBlockController.value = TextEditingValue(
      text: editingText,
      selection: localSelection,
    );
    _syncingFormattedBlock = false;

    setState(() {
      _activeFormattedRange = segment.range;
      _activeFormattedBlockId = plainTextEditing ? segment.block!.id : null;
      _activeFormattedContainerBlockId = plainTextEditing
          ? segment.containerBlockId ?? segment.block!.id
          : null;
      _activeFormattedBlockSourceOffset =
          plainTextEditing ? segment.blockSourceOffset : 0;
      _activeFormattedPlainText = plainTextEditing;
    });
    _controller.textController.selection = plainTextEditing
        ? _sourceSelectionForPlainTextSelection(
            segment.block!,
            segment.source,
            localSelection,
            sourceBaseOffset: segment.range.start + segment.blockSourceOffset,
          )
        : TextSelection(
            baseOffset: segment.range.start + localSelection.baseOffset,
            extentOffset: segment.range.start + localSelection.extentOffset,
          );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _formattedBlockFocusNode.requestFocus();
      }
    });
  }

  void _handleFormattedBlockChanged() {
    if (_syncingFormattedBlock) return;
    if (_hasActiveComposing(_formattedBlockController.value)) return;

    final range = _activeFormattedRange;
    if (range == null) return;

    if (_activeFormattedPlainText && _activeFormattedBlockId != null) {
      _handlePlainTextFormattedBlockChanged(range);
      return;
    }

    final text = _controller.text;
    if (range.start < 0 || range.start > text.length) return;
    final end = range.end.clamp(range.start, text.length);
    final replacement = _formattedBlockController.text;
    final nextRange = TextRange(
      start: range.start,
      end: range.start + replacement.length,
    );

    final localSelection = _formattedBlockController.selection;
    final globalSelection = localSelection.isValid
        ? TextSelection(
            baseOffset: range.start + localSelection.baseOffset,
            extentOffset: range.start + localSelection.extentOffset,
          )
        : TextSelection.collapsed(offset: nextRange.end);

    _activeFormattedRange = nextRange;

    if (text.substring(range.start, end) == replacement) {
      _controller.textController.selection = globalSelection;
      return;
    }

    _controller.replaceRange(
      TextRange(start: range.start, end: end),
      replacement,
      selection: globalSelection,
    );
  }

  void _handlePlainTextFormattedBlockChanged(TextRange range) {
    final block = _controller.document.blockById(_activeFormattedBlockId!);
    final replacement = _formattedBlockController.text;
    if (_applyFormattedBlockImageInputRule(block, replacement)) {
      return;
    }
    if (_applyFormattedMarkdownPaste(range, block, replacement)) return;
    if (_applyFormattedInputRule(range, block, replacement)) return;

    if (block != null && block.plainText == replacement) {
      _clearStoredMarksForExpandedSelection();
      final sourceOffset = _activeFormattedBlockSourceOffset +
          _plainTextSourceOffsetFor(block, block.toMarkdown());
      final localSelection = _formattedBlockController.selection;
      final globalSelection = localSelection.isValid
          ? TextSelection(
              baseOffset:
                  range.start + sourceOffset + localSelection.baseOffset,
              extentOffset:
                  range.start + sourceOffset + localSelection.extentOffset,
            )
          : TextSelection.collapsed(
              offset: range.start + sourceOffset + block.plainText.length,
            );
      _controller.textController.selection = globalSelection;
      return;
    }

    if (_preserveFormattedWikilinkTrigger(range, block, replacement)) {
      return;
    }

    if (_applyFormattedLinkPaste(range, block, replacement)) {
      return;
    }

    if (_applyFormattedStoredMarkInsertion(range, block, replacement)) {
      return;
    }

    if (block == null ||
        !_controller.documentEditor.replaceTextBlockText(
          block.id,
          replacement,
        )) {
      return;
    }

    final nextBlock = _controller.document.blockById(block.id);
    if (nextBlock == null) return;

    if (_applyFormattedInlineInputRule(range, nextBlock, replacement)) {
      return;
    }

    final nextSource = nextBlock.toMarkdown();
    final sourceOffset = _activeFormattedBlockSourceOffset +
        _plainTextSourceOffsetFor(nextBlock, nextSource);
    final localSelection = _formattedBlockController.selection;
    final globalSelection = localSelection.isValid
        ? TextSelection(
            baseOffset: range.start + sourceOffset + localSelection.baseOffset,
            extentOffset:
                range.start + sourceOffset + localSelection.extentOffset,
          )
        : TextSelection.collapsed(
            offset: range.start + sourceOffset + nextBlock.plainText.length,
          );

    _formattedBlockController.block = nextBlock;
    _activeFormattedRange = _rangeForActiveContainer(range.start, nextBlock);
    _controller.textController.selection = globalSelection;
  }

  bool _applyFormattedStoredMarkInsertion(
    TextRange range,
    MarkdownBlock? block,
    String replacement,
  ) {
    if (!_usesPlainTextEditing(block) ||
        !_storedMarkTargetMatchesCurrentSelection()) {
      return false;
    }

    final diff = _plainTextDiff(block!.plainText, replacement);
    if (!diff.range.isCollapsed ||
        diff.replacement.isEmpty ||
        diff.replacement.contains('\n')) {
      return false;
    }

    final applied = _controller.documentEditor.replaceTextRangeWithInlineNodes(
      block.id,
      diff.range,
      _storedMarkedTextNodes(diff.replacement),
    );
    if (!applied) return false;

    final selectionOffset = diff.range.start + diff.replacement.length;
    _syncActiveFormattedBlock(
      block.id,
      selectionOffset: selectionOffset,
    );
    return true;
  }

  bool _preserveFormattedWikilinkTrigger(
    TextRange range,
    MarkdownBlock? block,
    String replacement,
  ) {
    if (!widget.enableWikilinks || !_usesPlainTextEditing(block)) {
      return false;
    }

    final localSelection = _formattedBlockController.selection;
    if (!localSelection.isValid || !localSelection.isCollapsed) {
      return false;
    }

    final cursor =
        localSelection.extentOffset.clamp(0, replacement.length).toInt();
    final open = replacement.lastIndexOf('[[', cursor);
    final close = replacement.lastIndexOf(']]', cursor);
    if (open == -1 || open <= close) return false;

    final query = replacement.substring(open + 2, cursor);
    if (query.contains('\n')) return false;

    final markdown = block!.toMarkdown();
    final sourceOffset = _activeFormattedBlockSourceOffset +
        _plainTextSourceOffsetFor(block, markdown);
    final sourceRange = TextRange(
      start: range.start + sourceOffset,
      end: range.start + sourceOffset + block.plainText.length,
    );
    final globalSelection = TextSelection(
      baseOffset: range.start + sourceOffset + localSelection.baseOffset,
      extentOffset: range.start + sourceOffset + localSelection.extentOffset,
    );

    _controller.replaceRange(
      sourceRange,
      replacement,
      selection: globalSelection,
    );
    _activeFormattedRange = TextRange(
      start: range.start,
      end: range.start + sourceOffset + replacement.length,
    );
    final nextBlock = _controller.document.blockById(block.id);
    if (nextBlock != null) {
      _formattedBlockController.block = nextBlock;
    }
    return true;
  }

  bool _applyFormattedInlineInputRule(
    TextRange range,
    MarkdownBlock block,
    String text,
  ) {
    if (!_usesPlainTextEditing(block)) return false;

    final localSelection = _formattedBlockController.selection;
    if (!localSelection.isValid || !localSelection.isCollapsed) {
      return false;
    }

    final match = _inlineInputRuleMatch(
      text,
      localSelection.extentOffset,
    );
    if (match == null) return false;

    final imageBlock = match.imageBlock;
    if (imageBlock != null) {
      final inserted =
          _controller.documentEditor.replaceTextRangeWithImageBlock(
        block.id,
        match.range,
        url: imageBlock.url,
        alt: imageBlock.alt,
        title: imageBlock.title,
      );
      if (inserted == null) return false;
      _syncActiveFormattedBlock(
        inserted.activeBlockId,
        selectionOffset: inserted.selectionOffset,
      );
      return true;
    }

    final applied = _controller.documentEditor.replaceTextRangeWithInlineNodes(
      block.id,
      match.range,
      match.replacement,
    );
    if (!applied) return false;

    final nextBlock = _controller.document.blockById(block.id);
    if (nextBlock == null) return false;

    final nextSelectionOffset = match.range.start + match.plainText.length;
    _syncingFormattedBlock = true;
    _formattedBlockController
      ..block = nextBlock
      ..value = TextEditingValue(
        text: nextBlock.plainText,
        selection: TextSelection.collapsed(
          offset: nextSelectionOffset.clamp(0, nextBlock.plainText.length),
        ),
      );
    _syncingFormattedBlock = false;

    final nextSource = nextBlock.toMarkdown();
    final sourceOffset = _activeFormattedBlockSourceOffset +
        _plainTextSourceOffsetFor(nextBlock, nextSource);
    _activeFormattedRange = _rangeForActiveContainer(range.start, nextBlock);
    _controller.textController.selection = _clampSourceSelection(
      TextSelection.collapsed(
        offset: range.start +
            sourceOffset +
            match.range.start +
            match.markdown.length,
      ),
    );
    _formattedBlockFocusNode.requestFocus();
    return true;
  }

  bool _applyFormattedBlockImageInputRule(
    MarkdownBlock? block,
    String text,
  ) {
    if (!_usesPlainTextEditing(block)) return false;

    final localSelection = _formattedBlockController.selection;
    if (!localSelection.isValid || !localSelection.isCollapsed) {
      return false;
    }

    final image = _blockImageInputRuleMatch(text);
    if (image == null) return false;

    final inserted = _controller.documentEditor.replaceBlockWithImageInputRule(
      block!.id,
      url: image.url,
      alt: image.alt,
      title: image.title,
    );
    if (inserted == null) return false;

    _syncActiveFormattedBlock(
      inserted.activeBlockId,
      selectionOffset: inserted.selectionOffset,
    );
    return true;
  }

  bool _applyFormattedLinkPaste(
    TextRange range,
    MarkdownBlock? block,
    String replacement,
  ) {
    if (!_usesPlainTextEditing(block)) return false;

    final diff = _plainTextDiff(block!.plainText, replacement);
    final url = _linkPasteUrl(diff.replacement);
    if (url == null) return false;

    if (diff.range.isCollapsed) {
      final applied =
          _controller.documentEditor.replaceTextRangeWithInlineNodes(
        block.id,
        diff.range,
        _linkPasteInsertedNodes(diff.replacement, url),
      );
      if (!applied) return false;
    } else {
      _controller.documentEditor.applyInlineCommand(
        block.id,
        diff.range,
        MarkdownEditorCommand.link,
        argument: url,
      );
    }

    final nextBlock = _controller.document.blockById(block.id);
    if (nextBlock == null) return false;

    final selectionOffset = (diff.range.isCollapsed
            ? diff.range.start + diff.replacement.length
            : diff.range.end)
        .clamp(0, nextBlock.plainText.length)
        .toInt();
    _syncingFormattedBlock = true;
    _formattedBlockController
      ..block = nextBlock
      ..value = TextEditingValue(
        text: nextBlock.plainText,
        selection: TextSelection.collapsed(offset: selectionOffset),
      );
    _syncingFormattedBlock = false;

    final nextSource = nextBlock.toMarkdown();
    final sourceOffset = _activeFormattedBlockSourceOffset +
        _plainTextSourceOffsetFor(nextBlock, nextSource);
    _activeFormattedRange = _rangeForActiveContainer(range.start, nextBlock);
    _controller.textController.selection = _clampSourceSelection(
      TextSelection.collapsed(
        offset: range.start + sourceOffset + nextSource.length,
      ),
    );
    _formattedBlockFocusNode.requestFocus();
    return true;
  }

  bool _applyFormattedMarkdownPaste(
    TextRange range,
    MarkdownBlock? block,
    String replacement,
  ) {
    if (block == null) {
      return false;
    }

    final diff = _plainTextDiff(block.plainText, replacement);
    final pastedMarkdown = diff.replacement;
    if (!_looksLikePastedMarkdown(pastedMarkdown)) {
      return false;
    }

    final trimmedLeft = pastedMarkdown.trimLeft();
    if (trimmedLeft.length != pastedMarkdown.length &&
        _blockImageInputRuleMatch(trimmedLeft) != null) {
      return false;
    }

    final isSingleLine = !pastedMarkdown.trimRight().contains('\n');
    if (isSingleLine && _looksLikeFormattedInputRuleTrigger(pastedMarkdown)) {
      return false;
    }

    if (isSingleLine && !_looksLikePastedBlockMarkdown(pastedMarkdown)) {
      return _applyFormattedInlineMarkdownPaste(
        range,
        block,
        replacement,
        diff,
      );
    }

    final previousContainer = _topLevelBlockContaining(block.id);
    final replacingTopLevel = previousContainer?.id == block.id;
    final parsed = MarkdownDocumentCodec(plugins: widget.plugins).parse(
      pastedMarkdown,
    );
    final inserted = _controller.documentEditor.replaceTextRangeWithBlocks(
      block.id,
      diff.range,
      parsed.blocks,
    );
    if (inserted == null) return false;

    final nextContainer = previousContainer == null
        ? null
        : _controller.document.blockById(previousContainer.id);

    final selectionOffset = replacingTopLevel
        ? range.start + inserted.selectionOffset
        : range.start +
            (nextContainer?.toMarkdown().length ?? inserted.selectionOffset);
    setState(_clearActiveFormattedBlock);
    _controller.textController.selection = _clampSourceSelection(
      TextSelection.collapsed(offset: selectionOffset),
    );
    return true;
  }

  bool _applyFormattedInlineMarkdownPaste(
    TextRange range,
    MarkdownBlock block,
    String replacement,
    _PlainTextDiff diff,
  ) {
    if (!_usesPlainTextEditing(block)) return false;
    if (!_textBlockHasOnlyPlainText(block)) return false;

    final parsed = MarkdownDocumentCodec(plugins: widget.plugins).parse(
      diff.replacement,
    );
    if (parsed.blocks.length != 1) return false;

    final parsedBlock = parsed.blocks.single;
    final children = switch (parsedBlock) {
      MarkdownParagraphBlock() => parsedBlock.children,
      MarkdownHeadingBlock() => parsedBlock.children,
      _ => null,
    };
    final normalizedChildren =
        children == null ? null : _normalizeInlinePasteNodes(children);
    if (normalizedChildren == null || normalizedChildren.isEmpty) return false;
    if (normalizedChildren.length == 1 &&
        normalizedChildren.single is MarkdownText &&
        normalizedChildren.single.plainText == diff.replacement) {
      return false;
    }

    final replaced = _controller.documentEditor.replaceTextRangeWithInlineNodes(
      block.id,
      diff.range,
      normalizedChildren,
    );
    if (!replaced) return false;

    final nextBlock = _controller.document.blockById(block.id);
    if (nextBlock == null) return false;
    _syncingFormattedBlock = true;
    _formattedBlockController
      ..block = nextBlock
      ..value = TextEditingValue(
        text: nextBlock.plainText,
        selection: TextSelection.collapsed(
          offset:
              diff.range.start + _inlinePlainText(normalizedChildren).length,
        ),
      );
    _syncingFormattedBlock = false;
    _activeFormattedRange = _rangeForActiveContainer(range.start, nextBlock);
    _controller.textController.selection = _clampSourceSelection(
      TextSelection.collapsed(
        offset: _activeFormattedRange!.start + nextBlock.toMarkdown().length,
      ),
    );
    _formattedBlockFocusNode.requestFocus();
    return true;
  }

  bool _textBlockHasOnlyPlainText(MarkdownBlock block) {
    final children = switch (block) {
      MarkdownParagraphBlock() => block.children,
      MarkdownHeadingBlock() => block.children,
      _ => const <MarkdownInlineNode>[],
    };
    return _inlineChildrenHaveOnlyPlainText(children);
  }

  bool _inlineChildrenHaveOnlyPlainText(List<MarkdownInlineNode> children) {
    return children.every((child) => child is MarkdownText);
  }

  List<MarkdownInlineNode> _normalizeInlinePasteNodes(
    List<MarkdownInlineNode> children,
  ) {
    return [
      for (final child in children) _normalizeInlinePasteNode(child),
    ];
  }

  MarkdownInlineNode _normalizeInlinePasteNode(MarkdownInlineNode child) {
    return switch (child) {
      MarkdownLink() => _normalizeInlinePasteLink(child),
      MarkdownStrong() => MarkdownStrong(
          _normalizeInlinePasteNodes(child.children),
        ),
      MarkdownEmphasis() => MarkdownEmphasis(
          _normalizeInlinePasteNodes(child.children),
        ),
      MarkdownStrikethrough() => MarkdownStrikethrough(
          _normalizeInlinePasteNodes(child.children),
        ),
      _ => child,
    };
  }

  MarkdownInlineNode _normalizeInlinePasteLink(MarkdownLink link) {
    final url = _normalizeAllowedLinkUrl(link.url);
    if (url == null || url.isEmpty) return MarkdownText(link.toMarkdown());
    return MarkdownLink(
      url: url,
      title: link.title,
      children: _normalizeInlinePasteNodes(link.children),
    );
  }

  bool _looksLikePastedMarkdown(String text) {
    final markdownPatterns = RegExp(
      r'^#{1,6}\s|^\s*[-*+]\s|^\s*\d+\.\s|^\s*>\s|```|^\s*\[.*\]\(.*\)|^\s*!\[|\*\*.*\*\*|__.*__|~~.*~~|^\s*[-*_]{3,}\s*$|^\|.+\||\$\$[\s\S]+?\$\$',
      multiLine: true,
    );
    return markdownPatterns.hasMatch(text);
  }

  bool _looksLikePastedBlockMarkdown(String text) {
    final blockPatterns = RegExp(
      r'^#{1,6}\s|^\s*[-*+]\s|^\s*\d+\.\s|^\s*>\s|```|^\s*!\[|^\s*[-*_]{3,}\s*$|^\|.+\||\$\$[\s\S]+?\$\$',
      multiLine: true,
    );
    return blockPatterns.hasMatch(text);
  }

  bool _looksLikeFormattedInputRuleTrigger(String text) {
    return RegExp(
      r'^\s*(?:#{1,6}\s+|[-*+]\s+(?:\[[ xX]\]\s+)?|\d+\.\s+|>\s+|`{3,}[^`\n]*\s+|~{3,}[^~\n]*\s+|---|—-|___\s|\*\*\*\s)$',
    ).hasMatch(text);
  }

  _PlainTextDiff _plainTextDiff(String previous, String next) {
    var prefix = 0;
    final minLength =
        previous.length < next.length ? previous.length : next.length;
    while (prefix < minLength && previous[prefix] == next[prefix]) {
      prefix++;
    }

    var previousSuffix = previous.length;
    var nextSuffix = next.length;
    while (previousSuffix > prefix &&
        nextSuffix > prefix &&
        previous[previousSuffix - 1] == next[nextSuffix - 1]) {
      previousSuffix--;
      nextSuffix--;
    }

    return _PlainTextDiff(
      range: TextRange(start: prefix, end: previousSuffix),
      replacement: next.substring(prefix, nextSuffix),
    );
  }

  String? _linkPasteUrl(String replacement) {
    final value = replacement.trim();
    if (value.isEmpty || value.contains(RegExp(r'\s'))) return null;
    if (!_autoLinkTokenRegExp.hasMatch(value)) return null;

    final url = _normalizeAutoLinkUrl(value);
    return url.isEmpty ? null : url;
  }

  List<MarkdownInlineNode> _linkPasteInsertedNodes(
    String replacement,
    String url,
  ) {
    final leadingLength = replacement.length - replacement.trimLeft().length;
    final withoutLeading = replacement.substring(leadingLength);
    final trailingLength =
        withoutLeading.length - withoutLeading.trimRight().length;
    final label =
        withoutLeading.substring(0, withoutLeading.length - trailingLength);
    final trailingStart = withoutLeading.length - trailingLength;

    return [
      if (leadingLength > 0)
        MarkdownText(replacement.substring(0, leadingLength)),
      MarkdownLink(
        url: url,
        children: [MarkdownText(label)],
      ),
      if (trailingLength > 0)
        MarkdownText(withoutLeading.substring(trailingStart)),
    ];
  }

  _ImageInputRuleMatch? _blockImageInputRuleMatch(String text) {
    final parsed = MarkdownDocumentCodec(plugins: widget.plugins).parse(
      text.trim(),
    );
    if (parsed.blocks.length != 1) return null;

    final block = parsed.blocks.single;
    if (block is! MarkdownImageBlock || block.url.isEmpty) return null;
    return _ImageInputRuleMatch(
      url: block.url,
      alt: block.alt,
      title: block.title,
    );
  }

  _InlineInputRuleMatch? _inlineInputRuleMatch(
    String text,
    int cursor,
  ) {
    if (cursor < 0 || cursor > text.length) return null;

    final prefix = text.substring(0, cursor);
    final imageMatch = RegExp(
      r'''(?:^|\s)(!\[(.+|:?)\]\((\S+)(?:(?:\s+)["'](\S+)["'])?\))$''',
    ).firstMatch(prefix);
    if (imageMatch != null) {
      final markdown = imageMatch.group(1)!;
      final alt = imageMatch.group(2) ?? '';
      final url = imageMatch.group(3)!.trim();
      final title = imageMatch.group(4);
      if (url.isNotEmpty) {
        final image = _ImageInputRuleMatch(
          url: url,
          alt: alt,
          title: title,
        );
        return _InlineInputRuleMatch(
          range: TextRange(
            start: prefix.length - markdown.length,
            end: prefix.length,
          ),
          replacement: [
            MarkdownImage(url: image.url, alt: image.alt, title: image.title),
          ],
          plainText: alt,
          markdown: markdown,
          imageBlock: image,
        );
      }
    }

    final linkMatch =
        RegExp(r'\[([^\]\n]+)\]\(([^)\n]+)\)$').firstMatch(prefix);
    if (linkMatch != null) {
      final label = linkMatch.group(1)!;
      final url = _normalizeAllowedLinkUrl(linkMatch.group(2)!);
      if (label.isNotEmpty && url != null && url.isNotEmpty) {
        return _InlineInputRuleMatch(
          range: TextRange(start: linkMatch.start, end: linkMatch.end),
          replacement: [
            MarkdownLink(
              url: url,
              children: [MarkdownText(label)],
            ),
          ],
          plainText: label,
          markdown: prefix.substring(linkMatch.start, linkMatch.end),
        );
      }
    }

    final autoLinkMatch = _autoLinkInputRuleMatch(prefix);
    if (autoLinkMatch != null) return autoLinkMatch;

    final wikilinkMatch = RegExp(r'\[\[([^\]\n]+?)\]\]$').firstMatch(prefix);
    if (wikilinkMatch != null) {
      final target = wikilinkMatch.group(1)!;
      if (target.isNotEmpty) {
        final node = MarkdownWikilink(target: target);
        return _InlineInputRuleMatch(
          range: TextRange(start: wikilinkMatch.start, end: wikilinkMatch.end),
          replacement: [node],
          plainText: node.plainText,
          markdown: prefix.substring(wikilinkMatch.start, wikilinkMatch.end),
        );
      }
    }

    final codeMatch = RegExp(r'`([^`\n]+)`$').firstMatch(prefix);
    if (codeMatch != null && _validInlineRuleBoundary(prefix, codeMatch)) {
      final code = codeMatch.group(1)!;
      return _InlineInputRuleMatch(
        range: TextRange(start: codeMatch.start, end: codeMatch.end),
        replacement: [MarkdownInlineCode(code)],
        plainText: code,
        markdown: prefix.substring(codeMatch.start, codeMatch.end),
      );
    }

    final mathMatch = RegExp(r'\$([^$\n]+)\$$').firstMatch(prefix);
    if (mathMatch != null &&
        _validInlineRuleBoundary(prefix, mathMatch) &&
        !_isDollarDelimitedByDollar(prefix, mathMatch)) {
      final latex = mathMatch.group(1)!;
      return _InlineInputRuleMatch(
        range: TextRange(start: mathMatch.start, end: mathMatch.end),
        replacement: [MarkdownInlineMath(latex)],
        plainText: latex,
        markdown: prefix.substring(mathMatch.start, mathMatch.end),
      );
    }

    final strikeMatch = RegExp(r'~~([^~\n]+)~~$').firstMatch(prefix);
    if (strikeMatch != null && _validInlineRuleBoundary(prefix, strikeMatch)) {
      final text = strikeMatch.group(1)!;
      return _InlineInputRuleMatch(
        range: TextRange(start: strikeMatch.start, end: strikeMatch.end),
        replacement: [
          MarkdownStrikethrough([MarkdownText(text)]),
        ],
        plainText: text,
        markdown: prefix.substring(strikeMatch.start, strikeMatch.end),
      );
    }

    final strongMatch =
        RegExp(r'(?:\*\*([^*\n]+)\*\*|__([^_\n]+)__)$').firstMatch(prefix);
    if (strongMatch != null && _validInlineRuleBoundary(prefix, strongMatch)) {
      final text = strongMatch.group(1) ?? strongMatch.group(2)!;
      return _InlineInputRuleMatch(
        range: TextRange(start: strongMatch.start, end: strongMatch.end),
        replacement: [
          MarkdownStrong([MarkdownText(text)]),
        ],
        plainText: text,
        markdown: prefix.substring(strongMatch.start, strongMatch.end),
      );
    }

    final emphasisMatch =
        RegExp(r'(?:\*([^*\n]+)\*|_([^_\n]+)_)$').firstMatch(prefix);
    if (emphasisMatch != null &&
        _validInlineRuleBoundary(prefix, emphasisMatch)) {
      final text = emphasisMatch.group(1) ?? emphasisMatch.group(2)!;
      return _InlineInputRuleMatch(
        range: TextRange(start: emphasisMatch.start, end: emphasisMatch.end),
        replacement: [
          MarkdownEmphasis([MarkdownText(text)]),
        ],
        plainText: text,
        markdown: prefix.substring(emphasisMatch.start, emphasisMatch.end),
      );
    }

    return null;
  }

  _InlineInputRuleMatch? _autoLinkInputRuleMatch(String prefix) {
    final match =
        RegExp('($_autoLinkTokenPattern)([)\\]])?(\\s)\$').firstMatch(prefix);
    if (match == null || !_validInlineRuleBoundary(prefix, match)) {
      return null;
    }

    var label = match.group(1)!;
    final closingWrapper = match.group(2) ?? '';
    if (closingWrapper.isNotEmpty &&
        !_hasMatchingAutoLinkOpeningWrapper(prefix, match, closingWrapper)) {
      return null;
    }
    final trailingSpace = match.group(3)!;
    var trailingPunctuation = '';
    while (label.isNotEmpty && '.,;:!?'.contains(label[label.length - 1])) {
      trailingPunctuation = label[label.length - 1] + trailingPunctuation;
      label = label.substring(0, label.length - 1);
    }
    if (label.isEmpty) return null;

    final url = _normalizeAutoLinkUrl(label);
    if (url.isEmpty) return null;

    final replacement = <MarkdownInlineNode>[
      MarkdownLink(
        url: url,
        children: [MarkdownText(label)],
      ),
      if (trailingPunctuation.isNotEmpty) MarkdownText(trailingPunctuation),
      if (closingWrapper.isNotEmpty) MarkdownText(closingWrapper),
      MarkdownText(trailingSpace),
    ];

    return _InlineInputRuleMatch(
      range: TextRange(start: match.start, end: match.end),
      replacement: replacement,
      plainText: '$label$trailingPunctuation$closingWrapper$trailingSpace',
      markdown: replacement.map((node) => node.toMarkdown()).join(),
    );
  }

  bool _hasMatchingAutoLinkOpeningWrapper(
    String prefix,
    RegExpMatch match,
    String closingWrapper,
  ) {
    if (match.start == 0) return false;
    final expectedOpening = closingWrapper == ')' ? '(' : '[';
    return prefix[match.start - 1] == expectedOpening;
  }

  bool _validInlineRuleBoundary(String prefix, RegExpMatch match) {
    if (match.start == 0) return true;
    final previous = prefix[match.start - 1];
    return previous.trim().isEmpty || "([{>\"'".contains(previous);
  }

  bool _isDollarDelimitedByDollar(String prefix, RegExpMatch match) {
    final beforeOpening = match.start > 0 ? prefix[match.start - 1] : '';
    final beforeClosing = match.end > 1 ? prefix[match.end - 2] : '';
    return beforeOpening == r'$' || beforeClosing == r'$';
  }

  bool _applyFormattedInputRule(
    TextRange range,
    MarkdownBlock? block,
    String replacement,
  ) {
    if (block is! MarkdownParagraphBlock) return false;

    final localSelection = _formattedBlockController.selection;
    if (!localSelection.isValid || !localSelection.isCollapsed) {
      return false;
    }

    final result = _controller.documentEditor.applyInputRules(
      blockId: block.id,
      text: replacement,
      selectionOffset: localSelection.extentOffset,
    );
    if (result == null) return false;

    final activeBlock = _controller.document.blockById(result.activeBlockId);
    final container = _topLevelBlockContaining(result.activeBlockId);
    final usePlainText = _usesPlainTextEditing(activeBlock);

    _syncingFormattedBlock = true;
    if (usePlainText) {
      final selectionOffset = result.selectionOffset
          .clamp(0, activeBlock!.plainText.length)
          .toInt();
      _formattedBlockController.block = activeBlock;
      _formattedBlockController.value = TextEditingValue(
        text: activeBlock.plainText,
        selection: TextSelection.collapsed(offset: selectionOffset),
      );
    } else {
      _formattedBlockController.block = null;
      _formattedBlockController.value = const TextEditingValue();
    }
    _syncingFormattedBlock = false;

    if (usePlainText && activeBlock != null && container != null) {
      final blockSourceOffset = _blockSourceOffsetInContainer(
        container,
        activeBlock.id,
      );
      final sourceOffset = blockSourceOffset +
          _plainTextSourceOffsetFor(activeBlock, activeBlock.toMarkdown());
      final sourceSelection = TextSelection.collapsed(
        offset: range.start + sourceOffset + result.selectionOffset,
      );

      setState(() {
        _activeFormattedRange = TextRange(
          start: range.start,
          end: range.start + container.toMarkdown().length,
        );
        _activeFormattedBlockId = activeBlock.id;
        _activeFormattedContainerBlockId = container.id;
        _activeFormattedBlockSourceOffset = blockSourceOffset;
        _activeFormattedPlainText = true;
      });
      _controller.textController.selection =
          _clampSourceSelection(sourceSelection);
      return true;
    }

    setState(_clearActiveFormattedBlock);
    _controller.textController.selection = _clampSourceSelection(
      TextSelection.collapsed(offset: range.start),
    );
    return true;
  }

  TextRange _rangeForActiveContainer(int rangeStart, MarkdownBlock fallback) {
    final containerId = _activeFormattedContainerBlockId;
    final container = containerId == null
        ? null
        : _controller.document.blockById(containerId);
    final source = (container ?? fallback).toMarkdown();
    return TextRange(start: rangeStart, end: rangeStart + source.length);
  }

  MarkdownBlock? _topLevelBlockContaining(String blockId) {
    for (final block in _controller.document.blocks) {
      if (block.findBlock(blockId) != null) return block;
    }
    return null;
  }

  int _blockSourceOffsetInContainer(
    MarkdownBlock container,
    String blockId,
  ) {
    if (container.id == blockId) return 0;

    if (container is MarkdownListBlock) {
      return _blockSourceOffsetInList(container, blockId) ?? 0;
    }

    if (container is MarkdownBlockquoteBlock) {
      for (var index = 0; index < container.blocks.length; index++) {
        final block = container.blocks[index];
        final childOffset = _blockquoteChildSourceOffset(container, index);
        if (block.id == blockId) {
          return childOffset;
        }
        if (block.findBlock(blockId) != null) {
          return childOffset + _blockSourceOffsetInContainer(block, blockId);
        }
      }
    }

    return 0;
  }

  int? _blockSourceOffsetInList(
    MarkdownListBlock list,
    String blockId,
  ) {
    for (var itemIndex = 0; itemIndex < list.items.length; itemIndex++) {
      final item = list.items[itemIndex];
      for (var childIndex = 0; childIndex < item.blocks.length; childIndex++) {
        final child = item.blocks[childIndex];
        final childOffset = _listItemChildBlockSourceOffset(
          list,
          itemIndex,
          childIndex,
        );
        if (child.id == blockId) {
          return childOffset;
        }
        if (child.findBlock(blockId) != null) {
          return childOffset + _blockSourceOffsetInContainer(child, blockId);
        }
      }
    }
    return null;
  }

  TextSelection _clampSourceSelection(TextSelection selection) {
    final textLength = _controller.text.length;
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: textLength);
    }
    return TextSelection(
      baseOffset: selection.baseOffset.clamp(0, textLength),
      extentOffset: selection.extentOffset.clamp(0, textLength),
    );
  }

  bool _usesPlainTextEditing(MarkdownBlock? block) {
    return block is MarkdownParagraphBlock || block is MarkdownHeadingBlock;
  }

  TextSelection _localSelectionForSegment(
    _MarkdownBlockSegment segment,
    TextSelection? selection,
    int textLength, {
    required bool plainTextEditing,
  }) {
    if (selection == null) {
      return TextSelection.collapsed(offset: textLength);
    }

    if (!plainTextEditing) return selection;

    return _plainTextSelectionForSourceSelection(
      segment.block!,
      segment.source,
      selection,
      textLength: textLength,
    );
  }

  int _plainTextSourceOffsetFor(MarkdownBlock block, String source) {
    if (block is MarkdownHeadingBlock) {
      final match = RegExp(r'^(?: {0,3})#{1,6}[ \t]+').firstMatch(source);
      if (match != null) return match.end;
      if (block.plainText.isEmpty) return source.length;
    }
    return 0;
  }

  _FencedCodeBlock? _parseFencedCodeSegment(String source) {
    final lines = source.split('\n');
    if (lines.isEmpty) return null;

    final opening = lines.first.trimLeft();
    if (!opening.startsWith('```') && !opening.startsWith('~~~')) {
      return null;
    }

    final fence = opening.substring(0, 3);
    final info = opening.substring(3).trim();
    final language = info.isEmpty ? '' : info.split(RegExp(r'\s+')).first;
    final hasClosingFence =
        lines.length > 1 && lines.last.trimLeft().startsWith(fence);
    final codeLines =
        hasClosingFence ? lines.sublist(1, lines.length - 1) : lines.sublist(1);

    return _FencedCodeBlock(
      fence: fence,
      language: language,
      info: info.isEmpty ? null : info,
      code: codeLines.join('\n'),
    );
  }

  String? _parseBlockMathSegment(String source) {
    final lines = source.split('\n');
    if (lines.length < 3) return null;
    if (lines.first.trim() != r'$$' || lines.last.trim() != r'$$') {
      return null;
    }
    return lines.sublist(1, lines.length - 1).join('\n');
  }

  String _normalizeBlockMathSource(String source) {
    var normalized = source.trim();
    if (normalized.startsWith(r'$$') &&
        normalized.endsWith(r'$$') &&
        normalized.length >= 4) {
      normalized = normalized.substring(2, normalized.length - 2).trim();
    }
    return normalized;
  }

  void _updateCodeBlockLanguage(
    _MarkdownBlockSegment segment,
    _FencedCodeBlock codeBlock,
    String language,
  ) {
    final block = segment.block;
    if (block is MarkdownCodeBlock) {
      _controller.documentEditor.updateCodeBlockLanguage(block.id, language);
      setState(() {
        _clearActiveFormattedBlock();
        if (language != 'mermaid') {
          _mermaidSourceBlocks.remove(segment.range.start);
        }
      });
      return;
    }
    if (block is MarkdownMermaidBlock) {
      _controller.documentEditor.updateCodeBlockLanguage(block.id, language);
      setState(() {
        _clearActiveFormattedBlock();
        if (language != 'mermaid') {
          _mermaidSourceBlocks.remove(segment.range.start);
        }
      });
      return;
    }

    final source = segment.source;
    final firstLineEnd = source.indexOf('\n');
    final openingEnd = firstLineEnd == -1 ? source.length : firstLineEnd;
    final openingLine =
        language.isEmpty ? codeBlock.fence : '${codeBlock.fence}$language';
    final updatedSource = source.replaceRange(0, openingEnd, openingLine);

    _controller.replaceRange(
      segment.range,
      updatedSource,
      selection: TextSelection.collapsed(
        offset: segment.range.start + updatedSource.length,
      ),
    );
    setState(() {
      _clearActiveFormattedBlock();
      if (language != 'mermaid') {
        _mermaidSourceBlocks.remove(segment.range.start);
      }
    });
  }

  void _toggleMermaidSource(_MarkdownBlockSegment segment) {
    setState(() {
      if (!_mermaidSourceBlocks.add(segment.range.start)) {
        _mermaidSourceBlocks.remove(segment.range.start);
      }
    });
  }

  Future<void> _showBlockMathEditor(
    _MarkdownBlockSegment segment,
    String latex,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _BlockMathEditorDialog(initialLatex: latex),
    );

    if (result == null || !mounted) return;

    final trimmed = result.trim();
    if (trimmed.isEmpty) return;

    final block = segment.block;
    if (block is MarkdownBlockMathBlock) {
      _controller.documentEditor.updateBlockMath(block.id, trimmed);
      setState(_clearActiveFormattedBlock);
      return;
    }

    final replacement = '${r'$$'}\n$trimmed\n${r'$$'}';
    _controller.replaceRange(
      segment.range,
      replacement,
      selection: TextSelection.collapsed(
        offset: segment.range.start + replacement.length,
      ),
    );
    setState(_clearActiveFormattedBlock);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final suggestionResult = _handleSuggestionKeyEvent(event);
    if (suggestionResult == KeyEventResult.handled) {
      return suggestionResult;
    }

    final isModifierPressed = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (!isModifierPressed) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;

    if (!alt && key == LogicalKeyboardKey.keyZ) {
      if (shift) {
        _redo();
      } else {
        _undo();
      }
      return KeyEventResult.handled;
    }
    if (!shift && !alt && key == LogicalKeyboardKey.keyY) {
      _redo();
      return KeyEventResult.handled;
    }

    if (alt && !shift) {
      final headingCommand = _headingCommandForShortcutKey(key);
      if (headingCommand != null) {
        _applyCommand(headingCommand);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyC) {
        _applyCommand(MarkdownEditorCommand.codeBlock);
        return KeyEventResult.handled;
      }
    }

    if (shift && !alt) {
      if (key == LogicalKeyboardKey.keyB) {
        _applyCommand(MarkdownEditorCommand.blockquote);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyS || key == LogicalKeyboardKey.keyX) {
        _applyCommand(MarkdownEditorCommand.strikethrough);
        return KeyEventResult.handled;
      }
      if (_isShortcutDigitKey(key, 7)) {
        _applyCommand(MarkdownEditorCommand.orderedList);
        return KeyEventResult.handled;
      }
      if (_isShortcutDigitKey(key, 8)) {
        _applyCommand(MarkdownEditorCommand.unorderedList);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyP) {
        unawaited(_exportPdf());
        return KeyEventResult.handled;
      }
    }

    if (!shift && !alt && key == LogicalKeyboardKey.keyB) {
      _applyCommand(MarkdownEditorCommand.bold);
      return KeyEventResult.handled;
    }
    if (!shift && !alt && key == LogicalKeyboardKey.keyI) {
      _applyCommand(MarkdownEditorCommand.italic);
      return KeyEventResult.handled;
    }
    if (!shift && !alt && key == LogicalKeyboardKey.keyE) {
      _applyCommand(MarkdownEditorCommand.inlineCode);
      return KeyEventResult.handled;
    }
    if (!shift && !alt && key == LogicalKeyboardKey.keyK) {
      _applyCommand(MarkdownEditorCommand.link);
      return KeyEventResult.handled;
    }
    if (!shift && !alt && key == LogicalKeyboardKey.keyC) {
      if (_copyActiveFormattedSelectionAsMarkdown()) {
        return KeyEventResult.handled;
      }
    }
    if (!shift && !alt && key == LogicalKeyboardKey.keyF) {
      _openSearch();
      return KeyEventResult.handled;
    }
    if (shift && !alt && key == LogicalKeyboardKey.keyC) {
      _copyMenuController.open();
      return KeyEventResult.handled;
    }
    if (shift && !alt && key == LogicalKeyboardKey.enter) {
      _toggleFocusMode();
      return KeyEventResult.handled;
    }
    if (shift && !alt && key == LogicalKeyboardKey.keyM) {
      _toggleSourceMode();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _copyActiveFormattedSelectionAsMarkdown() {
    final markdown = _activeFormattedSelectionMarkdown();
    if (markdown == null) return false;

    unawaited(Clipboard.setData(ClipboardData(text: markdown)));
    return true;
  }

  String? _activeFormattedSelectionMarkdown() {
    if (_tableCellFocusNode.hasFocus) {
      final children = _tableCellController.inlineNodes;
      if (children == null ||
          _inlinePlainText(children) != _tableCellController.text) {
        return null;
      }
      return _inlineSelectionMarkdown(
        children,
        _tableCellController.selection,
      );
    }

    if (!_formattedBlockFocusNode.hasFocus) return null;

    final block = _formattedBlockController.block;
    final children = switch (block) {
      MarkdownParagraphBlock() => block.children,
      MarkdownHeadingBlock() => block.children,
      _ => null,
    };
    if (children == null ||
        _inlinePlainText(children) != _formattedBlockController.text) {
      return null;
    }

    return _inlineSelectionMarkdown(
      children,
      _formattedBlockController.selection,
    );
  }

  KeyEventResult _handleSearchKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_searchOpen) {
        setState(() => _searchOpen = false);
      }
      _focusNode.requestFocus();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _selectPreviousSearchMatch();
      } else {
        _selectNextSearchMatch();
      }
      _restoreSearchFocusAfterMatchNavigation();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _restoreSearchFocusAfterMatchNavigation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_searchOpen) return;
      _searchFocusNode.requestFocus();
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
    });
  }

  KeyEventResult _handleSuggestionKeyEvent(KeyDownEvent event) {
    if (!_shouldShowSlashCommands && !_shouldShowWikilinkSuggestions) {
      return KeyEventResult.ignored;
    }

    final isModifierPressed = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed;
    if (isModifierPressed) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      setState(() {
        _slashMatch = null;
        _wikilinkMatch = null;
        _slashSelectedIndex = 0;
        _wikilinkSelectedIndex = 0;
      });
      _requestActiveEditorFocus();
      return KeyEventResult.handled;
    }

    if (_shouldShowSlashCommands) {
      final commands = _visibleSlashCommands();
      if (commands.isEmpty) return KeyEventResult.ignored;
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _slashSelectedIndex = (_slashSelectedIndex + 1) % commands.length;
        });
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _slashSelectedIndex =
              (_slashSelectedIndex - 1 + commands.length) % commands.length;
        });
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        final index = _slashSelectedIndex.clamp(0, commands.length - 1).toInt();
        _runSlashCommand(commands[index]);
        return KeyEventResult.handled;
      }
    }

    if (_shouldShowWikilinkSuggestions) {
      final suggestions = _visibleWikilinkSuggestions();
      if (suggestions.isEmpty) {
        if (key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _wikilinkSelectedIndex =
              (_wikilinkSelectedIndex + 1) % suggestions.length;
        });
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _wikilinkSelectedIndex =
              (_wikilinkSelectedIndex - 1 + suggestions.length) %
                  suggestions.length;
        });
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        final index =
            _wikilinkSelectedIndex.clamp(0, suggestions.length - 1).toInt();
        _insertWikilinkSuggestion(suggestions[index]);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  MarkdownEditorCommand? _headingCommandForShortcutKey(LogicalKeyboardKey key) {
    if (_isShortcutDigitKey(key, 1)) return MarkdownEditorCommand.heading1;
    if (_isShortcutDigitKey(key, 2)) return MarkdownEditorCommand.heading2;
    if (_isShortcutDigitKey(key, 3)) return MarkdownEditorCommand.heading3;
    if (_isShortcutDigitKey(key, 4)) return MarkdownEditorCommand.heading4;
    if (_isShortcutDigitKey(key, 5)) return MarkdownEditorCommand.heading5;
    if (_isShortcutDigitKey(key, 6)) return MarkdownEditorCommand.heading6;
    return null;
  }

  bool _isShortcutDigitKey(LogicalKeyboardKey key, int digit) {
    return switch (digit) {
      1 =>
        key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1,
      2 =>
        key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2,
      3 =>
        key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3,
      4 =>
        key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4,
      5 =>
        key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5,
      6 =>
        key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6,
      7 =>
        key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7,
      8 =>
        key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8,
      _ => false,
    };
  }

  KeyEventResult _handleFormattedBlockKeyEvent(
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final suggestionResult = _handleSuggestionKeyEvent(event);
    if (suggestionResult == KeyEventResult.handled) {
      return suggestionResult;
    }

    final isModifierPressed = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (isModifierPressed) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      return _changeActiveListItemIndent(outdent: shift)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }

    if (shift ||
        (event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.backspace)) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      return _splitActiveFormattedBlock()
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }

    return _deleteBackwardFromActiveFormattedBlock()
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  void _setMode(MarkdownEditorMode mode) {
    if (_mode == mode) return;
    final previousMode = _mode;
    final transition = _modeTransitionAnchor(previousMode, mode);
    setState(() {
      _mode = mode;
      if (mode != MarkdownEditorMode.formatted) {
        _clearActiveFormattedBlock();
      }
      if (mode != MarkdownEditorMode.source) {
        _lastNonSourceMode = mode;
      }
    });
    widget.onModeChanged?.call(mode);
    _restoreModeTransition(mode, transition);
  }

  void _toggleSourceMode() {
    if (_mode == MarkdownEditorMode.source) {
      _setMode(_lastNonSourceMode);
    } else {
      _setMode(MarkdownEditorMode.source);
    }
  }

  _ModeTransitionAnchor? _modeTransitionAnchor(
    MarkdownEditorMode from,
    MarkdownEditorMode to,
  ) {
    if (to != MarkdownEditorMode.source && to != MarkdownEditorMode.formatted) {
      return null;
    }

    final currentSelection = _clampSourceSelection(_controller.selection);
    final cursor = currentSelection.extentOffset;
    final topBlockIndex = switch (from) {
      MarkdownEditorMode.formatted => _formattedTopBlockIndex() ??
          (_activeFormattedRange == null
              ? 0
              : _blockIndexForSourceOffset(_activeFormattedRange!.start)),
      MarkdownEditorMode.source ||
      MarkdownEditorMode.split =>
        _sourceTopBlockIndex() ?? _blockIndexForSourceOffset(cursor),
      MarkdownEditorMode.preview => _blockIndexForSourceOffset(cursor),
    };
    final sourceSelection = _sourceSelectionForModeTransition(
      from: from,
      to: to,
      currentSelection: currentSelection,
      topBlockIndex: topBlockIndex,
    );

    return _ModeTransitionAnchor(
      topBlockIndex: topBlockIndex,
      sourceSelection: sourceSelection,
    );
  }

  TextSelection _sourceSelectionForModeTransition({
    required MarkdownEditorMode from,
    required MarkdownEditorMode to,
    required TextSelection currentSelection,
    required int topBlockIndex,
  }) {
    if (from == MarkdownEditorMode.formatted &&
        to == MarkdownEditorMode.source &&
        _activeFormattedPlainText &&
        _activeFormattedRange != null) {
      final block = _formattedBlockController.block ?? _activeEditableBlock();
      final localSelection = _formattedBlockController.selection;
      if (block != null && localSelection.isValid) {
        return _sourceSelectionForPlainTextSelection(
          block,
          block.toMarkdown(),
          localSelection,
          sourceBaseOffset:
              _activeFormattedRange!.start + _activeFormattedBlockSourceOffset,
        );
      }
    }

    if (from != MarkdownEditorMode.formatted ||
        to != MarkdownEditorMode.source ||
        _activeFormattedRange != null) {
      return currentSelection;
    }

    final segments = _documentBlockSegments();
    if (segments.isEmpty) return currentSelection;
    final clampedIndex = topBlockIndex.clamp(0, segments.length - 1).toInt();
    return TextSelection.collapsed(offset: segments[clampedIndex].range.start);
  }

  void _restoreModeTransition(
    MarkdownEditorMode mode,
    _ModeTransitionAnchor? anchor,
  ) {
    if (anchor == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _mode != mode) return;

      if (mode == MarkdownEditorMode.source) {
        _controller.textController.selection = anchor.sourceSelection;
        _focusNode.requestFocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _mode == MarkdownEditorMode.source) {
            _scrollSourceBlockToTop(anchor.topBlockIndex);
          }
        });
        return;
      }

      if (mode == MarkdownEditorMode.formatted) {
        final target =
            _formattedActivationTargetForSelection(anchor.sourceSelection);
        if (target != null) {
          _activateFormattedSegment(
            target.segment,
            selection: target.segmentSelection,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _mode == MarkdownEditorMode.formatted) {
              _scrollFormattedBlockToTop(anchor.topBlockIndex);
            }
          });
        } else {
          _scrollFormattedBlockToTop(anchor.topBlockIndex);
        }
      }
    });
  }

  int _blockIndexForSourceOffset(int sourceOffset) {
    final segments = _documentBlockSegments();
    if (segments.isEmpty) return 0;

    final offset = sourceOffset.clamp(0, _controller.text.length).toInt();
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final nextSegment =
          index + 1 < segments.length ? segments[index + 1] : null;
      if (segment.range.isCollapsed &&
          nextSegment != null &&
          nextSegment.range.start == offset &&
          nextSegment.range.end > offset) {
        continue;
      }
      if (offset >= segment.range.start && offset <= segment.range.end) {
        return index;
      }
      if (offset < segment.range.start) {
        return index == 0 ? 0 : index - 1;
      }
    }
    return segments.length - 1;
  }

  int? _sourceTopBlockIndex() {
    if (!_sourceScrollController.hasClients) return null;
    final offset = _sourceOffsetForScrollOffset(_sourceScrollController.offset);
    return _blockIndexForSourceOffset(offset);
  }

  int? _formattedTopBlockIndex() {
    final viewportContext = _formattedViewportKey.currentContext;
    if (viewportContext == null) return null;

    final viewportBox = viewportContext.findRenderObject();
    if (viewportBox is! RenderBox || !viewportBox.hasSize) return null;

    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final segments = _documentBlockSegments();
    for (var index = 0; index < segments.length; index++) {
      final segmentContext =
          _formattedSegmentGlobalKey(segments[index]).currentContext;
      if (segmentContext == null) continue;

      final segmentBox = segmentContext.findRenderObject();
      if (segmentBox is! RenderBox || !segmentBox.hasSize) continue;

      final segmentTop = segmentBox.localToGlobal(Offset.zero).dy;
      final segmentBottom = segmentTop + segmentBox.size.height;
      if (segmentBottom >= viewportTop + 1) return index;
    }

    return null;
  }

  int _sourceOffsetForScrollOffset(double scrollOffset) {
    final lineHeight = _estimatedSourceLineHeight();
    final topLine = lineHeight <= 0 ? 0 : (scrollOffset / lineHeight).floor();
    final lines = _controller.text.split('\n');
    var offset = 0;
    for (var line = 0; line < topLine && line < lines.length; line++) {
      offset += lines[line].length + 1;
    }
    return offset.clamp(0, _controller.text.length).toInt();
  }

  double _sourceScrollOffsetForBlockIndex(int blockIndex) {
    final segments = _documentBlockSegments();
    if (segments.isEmpty) return 0;
    final clampedIndex = blockIndex.clamp(0, segments.length - 1).toInt();
    final sourceOffset = segments[clampedIndex].range.start;
    final linesBefore = _controller.text
            .substring(
                0, sourceOffset.clamp(0, _controller.text.length).toInt())
            .split('\n')
            .length -
        1;
    return linesBefore * _estimatedSourceLineHeight();
  }

  double _estimatedSourceLineHeight() {
    final style =
        _sourceTextStyle(context) ?? DefaultTextStyle.of(context).style;
    final fontSize = style.fontSize ?? 14;
    final height = style.height ?? 1.2;
    return fontSize * height;
  }

  void _scrollSourceBlockToTop(int blockIndex) {
    if (!_sourceScrollController.hasClients) return;
    final target = _sourceScrollOffsetForBlockIndex(blockIndex).clamp(
      _sourceScrollController.position.minScrollExtent,
      _sourceScrollController.position.maxScrollExtent,
    );
    _sourceScrollController.jumpTo(target.toDouble());
  }

  void _scrollFormattedBlockToTop(int blockIndex) {
    final segments = _documentBlockSegments();
    if (segments.isEmpty) return;
    final clampedIndex = blockIndex.clamp(0, segments.length - 1).toInt();
    final context =
        _formattedSegmentGlobalKey(segments[clampedIndex]).currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      alignment: 0,
      duration: Duration.zero,
    );
  }

  GlobalKey _formattedSegmentGlobalKey(_MarkdownBlockSegment segment) {
    final id =
        '${segment.range.start}:${segment.range.end}:${segment.block?.id ?? ''}';
    return _formattedSegmentKeys.putIfAbsent(id, GlobalKey.new);
  }

  _FormattedActivationTarget? _formattedActivationTargetForSelection(
    TextSelection sourceSelection,
  ) {
    final segments = _documentBlockSegments();
    if (segments.isEmpty) return null;

    final textLength = _controller.text.length;
    final extent = sourceSelection.extentOffset.clamp(0, textLength).toInt();
    final blockIndex = _blockIndexForSourceOffset(extent);
    final topSegment = segments[blockIndex];
    final nestedSegment =
        _nestedActivationSegmentAtSourceOffset(topSegment, extent);
    final targetSegment = nestedSegment ?? topSegment;
    final selectionBase =
        sourceSelection.baseOffset.clamp(0, textLength).toInt();
    final selectionExtent =
        sourceSelection.extentOffset.clamp(0, textLength).toInt();
    final localBase = (selectionBase -
            targetSegment.range.start -
            targetSegment.blockSourceOffset)
        .clamp(0, targetSegment.source.length)
        .toInt();
    final localExtent = (selectionExtent -
            targetSegment.range.start -
            targetSegment.blockSourceOffset)
        .clamp(0, targetSegment.source.length)
        .toInt();

    return _FormattedActivationTarget(
      segment: targetSegment,
      segmentSelection: TextSelection(
        baseOffset: localBase,
        extentOffset: localExtent,
      ),
    );
  }

  _MarkdownBlockSegment? _nestedActivationSegmentAtSourceOffset(
    _MarkdownBlockSegment segment,
    int sourceOffset,
  ) {
    final block = segment.block;
    if (block is MarkdownListBlock) {
      return _nestedListSegmentAtSourceOffset(segment, block, sourceOffset);
    }
    if (block is MarkdownBlockquoteBlock) {
      return _nestedBlockquoteSegmentAtSourceOffset(
        segment,
        block,
        sourceOffset,
      );
    }
    return null;
  }

  _MarkdownBlockSegment? _nestedListSegmentAtSourceOffset(
    _MarkdownBlockSegment segment,
    MarkdownListBlock list,
    int sourceOffset,
  ) {
    for (var itemIndex = 0; itemIndex < list.items.length; itemIndex++) {
      final item = list.items[itemIndex];
      for (var childIndex = 0; childIndex < item.blocks.length; childIndex++) {
        final child = item.blocks[childIndex];
        final blockSourceOffset = segment.blockSourceOffset +
            _listItemChildBlockSourceOffset(list, itemIndex, childIndex);
        final childStart = segment.range.start + blockSourceOffset;
        final childEnd = childStart + child.toMarkdown().length;
        if (sourceOffset < childStart || sourceOffset > childEnd) continue;

        final childSegment = _MarkdownBlockSegment(
          range: segment.range,
          source: child.toMarkdown(),
          block: child,
          containerBlockId: segment.containerBlockId ?? list.id,
          blockSourceOffset: blockSourceOffset,
        );
        return _nestedActivationSegmentAtSourceOffset(
              childSegment,
              sourceOffset,
            ) ??
            childSegment;
      }
    }
    return null;
  }

  _MarkdownBlockSegment? _nestedBlockquoteSegmentAtSourceOffset(
    _MarkdownBlockSegment segment,
    MarkdownBlockquoteBlock blockquote,
    int sourceOffset,
  ) {
    for (var index = 0; index < blockquote.blocks.length; index++) {
      final child = blockquote.blocks[index];
      final blockSourceOffset = segment.blockSourceOffset +
          _blockquoteChildSourceOffset(blockquote, index);
      final childStart = segment.range.start + blockSourceOffset;
      final childEnd = childStart + child.toMarkdown().length;
      if (sourceOffset < childStart || sourceOffset > childEnd) continue;

      final childSegment = _MarkdownBlockSegment(
        range: segment.range,
        source: child.toMarkdown(),
        block: child,
        containerBlockId: segment.containerBlockId ?? blockquote.id,
        blockSourceOffset: blockSourceOffset,
      );
      return _nestedActivationSegmentAtSourceOffset(
            childSegment,
            sourceOffset,
          ) ??
          childSegment;
    }
    return null;
  }

  void _clearActiveFormattedBlock() {
    _activeFormattedRange = null;
    _activeFormattedBlockId = null;
    _activeFormattedContainerBlockId = null;
    _activeFormattedBlockSourceOffset = 0;
    _activeFormattedPlainText = false;
    _clearStoredMarks();
  }

  void _toggleFocusMode() {
    setState(() => _focusMode = !_focusMode);
    widget.onFocusModeChanged?.call(_focusMode);
  }

  bool _splitActiveFormattedBlock() {
    if (!widget.enabled ||
        _mode != MarkdownEditorMode.formatted ||
        !_activeFormattedPlainText ||
        _activeFormattedBlockId == null) {
      return false;
    }

    final selection = _formattedBlockController.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      return false;
    }

    final result = _controller.documentEditor.splitBlockAt(
      blockId: _activeFormattedBlockId!,
      selectionOffset: selection.extentOffset,
    );
    if (result == null) return false;

    _syncActiveFormattedBlock(
      result.activeBlockId,
      selectionOffset: result.selectionOffset,
    );
    return true;
  }

  bool _deleteBackwardFromActiveFormattedBlock() {
    if (!widget.enabled ||
        _mode != MarkdownEditorMode.formatted ||
        !_activeFormattedPlainText ||
        _activeFormattedBlockId == null) {
      return false;
    }

    final selection = _formattedBlockController.selection;
    if (!selection.isValid ||
        !selection.isCollapsed ||
        selection.extentOffset != 0) {
      return false;
    }

    final result = _controller.documentEditor.deleteBackwardAt(
      blockId: _activeFormattedBlockId!,
      selectionOffset: selection.extentOffset,
    );
    if (result == null) return false;

    _syncActiveFormattedBlock(
      result.activeBlockId,
      selectionOffset: result.selectionOffset,
    );
    return true;
  }

  bool _changeActiveListItemIndent({required bool outdent}) {
    if (!widget.enabled ||
        _mode != MarkdownEditorMode.formatted ||
        !_activeFormattedPlainText ||
        _activeFormattedBlockId == null) {
      return false;
    }

    final selection = _formattedBlockController.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      return _activeFormattedBlockIsInList();
    }

    final result = outdent
        ? _controller.documentEditor.outdentListItemContainingBlock(
            blockId: _activeFormattedBlockId!,
            selectionOffset: selection.extentOffset,
          )
        : _controller.documentEditor.indentListItemContainingBlock(
            blockId: _activeFormattedBlockId!,
            selectionOffset: selection.extentOffset,
          );
    if (result == null) return _activeFormattedBlockIsInList();

    _syncActiveFormattedBlock(
      result.activeBlockId,
      selectionOffset: result.selectionOffset,
    );
    return true;
  }

  bool _activeFormattedBlockIsInList() {
    final blockId = _activeFormattedBlockId;
    if (blockId == null) return false;
    return _topLevelBlockContaining(blockId) is MarkdownListBlock;
  }

  void _undo() {
    _applyHistoryChange(_controller.undo);
  }

  void _redo() {
    _applyHistoryChange(_controller.redo);
  }

  void _applyHistoryChange(bool Function() change) {
    if (!widget.enabled) return;

    final activeTableCell = _activeTableCell;
    final tableSelection = _tableCellController.selection;
    final sourceHadFocus = _focusNode.hasFocus;

    if (!change()) return;
    _clearStoredMarks();

    if (_mode == MarkdownEditorMode.formatted) {
      if (activeTableCell != null &&
          _restoreTableCellAfterHistory(activeTableCell, tableSelection)) {
        return;
      }

      final target = _formattedActivationTargetForSelection(
        _controller.selection,
      );
      if (target != null) {
        if (_activeTableCell != null) {
          setState(() => _activeTableCell = null);
        }
        _activateFormattedSegment(
          target.segment,
          selection: target.segmentSelection,
        );
        return;
      }

      setState(() {
        _clearActiveFormattedBlock();
        _activeTableCell = null;
      });
      return;
    }

    if (_mode == MarkdownEditorMode.source || sourceHadFocus) {
      _focusNode.requestFocus();
    }
  }

  bool _restoreTableCellAfterHistory(
    _TableCellSelection cell,
    TextSelection selection,
  ) {
    final table = _controller.document.blockById(cell.tableId);
    if (table is! MarkdownTableBlock || !_tableCellExists(table, cell)) {
      setState(() => _activeTableCell = null);
      return false;
    }

    final children = _tableCellChildren(
      table,
      rowIndex: cell.rowIndex,
      columnIndex: cell.columnIndex,
      header: cell.header,
    );
    final plainText = _inlinePlainText(children);
    final offset = selection.isValid
        ? selection.extentOffset.clamp(0, plainText.length).toInt()
        : plainText.length;

    _syncingTableCell = true;
    _tableCellController
      ..inlineNodes = children
      ..value = TextEditingValue(
        text: plainText,
        selection: TextSelection.collapsed(offset: offset),
      );
    _syncingTableCell = false;

    setState(() {
      _clearActiveFormattedBlock();
      _activeTableCell = cell;
    });
    _tableCellFocusNode.requestFocus();
    return true;
  }

  bool _tableCellExists(MarkdownTableBlock table, _TableCellSelection cell) {
    if (cell.columnIndex < 0 || cell.columnIndex >= table.columnCount) {
      return false;
    }
    if (cell.header) return true;
    return cell.rowIndex >= 0 && cell.rowIndex < table.rows.length;
  }

  void _syncActiveFormattedBlock(
    String blockId, {
    required int selectionOffset,
    TextSelection? sourceSelection,
  }) {
    final activeBlock = _controller.document.blockById(blockId);
    final segments = _documentBlockSegments();
    _MarkdownBlockSegment? segment;
    for (final candidate in segments) {
      if (candidate.block?.findBlock(blockId) != null) {
        segment = candidate;
        break;
      }
    }

    final activeSegment = segment;
    if (!_usesPlainTextEditing(activeBlock) || activeSegment == null) {
      _syncingFormattedBlock = true;
      _formattedBlockController
        ..block = null
        ..value = const TextEditingValue();
      _syncingFormattedBlock = false;
      setState(_clearActiveFormattedBlock);
      return;
    }

    final clampedSelection =
        selectionOffset.clamp(0, activeBlock!.plainText.length).toInt();
    final localSelection = TextSelection.collapsed(offset: clampedSelection);
    final container = activeSegment.block;
    final blockSourceOffset = container == null
        ? 0
        : _blockSourceOffsetInContainer(container, activeBlock.id);

    _syncingFormattedBlock = true;
    _formattedBlockController
      ..block = activeBlock
      ..value = TextEditingValue(
        text: activeBlock.plainText,
        selection: localSelection,
      );
    _syncingFormattedBlock = false;

    setState(() {
      _activeFormattedRange = activeSegment.range;
      _activeFormattedBlockId = activeBlock.id;
      _activeFormattedContainerBlockId = container?.id ?? activeBlock.id;
      _activeFormattedBlockSourceOffset = blockSourceOffset;
      _activeFormattedPlainText = true;
    });
    _controller.textController.selection = sourceSelection == null
        ? _sourceSelectionForPlainTextSelection(
            activeBlock,
            activeBlock.toMarkdown(),
            localSelection,
            sourceBaseOffset: activeSegment.range.start + blockSourceOffset,
          )
        : _clampSourceSelection(sourceSelection);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _formattedBlockFocusNode.requestFocus();
      }
    });
  }

  void _applyCommand(MarkdownEditorCommand command) {
    if (!widget.enabled) return;
    if (command == MarkdownEditorCommand.image) {
      unawaited(_insertImageCommand());
      return;
    }
    if (_mode == MarkdownEditorMode.formatted &&
        _activeTableCell != null &&
        _isInlineCommand(command)) {
      if (command == MarkdownEditorCommand.link) {
        unawaited(_editActiveTableCellLink());
        return;
      }
      _applyActiveTableCellInlineCommand(command);
      return;
    }
    if (_mode == MarkdownEditorMode.formatted &&
        _activeFormattedPlainText &&
        _activeFormattedBlockId != null) {
      if (command == MarkdownEditorCommand.blockMath) {
        unawaited(_insertBlockMathFromActiveFormattedText());
        return;
      }
      if (_isInlineCommand(command)) {
        if (command == MarkdownEditorCommand.link) {
          unawaited(_editActiveInlineLink());
          return;
        }
        _applyActiveInlineCommand(command);
        return;
      }
      if (_isBlockCommand(command)) {
        _controller.applyBlockCommand(_activeFormattedBlockId!, command);
        setState(_clearActiveFormattedBlock);
        return;
      }
    }

    _controller.applyCommand(command);
    if (_mode == MarkdownEditorMode.formatted) {
      setState(_clearActiveFormattedBlock);
    } else {
      _focusNode.requestFocus();
    }
  }

  void _insertTable({
    required int rows,
    required int columns,
  }) {
    if (!widget.enabled) return;

    if (_mode == MarkdownEditorMode.formatted &&
        _activeFormattedPlainText &&
        _activeFormattedBlockId != null) {
      _controller.documentEditor.replaceBlockWithTable(
        _activeFormattedBlockId!,
        rows: rows,
        columns: columns,
      );
      setState(_clearActiveFormattedBlock);
      return;
    }

    _controller.insertTable(rows: rows, columns: columns);
    if (_mode == MarkdownEditorMode.formatted) {
      setState(_clearActiveFormattedBlock);
    } else {
      _focusNode.requestFocus();
    }
  }

  void _applyActiveInlineCommand(MarkdownEditorCommand command) {
    final selection = _formattedBlockController.selection;
    if (!selection.isValid || selection.isCollapsed) {
      if (selection.isValid &&
          selection.isCollapsed &&
          _toggleStoredMarkCommand(command)) {
        return;
      }
      _formattedBlockFocusNode.requestFocus();
      return;
    }
    _clearStoredMarks();

    final localRange = TextRange(
      start: selection.start,
      end: selection.end,
    );
    _controller.applyInlineCommand(
      _activeFormattedBlockId!,
      localRange,
      command,
    );

    final block = _controller.document.blockById(_activeFormattedBlockId!);
    if (_activeFormattedRange != null && block != null) {
      _activeFormattedRange = _rangeForActiveContainer(
        _activeFormattedRange!.start,
        block,
      );
    }
    _formattedBlockController
      ..block = block
      ..selection = selection;
    _formattedBlockFocusNode.requestFocus();
    setState(() {});
  }

  Future<void> _editActiveInlineLink() async {
    final blockId = _activeFormattedBlockId;
    if (blockId == null) return;

    final selection = _formattedBlockController.selection;
    if (!selection.isValid) {
      _formattedBlockFocusNode.requestFocus();
      return;
    }

    final range = TextRange(start: selection.start, end: selection.end);
    final existing = _controller.documentEditor.linkAtTextRange(
      blockId,
      range,
    );
    final result = await _showLinkEditorDialog(
      initialUrl: existing?.url ?? '',
      initialText: selection.isCollapsed && existing == null ? '' : null,
      canRemove: existing != null,
    );
    if (result == null || !mounted) {
      _formattedBlockFocusNode.requestFocus();
      return;
    }

    if (result.remove) {
      _controller.documentEditor.unlinkAtTextRange(blockId, range);
      _syncActiveFormattedBlock(blockId,
          selectionOffset: existing?.range.start ?? selection.start);
      return;
    }

    final url = _normalizeAllowedLinkUrl(result.url);
    if (url == null) {
      _formattedBlockFocusNode.requestFocus();
      return;
    }
    if (url.isEmpty) {
      if (existing != null) {
        _controller.documentEditor.unlinkAtTextRange(blockId, range);
        _syncActiveFormattedBlock(blockId,
            selectionOffset: existing.range.start);
        return;
      }
      _formattedBlockFocusNode.requestFocus();
      return;
    }

    if (result.text != null) {
      final text = result.text!.trim();
      if (text.isEmpty) {
        _formattedBlockFocusNode.requestFocus();
        return;
      }
      _controller.documentEditor.replaceTextRangeWithInlineNodes(
        blockId,
        range,
        [
          MarkdownLink(
            url: url,
            children: [MarkdownText(text)],
          ),
        ],
      );
      _syncActiveFormattedBlock(
        blockId,
        selectionOffset: range.start + text.length,
      );
      return;
    }

    if (existing != null) {
      _controller.documentEditor.updateLinkAtTextRange(
        blockId,
        range,
        url: url,
        title: existing.title,
      );
      _syncActiveFormattedBlock(
        blockId,
        selectionOffset: existing.range.end,
      );
      return;
    }

    if (selection.isCollapsed) {
      _formattedBlockFocusNode.requestFocus();
      return;
    }

    _controller.applyInlineCommand(
      blockId,
      range,
      MarkdownEditorCommand.link,
      argument: url,
    );
    _syncActiveFormattedBlock(blockId, selectionOffset: selection.end);
  }

  void _applyActiveTableCellInlineCommand(MarkdownEditorCommand command) {
    final cell = _activeTableCell;
    if (cell == null) return;

    final selection = _tableCellController.selection;
    if (!selection.isValid || selection.isCollapsed) {
      if (selection.isValid &&
          selection.isCollapsed &&
          _toggleStoredMarkCommand(command)) {
        return;
      }
      _tableCellFocusNode.requestFocus();
      return;
    }
    _clearStoredMarks();

    final applied = _controller.documentEditor.applyTableCellInlineCommand(
      blockId: cell.tableId,
      rowIndex: cell.rowIndex,
      columnIndex: cell.columnIndex,
      header: cell.header,
      range: TextRange(start: selection.start, end: selection.end),
      command: command,
    );
    if (!applied) {
      _tableCellFocusNode.requestFocus();
      return;
    }

    final table = _controller.document.blockById(cell.tableId);
    if (table is MarkdownTableBlock) {
      _tableCellController
        ..inlineNodes = _tableCellChildren(
          table,
          rowIndex: cell.rowIndex,
          columnIndex: cell.columnIndex,
          header: cell.header,
        )
        ..selection = selection;
    }
    _tableCellFocusNode.requestFocus();
    setState(() {});
  }

  Future<void> _editActiveTableCellLink() async {
    final cell = _activeTableCell;
    if (cell == null) return;

    final selection = _tableCellController.selection;
    if (!selection.isValid) {
      _tableCellFocusNode.requestFocus();
      return;
    }

    final range = TextRange(start: selection.start, end: selection.end);
    final existing = _controller.documentEditor.tableCellLinkAtRange(
      blockId: cell.tableId,
      rowIndex: cell.rowIndex,
      columnIndex: cell.columnIndex,
      header: cell.header,
      range: range,
    );
    final result = await _showLinkEditorDialog(
      initialUrl: existing?.url ?? '',
      initialText: selection.isCollapsed && existing == null ? '' : null,
      canRemove: existing != null,
    );
    if (result == null || !mounted) {
      _tableCellFocusNode.requestFocus();
      return;
    }

    if (result.remove) {
      _controller.documentEditor.unlinkTableCellAtRange(
        blockId: cell.tableId,
        rowIndex: cell.rowIndex,
        columnIndex: cell.columnIndex,
        header: cell.header,
        range: range,
      );
      _syncActiveTableCell(
          selectionOffset: existing?.range.start ?? selection.start);
      return;
    }

    final url = _normalizeAllowedLinkUrl(result.url);
    if (url == null) {
      _tableCellFocusNode.requestFocus();
      return;
    }
    if (url.isEmpty) {
      if (existing != null) {
        _controller.documentEditor.unlinkTableCellAtRange(
          blockId: cell.tableId,
          rowIndex: cell.rowIndex,
          columnIndex: cell.columnIndex,
          header: cell.header,
          range: range,
        );
        _syncActiveTableCell(selectionOffset: existing.range.start);
        return;
      }
      _tableCellFocusNode.requestFocus();
      return;
    }

    if (result.text != null) {
      final text = result.text!.trim();
      if (text.isEmpty) {
        _tableCellFocusNode.requestFocus();
        return;
      }
      _controller.documentEditor.replaceTableCellRangeWithInlineNodes(
        blockId: cell.tableId,
        rowIndex: cell.rowIndex,
        columnIndex: cell.columnIndex,
        header: cell.header,
        range: range,
        replacement: [
          MarkdownLink(
            url: url,
            children: [MarkdownText(text)],
          ),
        ],
      );
      _syncActiveTableCell(selectionOffset: range.start + text.length);
      return;
    }

    if (existing != null) {
      _controller.documentEditor.updateTableCellLinkAtRange(
        blockId: cell.tableId,
        rowIndex: cell.rowIndex,
        columnIndex: cell.columnIndex,
        header: cell.header,
        range: range,
        url: url,
        title: existing.title,
      );
      _syncActiveTableCell(selectionOffset: existing.range.end);
      return;
    }

    if (selection.isCollapsed) {
      _tableCellFocusNode.requestFocus();
      return;
    }

    final applied = _controller.documentEditor.applyTableCellInlineCommand(
      blockId: cell.tableId,
      rowIndex: cell.rowIndex,
      columnIndex: cell.columnIndex,
      header: cell.header,
      range: range,
      command: MarkdownEditorCommand.link,
      argument: url,
    );
    if (applied) {
      _syncActiveTableCell(selectionOffset: selection.end);
    } else {
      _tableCellFocusNode.requestFocus();
    }
  }

  Future<void> _insertImageCommand() async {
    final initialAlt = _selectedImageAltText();
    final result = await _pickImageForInsert(initialAlt);
    if (result == null || !mounted) {
      _requestActiveEditorFocus();
      return;
    }

    final url = result.url.trim();
    if (url.isEmpty) {
      _requestActiveEditorFocus();
      return;
    }

    final alt = result.alt.trim();
    final title = _normalizeOptionalMarkdownTitle(result.title);
    if (_mode == MarkdownEditorMode.formatted && _activeTableCell != null) {
      _insertImageInActiveTableCell(url: url, alt: alt, title: title);
      return;
    }

    if (_mode == MarkdownEditorMode.formatted &&
        _activeFormattedBlockId == null &&
        _controller.text.trim().isEmpty) {
      _insertFormattedImageIntoEmptyDocument(url: url, alt: alt, title: title);
      return;
    }

    if (_mode == MarkdownEditorMode.formatted &&
        _activeFormattedPlainText &&
        _activeFormattedBlockId != null) {
      _insertFormattedImageBlock(url: url, alt: alt, title: title);
      return;
    }

    _insertSourceImageBlock(url: url, alt: alt, title: title);
  }

  void _insertFormattedImageIntoEmptyDocument({
    required String url,
    required String alt,
    String? title,
  }) {
    final inserted =
        _controller.documentEditor.replaceEmptyDocumentWithImageBlock(
      url: url,
      alt: alt,
      title: title,
    );
    if (inserted == null) {
      _insertSourceImageBlock(url: url, alt: alt, title: title);
      return;
    }

    _syncActiveFormattedBlock(
      inserted.activeBlockId,
      selectionOffset: inserted.selectionOffset,
    );
  }

  Future<_ImageEditorResult?> _pickImageForInsert(String initialAlt) async {
    final pickImage = widget.onPickImage;
    if (pickImage == null) {
      return _showImageEditorDialog(
        initialUrl: '',
        initialAlt: initialAlt,
        initialTitle: '',
      );
    }

    final selection = await Future<MarkdownEditorImageSelection?>.value(
      pickImage(),
    );
    if (selection == null) return null;
    return _ImageEditorResult(
      url: selection.url,
      alt: selection.alt.trim().isEmpty ? initialAlt : selection.alt,
      title: selection.title,
    );
  }

  String _selectedImageAltText() {
    if (_mode == MarkdownEditorMode.formatted && _activeTableCell != null) {
      final selection = _tableCellController.selection;
      if (selection.isValid && !selection.isCollapsed) {
        return _tableCellController.text.substring(
          selection.start,
          selection.end,
        );
      }
      return '';
    }

    if (_mode == MarkdownEditorMode.formatted &&
        _activeFormattedPlainText &&
        _activeFormattedBlockId != null) {
      final selection = _formattedBlockController.selection;
      if (selection.isValid && !selection.isCollapsed) {
        return _formattedBlockController.text.substring(
          selection.start,
          selection.end,
        );
      }
    }
    return '';
  }

  void _insertImageInActiveTableCell({
    required String url,
    required String alt,
    String? title,
  }) {
    final cell = _activeTableCell;
    if (cell == null) return;

    final selection = _tableCellController.selection;
    final textLength = _tableCellController.text.length;
    final range = selection.isValid
        ? TextRange(start: selection.start, end: selection.end)
        : TextRange.collapsed(textLength);
    final imageAlt = alt.isEmpty && !range.isCollapsed
        ? _tableCellController.text.substring(range.start, range.end)
        : alt;

    final inserted =
        _controller.documentEditor.replaceTableCellRangeWithInlineNodes(
      blockId: cell.tableId,
      rowIndex: cell.rowIndex,
      columnIndex: cell.columnIndex,
      header: cell.header,
      range: range,
      replacement: [
        MarkdownImage(url: url, alt: imageAlt, title: title),
      ],
    );
    if (inserted) {
      _syncActiveTableCell(selectionOffset: range.start + imageAlt.length);
    } else {
      _tableCellFocusNode.requestFocus();
    }
  }

  void _insertFormattedImageBlock({
    required String url,
    required String alt,
    String? title,
  }) {
    final blockId = _activeFormattedBlockId;
    if (blockId == null) return;

    final block = _controller.document.blockById(blockId);
    if (block == null) return;

    final selection = _formattedBlockController.selection;
    final imageAlt = alt.isEmpty && selection.isValid && !selection.isCollapsed
        ? _formattedBlockController.text
            .substring(selection.start, selection.end)
        : alt;
    final textLength = block.plainText.length;
    final range = selection.isValid
        ? TextRange(start: selection.start, end: selection.end)
        : TextRange.collapsed(textLength);
    final container = _topLevelBlockContaining(block.id);
    final preserveEmptyListParagraph = container is MarkdownListBlock &&
        range.start == 0 &&
        range.end >= textLength;

    final inserted = _controller.documentEditor.replaceTextRangeWithImageBlock(
      block.id,
      range,
      url: url,
      alt: imageAlt,
      title: title,
      preserveEmptyBefore: preserveEmptyListParagraph,
    );
    if (inserted == null) {
      _formattedBlockFocusNode.requestFocus();
      return;
    }

    _syncActiveFormattedBlock(
      inserted.activeBlockId,
      selectionOffset: inserted.selectionOffset,
    );
  }

  void _insertSourceImageBlock({
    required String url,
    required String alt,
    String? title,
  }) {
    final markdown = MarkdownImageBlock(
      id: 'source-image',
      url: url,
      alt: alt,
      title: title,
    ).toMarkdown();
    _insertSeparatedMarkdown(markdown);
    _focusNode.requestFocus();
  }

  void _insertSeparatedMarkdown(String markdown) {
    final value = _controller.textController.value;
    final text = value.text;
    final selection = value.selection.isValid
        ? TextRange(
            start: value.selection.start,
            end: value.selection.end,
          )
        : TextRange.collapsed(text.length);
    final before = text.substring(0, selection.start);
    final after = text.substring(selection.end);
    final prefix = before.isEmpty || before.endsWith('\n\n')
        ? ''
        : before.endsWith('\n')
            ? '\n'
            : '\n\n';
    final suffix = after.isEmpty || after.startsWith('\n\n')
        ? ''
        : after.startsWith('\n')
            ? '\n'
            : '\n\n';
    final replacement = '$prefix$markdown$suffix';
    _controller.replaceRange(
      selection,
      replacement,
      selection: TextSelection.collapsed(
        offset: selection.start + prefix.length + markdown.length,
      ),
    );
  }

  Future<void> _insertBlockMathFromActiveFormattedText({
    TextRange? range,
  }) async {
    final blockId = _activeFormattedBlockId;
    if (blockId == null) return;

    final block = _controller.document.blockById(blockId);
    if (!_usesPlainTextEditing(block)) return;

    final text = _formattedBlockController.text;
    final selection = _formattedBlockController.selection;
    final effectiveRange = range ??
        (selection.isValid
            ? TextRange(start: selection.start, end: selection.end)
            : TextRange.collapsed(text.length));
    final start = effectiveRange.start.clamp(0, text.length).toInt();
    final end = effectiveRange.end.clamp(start, text.length).toInt();
    final normalizedRange = TextRange(start: start, end: end);
    final selectedText = normalizedRange.isCollapsed
        ? ''
        : text.substring(normalizedRange.start, normalizedRange.end);
    final initialLatex = _normalizeBlockMathSource(selectedText);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _BlockMathEditorDialog(
        initialLatex: initialLatex,
      ),
    );

    if (result == null || !mounted) {
      _requestActiveEditorFocus();
      return;
    }

    final latex = result.trim();
    if (latex.isEmpty) {
      _requestActiveEditorFocus();
      return;
    }

    final inserted = _controller.documentEditor.replaceTextRangeWithBlockMath(
      blockId,
      normalizedRange,
      latex: latex,
    );
    if (inserted == null) {
      _requestActiveEditorFocus();
      return;
    }

    final activeBlock = _controller.document.blockById(inserted.activeBlockId);
    if (_usesPlainTextEditing(activeBlock)) {
      _syncActiveFormattedBlock(
        inserted.activeBlockId,
        selectionOffset: inserted.selectionOffset,
      );
    } else {
      setState(_clearActiveFormattedBlock);
      _formattedBlockFocusNode.requestFocus();
    }
  }

  void _requestActiveEditorFocus() {
    if (_mode == MarkdownEditorMode.formatted && _activeTableCell != null) {
      _tableCellFocusNode.requestFocus();
    } else if (_mode == MarkdownEditorMode.formatted &&
        _activeFormattedPlainText) {
      _formattedBlockFocusNode.requestFocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  void _syncActiveTableCell({required int selectionOffset}) {
    final cell = _activeTableCell;
    if (cell == null) return;

    final table = _controller.document.blockById(cell.tableId);
    if (table is! MarkdownTableBlock) {
      setState(() => _activeTableCell = null);
      return;
    }

    final children = _tableCellChildren(
      table,
      rowIndex: cell.rowIndex,
      columnIndex: cell.columnIndex,
      header: cell.header,
    );
    final plainText = _inlinePlainText(children);
    final clampedSelection = selectionOffset.clamp(0, plainText.length).toInt();

    _syncingTableCell = true;
    _tableCellController
      ..inlineNodes = children
      ..value = TextEditingValue(
        text: plainText,
        selection: TextSelection.collapsed(offset: clampedSelection),
      );
    _syncingTableCell = false;
    _tableCellFocusNode.requestFocus();
    setState(() {});
  }

  Future<_LinkEditorResult?> _showLinkEditorDialog({
    required String initialUrl,
    required String? initialText,
    required bool canRemove,
  }) {
    return showDialog<_LinkEditorResult>(
      context: context,
      builder: (context) => _LinkEditorDialog(
        initialUrl: initialUrl,
        initialText: initialText,
        canRemove: canRemove,
      ),
    );
  }

  Future<_ImageEditorResult?> _showImageEditorDialog({
    required String initialUrl,
    required String initialAlt,
    required String initialTitle,
  }) {
    return showDialog<_ImageEditorResult>(
      context: context,
      builder: (context) => _ImageEditorDialog(
        initialUrl: initialUrl,
        initialAlt: initialAlt,
        initialTitle: initialTitle,
      ),
    );
  }

  Future<void> _showImageBlockEditor(MarkdownImageBlock block) async {
    final result = await _showImageEditorDialog(
      initialUrl: block.url,
      initialAlt: block.alt,
      initialTitle: block.title ?? '',
    );
    if (result == null || !mounted) return;

    final url = result.url.trim();
    if (url.isEmpty) return;

    _controller.documentEditor.updateImageBlock(
      block.id,
      url: url,
      alt: result.alt.trim(),
      title: _normalizeOptionalMarkdownTitle(result.title),
    );
    setState(_clearActiveFormattedBlock);
  }

  String? _normalizeOptionalMarkdownTitle(String? title) {
    final trimmed = title?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _normalizeLinkUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(trimmed)) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  String? _normalizeAllowedLinkUrl(String url) {
    final normalized = _normalizeLinkUrl(url);
    if (normalized.isEmpty) return '';
    return _isAllowedEditorLinkUrl(normalized) ? normalized : null;
  }

  bool _isAllowedEditorLinkUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return switch (uri.scheme.toLowerCase()) {
      'http' || 'https' || 'mailto' => true,
      _ => false,
    };
  }

  String _normalizeAutoLinkUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (_autoLinkEmailRegExp.hasMatch(trimmed)) {
      return 'mailto:$trimmed';
    }
    final normalized = _normalizeLinkUrl(trimmed);
    return _isAllowedEditorLinkUrl(normalized) ? normalized : '';
  }

  bool _isInlineCommand(MarkdownEditorCommand command) {
    return switch (command) {
      MarkdownEditorCommand.bold ||
      MarkdownEditorCommand.italic ||
      MarkdownEditorCommand.strikethrough ||
      MarkdownEditorCommand.inlineCode ||
      MarkdownEditorCommand.link ||
      MarkdownEditorCommand.image ||
      MarkdownEditorCommand.wikilink =>
        true,
      _ => false,
    };
  }

  bool _isBlockCommand(MarkdownEditorCommand command) {
    return switch (command) {
      MarkdownEditorCommand.paragraph ||
      MarkdownEditorCommand.heading1 ||
      MarkdownEditorCommand.heading2 ||
      MarkdownEditorCommand.heading3 ||
      MarkdownEditorCommand.heading4 ||
      MarkdownEditorCommand.heading5 ||
      MarkdownEditorCommand.heading6 ||
      MarkdownEditorCommand.unorderedList ||
      MarkdownEditorCommand.orderedList ||
      MarkdownEditorCommand.taskList ||
      MarkdownEditorCommand.blockquote ||
      MarkdownEditorCommand.codeBlock ||
      MarkdownEditorCommand.blockMath ||
      MarkdownEditorCommand.mermaidDiagram ||
      MarkdownEditorCommand.horizontalRule ||
      MarkdownEditorCommand.table =>
        true,
      _ => false,
    };
  }

  Future<void> _copyCodeBlock(
    _MarkdownBlockSegment segment,
    _FencedCodeBlock codeBlock,
  ) async {
    if (codeBlock.code.trim().isEmpty) return;

    try {
      await Clipboard.setData(ClipboardData(text: codeBlock.code));
    } catch (_) {
      return;
    }
    if (!mounted) return;

    _copiedCodeBlockResetTimer?.cancel();
    setState(() => _copiedCodeBlockStart = segment.range.start);
    _copiedCodeBlockResetTimer = Timer(_codeCopyFeedbackDuration, () {
      if (!mounted) return;
      setState(() {
        if (_copiedCodeBlockStart == segment.range.start) {
          _copiedCodeBlockStart = null;
        }
      });
    });
  }

  Future<void> _copyMarkdown() {
    return Clipboard.setData(ClipboardData(text: _controller.text));
  }

  Future<void> _copyPlainText() {
    return Clipboard.setData(
      ClipboardData(text: markdownToPlainText(_controller.text)),
    );
  }

  Future<void> _copyHtml() {
    return Clipboard.setData(
      ClipboardData(text: markdownToHtml(_controller.text)),
    );
  }

  Future<void> _exportPdf() async {
    final markdown = _controller.text;
    final html = markdownToHtml(markdown);
    final export = widget.onExportPdf;
    if (export == null) {
      await Clipboard.setData(ClipboardData(text: html));
      return;
    }
    await Future<void>.value(export(markdown, html));
  }

  Future<void> _exportMarkdown() async {
    final export = widget.onExportMarkdown;
    if (export == null) {
      await _copyMarkdown();
      return;
    }
    await Future<void>.value(export(_controller.text));
  }

  Future<void> _importMarkdown() async {
    if (!widget.enabled) return;

    final import = widget.onImportMarkdown;
    if (import == null) return;

    final markdown = await Future<String?>.value(import());
    if (!mounted ||
        !widget.enabled ||
        markdown == null ||
        markdown.trim().isEmpty) {
      return;
    }

    _controller.insertMarkdownBlock(markdown);
    setState(_clearActiveFormattedBlock);
    _focusNode.requestFocus();
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    _refreshSearchMatches();
  }

  void _refreshSearchMatches() {
    final query = _searchController.text;
    final matches = _findSearchMatches(query);
    var nextIndex = _currentSearchMatchIndex;
    if (query != _lastSearchQuery) {
      nextIndex = 0;
      _lastSearchQuery = query;
    }
    if (matches.isEmpty) {
      nextIndex = 0;
    } else if (nextIndex >= matches.length) {
      nextIndex = matches.length - 1;
    }

    if (mounted) {
      setState(() {
        _searchMatches = matches;
        _currentSearchMatchIndex = nextIndex;
      });
    } else {
      _searchMatches = matches;
      _currentSearchMatchIndex = nextIndex;
    }
  }

  void _selectNextSearchMatch() {
    if (_searchMatches.isEmpty) return;
    _goToSearchMatch((_currentSearchMatchIndex + 1) % _searchMatches.length);
  }

  void _selectPreviousSearchMatch() {
    if (_searchMatches.isEmpty) return;
    _goToSearchMatch(
      (_currentSearchMatchIndex - 1 + _searchMatches.length) %
          _searchMatches.length,
    );
  }

  void _goToSearchMatch(int index) {
    final match = _searchMatches[index];
    setState(() => _currentSearchMatchIndex = index);
    _controller.textController.selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );

    if (_mode == MarkdownEditorMode.formatted) {
      final target = _formattedActivationTargetForSelection(
        TextSelection(baseOffset: match.start, extentOffset: match.end),
      );
      if (target != null) {
        _activateFormattedSegment(
          target.segment,
          selection: target.segmentSelection,
        );
        return;
      }
    }
    _focusNode.requestFocus();
  }

  List<TextRange> _findSearchMatches(String query) {
    if (query.isEmpty) return const [];
    if (_mode == MarkdownEditorMode.source) {
      return _controller.findMatches(query);
    }

    final matches = <TextRange>[];
    for (final segment in _documentBlockSegments()) {
      final block = segment.block;
      if (block == null) {
        _addSourceSearchMatches(
          matches,
          segment.source,
          query,
          sourceBaseOffset: segment.range.start,
        );
      } else {
        _addSemanticBlockSearchMatches(
          matches,
          block,
          query,
          sourceBaseOffset: segment.range.start,
          source: segment.source,
        );
      }
      if (matches.length >= 500) break;
    }
    matches.sort((a, b) => a.start == b.start
        ? a.end.compareTo(b.end)
        : a.start.compareTo(b.start));
    return matches.length <= 500 ? matches : matches.take(500).toList();
  }

  void _addSemanticBlockSearchMatches(
    List<TextRange> matches,
    MarkdownBlock block,
    String query, {
    required int sourceBaseOffset,
    required String source,
  }) {
    if (matches.length >= 500) return;

    switch (block) {
      case MarkdownParagraphBlock() || MarkdownHeadingBlock():
        _addPlainTextSearchMatches(
          matches,
          block.plainText,
          query,
          sourceOffsetForPlainTextOffset: (offset) =>
              sourceBaseOffset +
              _sourceOffsetForPlainTextOffset(block, source, offset),
        );
      case MarkdownBlockquoteBlock():
        for (var index = 0; index < block.blocks.length; index++) {
          final child = block.blocks[index];
          _addSemanticBlockSearchMatches(
            matches,
            child,
            query,
            sourceBaseOffset:
                sourceBaseOffset + _blockquoteChildSourceOffset(block, index),
            source: child.toMarkdown(),
          );
          if (matches.length >= 500) return;
        }
      case MarkdownListBlock():
        for (var itemIndex = 0; itemIndex < block.items.length; itemIndex++) {
          final item = block.items[itemIndex];
          for (var childIndex = 0;
              childIndex < item.blocks.length;
              childIndex++) {
            final child = item.blocks[childIndex];
            _addSemanticBlockSearchMatches(
              matches,
              child,
              query,
              sourceBaseOffset: sourceBaseOffset +
                  _listItemChildBlockSourceOffset(
                    block,
                    itemIndex,
                    childIndex,
                  ),
              source: child.toMarkdown(),
            );
            if (matches.length >= 500) return;
          }
        }
      case MarkdownCodeBlock() ||
            MarkdownMermaidBlock() ||
            MarkdownBlockMathBlock():
        break;
      default:
        _addSourceBackedPlainTextSearchMatches(
          matches,
          block.plainText,
          source,
          query,
          sourceBaseOffset: sourceBaseOffset,
        );
    }
  }

  void _addPlainTextSearchMatches(
    List<TextRange> matches,
    String text,
    String query, {
    required int Function(int offset) sourceOffsetForPlainTextOffset,
  }) {
    if (text.isEmpty || query.isEmpty) return;

    final haystack = text.toLowerCase();
    final needle = query.toLowerCase();
    var index = haystack.indexOf(needle);
    while (index != -1 && matches.length < 500) {
      matches.add(
        TextRange(
          start: sourceOffsetForPlainTextOffset(index),
          end: sourceOffsetForPlainTextOffset(index + query.length),
        ),
      );
      index = haystack.indexOf(needle, index + needle.length);
    }
  }

  void _addSourceBackedPlainTextSearchMatches(
    List<TextRange> matches,
    String text,
    String source,
    String query, {
    required int sourceBaseOffset,
  }) {
    if (text.isEmpty || source.isEmpty || query.isEmpty) return;

    final plainHaystack = text.toLowerCase();
    final sourceHaystack = source.toLowerCase();
    final needle = query.toLowerCase();
    var plainIndex = plainHaystack.indexOf(needle);
    var sourceCursor = 0;
    while (plainIndex != -1 && matches.length < 500) {
      final matchedText = text.substring(plainIndex, plainIndex + query.length);
      final sourceIndex = sourceHaystack.indexOf(
        matchedText.toLowerCase(),
        sourceCursor,
      );
      if (sourceIndex == -1) break;

      matches.add(
        TextRange(
          start: sourceBaseOffset + sourceIndex,
          end: sourceBaseOffset + sourceIndex + matchedText.length,
        ),
      );
      sourceCursor = sourceIndex + matchedText.length;
      plainIndex = plainHaystack.indexOf(needle, plainIndex + needle.length);
    }
  }

  void _addSourceSearchMatches(
    List<TextRange> matches,
    String source,
    String query, {
    required int sourceBaseOffset,
  }) {
    if (source.isEmpty || query.isEmpty) return;

    final haystack = source.toLowerCase();
    final needle = query.toLowerCase();
    var index = haystack.indexOf(needle);
    while (index != -1 && matches.length < 500) {
      matches.add(
        TextRange(
          start: sourceBaseOffset + index,
          end: sourceBaseOffset + index + query.length,
        ),
      );
      index = haystack.indexOf(needle, index + needle.length);
    }
  }

  void _refreshInlineSuggestions() {
    if (_mode != MarkdownEditorMode.formatted) {
      _slashMatch = null;
      _wikilinkMatch = null;
      _slashSelectedIndex = 0;
      _wikilinkSelectedIndex = 0;
      return;
    }

    final selection = _controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      _slashMatch = null;
      _wikilinkMatch = null;
      return;
    }

    final cursor = selection.extentOffset;
    final text = _controller.text;
    final lineStart = cursor <= 0 ? 0 : text.lastIndexOf('\n', cursor - 1) + 1;
    final linePrefix = text.substring(lineStart, cursor);
    final richSuggestionsAllowed = _sourceRichSuggestionsAllowedAt(cursor);
    _slashSelectedIndex = 0;
    _wikilinkSelectedIndex = 0;

    if (widget.enableSlashCommands && richSuggestionsAllowed) {
      _slashMatch = _formattedSlashMatchForActiveTextBlock() ??
          _sourceSlashMatch(
            lineStart: lineStart,
            cursor: cursor,
            linePrefix: linePrefix,
          );
    } else {
      _slashMatch = null;
    }

    if (widget.enableWikilinks && richSuggestionsAllowed) {
      final open = text.lastIndexOf('[[', cursor);
      final close = text.lastIndexOf(']]', cursor);
      if (open != -1 && open > close && _wikilinkTriggerPrefixAllowed(open)) {
        final query = text.substring(open + 2, cursor);
        if (!query.contains('\n')) {
          _wikilinkMatch = _TriggerMatch(
            range: TextRange(start: open, end: cursor),
            query: query,
          );
          return;
        }
      }
    }
    _wikilinkMatch = null;
  }

  _TriggerMatch? _formattedSlashMatchForActiveTextBlock() {
    if (!_activeFormattedPlainText ||
        _activeFormattedBlockId == null ||
        _activeFormattedRange == null) {
      return null;
    }

    final block = _formattedBlockController.block ??
        _controller.document.blockById(_activeFormattedBlockId!);
    if (!_usesPlainTextEditing(block)) return null;

    final selection = _formattedBlockController.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;

    final visibleText = _formattedBlockController.text;
    final cursor = selection.extentOffset.clamp(0, visibleText.length).toInt();
    final lineStart =
        cursor <= 0 ? 0 : visibleText.lastIndexOf('\n', cursor - 1) + 1;
    final linePrefix = visibleText.substring(lineStart, cursor);
    if (!_isSlashCommandLinePrefix(linePrefix)) return null;

    final markdown = block!.toMarkdown();
    final sourceOffset = _activeFormattedRange!.start +
        _activeFormattedBlockSourceOffset +
        _plainTextSourceOffsetFor(block, markdown);
    final range = TextRange(
      start: sourceOffset + lineStart,
      end: sourceOffset + cursor,
    );
    if (range.start < 0 || range.end > _controller.text.length) return null;

    return _TriggerMatch(
      range: range,
      query: linePrefix.substring(1),
    );
  }

  _TriggerMatch? _sourceSlashMatch({
    required int lineStart,
    required int cursor,
    required String linePrefix,
  }) {
    if (!_isSlashCommandLinePrefix(linePrefix)) return null;
    return _TriggerMatch(
      range: TextRange(start: lineStart, end: cursor),
      query: linePrefix.substring(1),
    );
  }

  bool _isSlashCommandLinePrefix(String linePrefix) {
    return linePrefix.startsWith('/') &&
        !linePrefix.substring(1).contains(RegExp(r'\s'));
  }

  bool _wikilinkTriggerPrefixAllowed(int openOffset) {
    if (openOffset <= 0) return true;
    final text = _controller.text;
    final previous = text.codeUnitAt(openOffset - 1);
    return previous == 0x20 || previous == 0x0A || previous == 0x0D;
  }

  bool _sourceRichSuggestionsAllowedAt(int sourceOffset) {
    final text = _controller.text;
    if (text.isEmpty) return true;

    final offset = sourceOffset.clamp(0, text.length).toInt();
    for (final segment in _markdownBlockSegments(text)) {
      if (offset < segment.range.start || offset > segment.range.end) {
        continue;
      }

      final firstLine = segment.source.split('\n').first;
      final trimmed = firstLine.trimLeft();
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        return false;
      }
      if (segment.range.start == 0 && _isFrontmatterOpeningLine(firstLine)) {
        return false;
      }
      break;
    }

    return !_isInlineCodeSourceContext(offset);
  }

  bool _isInlineCodeSourceContext(int sourceOffset) {
    final text = _controller.text;
    if (text.isEmpty) return false;

    final offset = sourceOffset.clamp(0, text.length).toInt();
    final lineStart = offset <= 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
    final prefix = text.substring(lineStart, offset);
    var activeRunLength = 0;

    for (var index = 0; index < prefix.length; index++) {
      if (prefix.codeUnitAt(index) != 0x60 ||
          (index > 0 && prefix.codeUnitAt(index - 1) == 0x5C)) {
        continue;
      }

      var runEnd = index + 1;
      while (runEnd < prefix.length && prefix.codeUnitAt(runEnd) == 0x60) {
        runEnd++;
      }
      final runLength = runEnd - index;
      activeRunLength = activeRunLength == runLength
          ? 0
          : activeRunLength == 0
              ? runLength
              : activeRunLength;
      index = runEnd - 1;
    }

    return activeRunLength != 0;
  }

  bool get _shouldShowSlashCommands {
    return _mode == MarkdownEditorMode.formatted &&
        _slashMatch != null &&
        _filteredSlashCommands().isNotEmpty;
  }

  bool get _shouldShowWikilinkSuggestions {
    return _mode == MarkdownEditorMode.formatted && _wikilinkMatch != null;
  }

  List<_EditorCommandItem> _filteredSlashCommands() {
    final query = _slashMatch?.query.toLowerCase() ?? '';
    final commands = _allSlashCommands();
    if (query.isEmpty) return commands;
    return commands
        .where(
          (item) =>
              item.title.toLowerCase().contains(query) ||
              item.searchText.toLowerCase().contains(query),
        )
        .toList();
  }

  List<_EditorCommandItem> _visibleSlashCommands() {
    return _filteredSlashCommands();
  }

  List<_EditorCommandItem> _allSlashCommands() {
    return [
      ..._builtInSlashCommands,
      for (final command in widget.customSlashCommands)
        _EditorCommandItem.custom(command),
    ];
  }

  List<String> _filteredWikilinkSuggestions() {
    final query = _wikilinkMatch?.query.toLowerCase() ?? '';
    return widget.wikilinkSuggestions
        .where((title) => title.toLowerCase().contains(query))
        .toList();
  }

  List<String> _visibleWikilinkSuggestions() {
    return _filteredWikilinkSuggestions().take(10).toList(growable: false);
  }

  void _runSlashCommand(_EditorCommandItem item) {
    final match = _slashMatch;
    if (match == null) return;

    if (item.customCommand != null) {
      unawaited(_runCustomSlashCommand(item.customCommand!, match));
      return;
    }
    final command = item.command;
    if (command == null) return;

    if (_runFormattedSlashCommand(item, match)) {
      return;
    }

    if (command == MarkdownEditorCommand.wikilink) {
      _controller.replaceRange(
        match.range,
        '[[',
        selection: TextSelection.collapsed(offset: match.range.start + 2),
      );
      if (_mode == MarkdownEditorMode.formatted) {
        setState(_clearActiveFormattedBlock);
        _formattedBlockFocusNode.requestFocus();
      } else {
        _focusNode.requestFocus();
      }
      return;
    }

    _controller.runTransaction(() {
      _controller
        ..replaceRange(
          match.range,
          '',
          selection: TextSelection.collapsed(offset: match.range.start),
        )
        ..applyCommand(command);
    });
    if (_mode == MarkdownEditorMode.formatted) {
      setState(_clearActiveFormattedBlock);
    }
    _focusNode.requestFocus();
  }

  Future<void> _runCustomSlashCommand(
    MarkdownEditorSlashCommand command,
    _TriggerMatch match,
  ) async {
    final triggerText = '/${match.query}';
    if (!_currentRangeMatches(match.range, triggerText)) return;

    String? markdown;
    try {
      markdown = command.markdown ??
          await Future<String?>.value(command.onSelected?.call(match.query));
    } catch (_) {
      return;
    }
    if (!mounted ||
        !widget.enabled ||
        markdown == null ||
        markdown.trim().isEmpty ||
        !_currentRangeMatches(match.range, triggerText)) {
      return;
    }
    final markdownToInsert = markdown;

    if (_runFormattedCustomSlashCommand(markdownToInsert, match)) {
      return;
    }

    _controller.runTransaction(() {
      _controller
        ..replaceRange(
          match.range,
          '',
          selection: TextSelection.collapsed(offset: match.range.start),
        )
        ..insertMarkdownBlock(markdownToInsert);
    });
    if (_mode == MarkdownEditorMode.formatted) {
      setState(_clearActiveFormattedBlock);
    }
    _focusNode.requestFocus();
  }

  bool _runFormattedCustomSlashCommand(
    String markdown,
    _TriggerMatch match,
  ) {
    if (_mode != MarkdownEditorMode.formatted ||
        !_activeFormattedPlainText ||
        _activeFormattedBlockId == null ||
        _activeFormattedRange == null) {
      return false;
    }

    final block = _controller.document.blockById(_activeFormattedBlockId!);
    if (!_usesPlainTextEditing(block)) return false;

    final sourceOffset = _activeFormattedRange!.start +
        _activeFormattedBlockSourceOffset +
        _plainTextSourceOffsetFor(block!, block.toMarkdown());
    final localRange = TextRange(
      start: match.range.start - sourceOffset,
      end: match.range.end - sourceOffset,
    );
    if (localRange.start < 0 ||
        localRange.end < localRange.start ||
        localRange.end > block.plainText.length) {
      return false;
    }

    final parsed = MarkdownDocumentCodec(plugins: widget.plugins).parse(
      markdown,
    );
    if (parsed.blocks.isEmpty) return false;

    final previousContainer = _topLevelBlockContaining(block.id);
    final replacingTopLevel = previousContainer?.id == block.id;
    final inserted = _controller.documentEditor.replaceTextRangeWithBlocks(
      block.id,
      localRange,
      parsed.blocks,
    );
    if (inserted == null) return false;

    final nextContainer = previousContainer == null
        ? null
        : _controller.document.blockById(previousContainer.id);
    final selectionOffset = replacingTopLevel
        ? _activeFormattedRange!.start + inserted.selectionOffset
        : _activeFormattedRange!.start +
            (nextContainer?.toMarkdown().length ?? inserted.selectionOffset);

    setState(_clearActiveFormattedBlock);
    _controller.textController.selection = _clampSourceSelection(
      TextSelection.collapsed(offset: selectionOffset),
    );
    _formattedBlockFocusNode.requestFocus();
    return true;
  }

  bool _currentRangeMatches(TextRange range, String expected) {
    final text = _controller.text;
    return _rangeFitsText(range, text) &&
        text.substring(range.start, range.end) == expected;
  }

  bool _rangeFitsText(TextRange range, String text) {
    return range.start >= 0 &&
        range.end >= range.start &&
        range.end <= text.length;
  }

  bool _runFormattedSlashCommand(
    _EditorCommandItem item,
    _TriggerMatch match,
  ) {
    if (_mode != MarkdownEditorMode.formatted ||
        !_activeFormattedPlainText ||
        _activeFormattedBlockId == null ||
        _activeFormattedRange == null) {
      return false;
    }

    final block = _controller.document.blockById(_activeFormattedBlockId!);
    if (!_usesPlainTextEditing(block)) return false;

    final sourceOffset = _activeFormattedRange!.start +
        _activeFormattedBlockSourceOffset +
        _plainTextSourceOffsetFor(block!, block.toMarkdown());
    final localRange = TextRange(
      start: match.range.start - sourceOffset,
      end: match.range.end - sourceOffset,
    );
    if (localRange.start < 0 ||
        localRange.end < localRange.start ||
        localRange.end > block.plainText.length) {
      return false;
    }

    final command = item.command;
    if (command == null) return false;

    if (command == MarkdownEditorCommand.wikilink) {
      _controller.replaceRange(
        match.range,
        '[[',
        selection: TextSelection.collapsed(offset: match.range.start + 2),
      );
      _syncActiveFormattedBlock(
        block.id,
        selectionOffset: localRange.start + 2,
        sourceSelection: TextSelection.collapsed(
          offset: match.range.start + 2,
        ),
      );
      return true;
    }

    if (!_isBlockCommand(command)) return false;

    if (command == MarkdownEditorCommand.blockMath) {
      unawaited(_insertBlockMathFromActiveFormattedText(range: localRange));
      return true;
    }

    _controller.documentEditor.runTransaction(() {
      _controller.documentEditor.replaceTextRange(block.id, localRange, '');
      _controller.applyBlockCommand(block.id, command);
    });

    final preferredBlock = _preferredFormattedBlockAfterCommand(block.id);
    if (preferredBlock == null) {
      setState(_clearActiveFormattedBlock);
      _formattedBlockFocusNode.requestFocus();
    } else {
      _syncActiveFormattedBlock(preferredBlock.id, selectionOffset: 0);
    }
    return true;
  }

  MarkdownBlock? _preferredFormattedBlockAfterCommand(String blockId) {
    final block = _controller.document.blockById(blockId);
    if (_usesPlainTextEditing(block)) return block;
    if (block is MarkdownListBlock && block.items.isNotEmpty) {
      return _firstEditableListItemBlock(block.items.first);
    }
    if (block is MarkdownBlockquoteBlock && block.blocks.isNotEmpty) {
      final child = block.blocks.first;
      return _usesPlainTextEditing(child) ? child : null;
    }
    return null;
  }

  void _insertWikilinkSuggestion(String title) {
    final match = _wikilinkMatch;
    if (match == null) return;

    if (_insertWikilinkSuggestionInActiveFormattedBlock(title, match)) {
      return;
    }

    _controller.replaceRange(
      match.range,
      '[[$title]]',
      selection: TextSelection.collapsed(
        offset: match.range.start + title.length + 4,
      ),
    );
    if (_mode == MarkdownEditorMode.formatted) {
      _formattedBlockFocusNode.requestFocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  bool _insertWikilinkSuggestionInActiveFormattedBlock(
    String title,
    _TriggerMatch match,
  ) {
    if (_mode != MarkdownEditorMode.formatted ||
        !_activeFormattedPlainText ||
        _activeFormattedBlockId == null ||
        _activeFormattedRange == null) {
      return false;
    }

    final blockId = _activeFormattedBlockId!;
    final block = _controller.document.blockById(blockId);
    if (!_usesPlainTextEditing(block)) return false;

    final localRange = _activeFormattedWikilinkTriggerRange(match);
    if (localRange == null) return false;

    final applied = _controller.documentEditor.replaceTextRangeWithInlineNodes(
      blockId,
      localRange,
      [MarkdownWikilink(target: title)],
    );
    if (!applied) return false;

    _syncActiveFormattedBlock(
      blockId,
      selectionOffset: localRange.start + title.length,
    );
    _slashMatch = null;
    _wikilinkMatch = null;
    _slashSelectedIndex = 0;
    _wikilinkSelectedIndex = 0;
    return true;
  }

  TextRange? _activeFormattedWikilinkTriggerRange(_TriggerMatch match) {
    final selection = _formattedBlockController.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;

    final text = _formattedBlockController.text;
    final cursor = selection.extentOffset.clamp(0, text.length).toInt();
    final expectedTrigger = '[[${match.query}';
    final expectedStart = cursor - expectedTrigger.length;
    if (expectedStart >= 0 &&
        text.substring(expectedStart, cursor) == expectedTrigger) {
      return TextRange(start: expectedStart, end: cursor);
    }

    final open = text.lastIndexOf('[[', cursor);
    if (open == -1) return null;
    final query = text.substring(open + 2, cursor);
    if (query != match.query || query.contains('\n')) return null;
    return TextRange(start: open, end: cursor);
  }

  List<_MarkdownBlockSegment> _documentBlockSegments() {
    final text = _controller.text;
    if (text.trim().isEmpty) return const [];

    final sourceSegments = _markdownBlockSegments(text);
    final blocks = _controller.document.blocks;
    if (blocks.isEmpty) return sourceSegments;

    final segments = <_MarkdownBlockSegment>[];
    var sourceIndex = 0;
    var sourceSearchOffset = 0;
    var canonicalOffset = 0;
    for (final block in blocks) {
      final source = block.toMarkdown();
      final sourceIsEmpty = source.trim().isEmpty;
      final sourceRange = sourceIsEmpty
          ? TextRange.collapsed(canonicalOffset)
          : _sourceRangeForDocumentBlock(
              source,
              text,
              sourceSegments,
              sourceIndex,
              sourceSearchOffset,
              canonicalOffset,
            );

      segments.add(
        _MarkdownBlockSegment(
          range: sourceRange,
          source: source,
          block: block,
          containerBlockId: block.id,
        ),
      );
      if (!sourceIsEmpty) {
        canonicalOffset = sourceRange.end + 2;
        sourceSearchOffset = sourceRange.end;
        while (sourceIndex < sourceSegments.length &&
            sourceSegments[sourceIndex].range.end <= sourceRange.end) {
          sourceIndex++;
        }
      }
    }

    return segments;
  }

  TextRange _sourceRangeForDocumentBlock(
    String source,
    String text,
    List<_MarkdownBlockSegment> fallbackSegments,
    int fallbackIndex,
    int sourceSearchOffset,
    int canonicalOffset,
  ) {
    final sourceIndex = text.indexOf(source, sourceSearchOffset);
    if (sourceIndex != -1) {
      return TextRange(
        start: sourceIndex,
        end: sourceIndex + source.length,
      );
    }

    if (fallbackIndex < fallbackSegments.length) {
      return fallbackSegments[fallbackIndex].range;
    }

    return TextRange(
      start: canonicalOffset,
      end: canonicalOffset + source.length,
    );
  }

  List<_MarkdownBlockSegment> _markdownBlockSegments(String text) {
    if (text.trim().isEmpty) return const [];

    final lines = text.split('\n');
    final offsets = <int>[];
    var offset = 0;
    for (final line in lines) {
      offsets.add(offset);
      offset += line.length + 1;
    }

    final segments = <_MarkdownBlockSegment>[];
    var lineIndex = 0;
    while (lineIndex < lines.length) {
      while (lineIndex < lines.length && lines[lineIndex].trim().isEmpty) {
        lineIndex++;
      }
      if (lineIndex >= lines.length) break;

      final startLine = lineIndex;
      var endLine = lineIndex;
      final firstTrimmed = lines[lineIndex].trimLeft();

      if (startLine == 0 &&
          _isFrontmatterOpeningLine(lines[lineIndex]) &&
          _frontmatterClosingLine(lines, lineIndex + 1) != null) {
        endLine = _frontmatterClosingLine(lines, lineIndex + 1)!;
        lineIndex = endLine + 1;
      } else if (firstTrimmed.startsWith('```') ||
          firstTrimmed.startsWith('~~~')) {
        final fence = firstTrimmed.substring(0, 3);
        lineIndex++;
        while (lineIndex < lines.length) {
          endLine = lineIndex;
          if (lines[lineIndex].trimLeft().startsWith(fence)) {
            lineIndex++;
            break;
          }
          lineIndex++;
        }
      } else if (firstTrimmed == r'$$') {
        lineIndex++;
        while (lineIndex < lines.length) {
          endLine = lineIndex;
          if (lines[lineIndex].trim() == r'$$') {
            lineIndex++;
            break;
          }
          lineIndex++;
        }
      } else if (_isTableLine(lines[lineIndex])) {
        lineIndex++;
        while (lineIndex < lines.length && _isTableLine(lines[lineIndex])) {
          endLine = lineIndex;
          lineIndex++;
        }
      } else if (_isListOrQuoteLine(lines[lineIndex])) {
        lineIndex++;
        while (lineIndex < lines.length &&
            (lines[lineIndex].trim().isEmpty ||
                _isListOrQuoteLine(lines[lineIndex]))) {
          if (lines[lineIndex].trim().isNotEmpty) {
            endLine = lineIndex;
          }
          lineIndex++;
        }
      } else {
        lineIndex++;
        while (lineIndex < lines.length && lines[lineIndex].trim().isNotEmpty) {
          endLine = lineIndex;
          lineIndex++;
        }
      }

      final start = offsets[startLine];
      final end = offsets[endLine] + lines[endLine].length;
      segments.add(
        _MarkdownBlockSegment(
          range: TextRange(start: start, end: end),
          source: text.substring(start, end),
        ),
      );
    }

    return segments;
  }

  bool _isFrontmatterOpeningLine(String line) {
    return RegExp('^(?:\uFEFF)?---[ \\t]*\$').hasMatch(line);
  }

  bool _isFrontmatterClosingLine(String line) {
    return RegExp('^---[ \\t]*\$').hasMatch(line);
  }

  int? _frontmatterClosingLine(List<String> lines, int startLine) {
    for (var index = startLine; index < lines.length; index++) {
      if (_isFrontmatterClosingLine(lines[index])) {
        return index;
      }
    }
    return null;
  }

  bool _isTableLine(String line) {
    final trimmed = line.trim();
    return trimmed.contains('|') && trimmed.length > 1;
  }

  bool _isListOrQuoteLine(String line) {
    final trimmed = line.trimLeft();
    return trimmed.startsWith('>') ||
        RegExp(r'^[-*+]\s+').hasMatch(trimmed) ||
        RegExp(r'^\d+[.)]\s+').hasMatch(trimmed);
  }

  ParserPluginRegistry? _previewPlugins() {
    final registry = widget.plugins?.copy() ?? ParserPluginRegistry();
    if (registry.getBlockPlugin('mermaid') == null) {
      registry.register(const MermaidPlugin());
    }

    if (!widget.enableWikilinks) return registry;

    if (registry.getInlinePlugin('wikilink') == null) {
      registry.register(const WikilinkPlugin());
    }
    return registry;
  }

  BuilderRegistry? _previewBuilderRegistry() {
    final searchQuery = _searchOpen ? _searchController.text : '';
    final needsSearchHighlight = searchQuery.isNotEmpty;
    final needsWikilinks = widget.enableWikilinks;

    final registry = BuilderRegistry()
      ..register('mermaid', const MermaidBuilder());

    if (needsWikilinks) {
      registry.register(
        'wikilink',
        WikilinkBuilder(onTapWikilink: widget.onTapWikilink),
      );
    }

    if (widget.builderRegistry != null) {
      for (final entry in widget.builderRegistry!.entries) {
        registry.register(entry.key, entry.value);
      }
    }

    if (needsSearchHighlight) {
      registry.register(
        'text',
        _SearchHighlightTextBuilder(
          query: searchQuery,
          backgroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.22),
        ),
      );
    }

    return registry;
  }
}

class _FrontmatterEditor extends StatefulWidget {
  const _FrontmatterEditor({
    required this.fieldKey,
    required this.content,
    required this.enabled,
    required this.textStyle,
    required this.onChanged,
    super.key,
  });

  final ValueKey<String> fieldKey;
  final String content;
  final bool enabled;
  final TextStyle? textStyle;
  final ValueChanged<String> onChanged;

  @override
  State<_FrontmatterEditor> createState() => _FrontmatterEditorState();
}

class _FrontmatterEditorState extends State<_FrontmatterEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _FrontmatterEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content == _controller.text) return;

    final selection = _controller.selection;
    _controller.value = TextEditingValue(
      text: widget.content,
      selection: selection.isValid
          ? TextSelection.collapsed(
              offset: selection.baseOffset.clamp(0, widget.content.length),
            )
          : TextSelection.collapsed(offset: widget.content.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: widget.fieldKey,
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      minLines: 3,
      maxLines: null,
      style: widget.textStyle,
      keyboardType: TextInputType.multiline,
      autocorrect: false,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _SearchHighlightTextBuilder extends MarkdownWidgetBuilder {
  const _SearchHighlightTextBuilder({
    required this.query,
    required this.backgroundColor,
  });

  final String query;
  final Color backgroundColor;

  @override
  bool canBuild(MarkdownNode node) => node is TextNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final text = (node as TextNode).content;
    if (query.isEmpty || text.isEmpty) {
      return Text(text);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var cursor = 0;
    var matchStart = lowerText.indexOf(lowerQuery);

    while (matchStart != -1) {
      if (matchStart > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, matchStart)));
      }

      final matchEnd = matchStart + query.length;
      spans.add(
        TextSpan(
          text: text.substring(matchStart, matchEnd),
          style: TextStyle(backgroundColor: backgroundColor),
        ),
      );

      cursor = matchEnd;
      matchStart = lowerText.indexOf(lowerQuery, cursor);
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

class _FormattedInlineTextController extends TextEditingController {
  List<MarkdownInlineNode>? inlineNodes;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final nodes = inlineNodes;
    if (nodes == null || _plainText(nodes) != text) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    return TextSpan(
      style: baseStyle,
      children: _buildInlineSpans(context, nodes, baseStyle),
    );
  }

  List<TextSpan> _buildInlineSpans(
    BuildContext context,
    List<MarkdownInlineNode> nodes,
    TextStyle style,
  ) {
    return [
      for (final node in nodes) ..._spansForNode(context, node, style),
    ];
  }

  List<TextSpan> _spansForNode(
    BuildContext context,
    MarkdownInlineNode node,
    TextStyle style,
  ) {
    switch (node) {
      case MarkdownText():
        return [TextSpan(text: node.text, style: style)];
      case MarkdownStrong():
        return _buildInlineSpans(
          context,
          node.children,
          style.copyWith(fontWeight: FontWeight.w700),
        );
      case MarkdownEmphasis():
        return _buildInlineSpans(
          context,
          node.children,
          style.copyWith(fontStyle: FontStyle.italic),
        );
      case MarkdownStrikethrough():
        return _buildInlineSpans(
          context,
          node.children,
          style.copyWith(decoration: _mergeLineThrough(style.decoration)),
        );
      case MarkdownInlineCode():
        return [
          TextSpan(
            text: node.code,
            style: style.copyWith(
              fontFamily: 'monospace',
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
            ),
          ),
        ];
      case MarkdownHardBreak():
        return [TextSpan(text: '\n', style: style)];
      case MarkdownInlineMath():
        return [
          TextSpan(
            text: node.latex,
            style: style.copyWith(
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ];
      case MarkdownLink():
        return _buildInlineSpans(
          context,
          node.children,
          style.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: _mergeUnderline(style.decoration),
          ),
        );
      case MarkdownImage():
        return [
          TextSpan(
            text: node.alt,
            style: style.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ];
      case MarkdownWikilink():
        return [
          TextSpan(
            text: node.label,
            style: style.copyWith(
              color: Theme.of(context).colorScheme.primary,
              decoration: _mergeUnderline(style.decoration),
            ),
          ),
        ];
      default:
        return [TextSpan(text: node.plainText, style: style)];
    }
  }

  TextDecoration _mergeUnderline(TextDecoration? decoration) {
    return TextDecoration.combine([
      if (decoration != null) decoration,
      TextDecoration.underline,
    ]);
  }

  TextDecoration _mergeLineThrough(TextDecoration? decoration) {
    return TextDecoration.combine([
      if (decoration != null) decoration,
      TextDecoration.lineThrough,
    ]);
  }

  String _plainText(List<MarkdownInlineNode> nodes) {
    return nodes.map((node) => node.plainText).join();
  }
}

const _autoLinkEmailPattern =
    r"[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}";
const _autoLinkTokenPattern =
    r"(?:https?://|mailto:|www\.)[^\s<>()\[\]{}]+|[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}|(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}(?:/[^\s<>()\[\]{}]*)?";
final _autoLinkEmailRegExp = RegExp('^$_autoLinkEmailPattern\$');
final _autoLinkTokenRegExp = RegExp('^$_autoLinkTokenPattern\$');

class _PlainTextDiff {
  const _PlainTextDiff({
    required this.range,
    required this.replacement,
  });

  final TextRange range;
  final String replacement;
}

class _ImageInputRuleMatch {
  const _ImageInputRuleMatch({
    required this.url,
    required this.alt,
    required this.title,
  });

  final String url;
  final String alt;
  final String? title;
}

class _FormattedBlockTextController extends _FormattedInlineTextController {
  MarkdownBlock? _block;

  MarkdownBlock? get block => _block;

  set block(MarkdownBlock? value) {
    _block = value;
    inlineNodes = switch (value) {
      MarkdownParagraphBlock() => value.children,
      MarkdownHeadingBlock() => value.children,
      _ => null,
    };
  }
}

class _HeadingMenuItem extends StatelessWidget {
  const _HeadingMenuItem({
    required this.label,
    required this.title,
  });

  final String label;
  final String title;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          child: Text(label, style: labelStyle),
        ),
        const SizedBox(width: 8),
        Text(title),
      ],
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({
    required this.label,
    required this.maxHeight,
    required this.children,
  });

  final String label;
  final double maxHeight;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 3,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _TriggerMatch {
  const _TriggerMatch({
    required this.range,
    required this.query,
  });

  final TextRange range;
  final String query;
}

class _InlineInputRuleMatch {
  const _InlineInputRuleMatch({
    required this.range,
    required this.replacement,
    required this.plainText,
    required this.markdown,
    this.imageBlock,
  });

  final TextRange range;
  final List<MarkdownInlineNode> replacement;
  final String plainText;
  final String markdown;
  final _ImageInputRuleMatch? imageBlock;
}

class _ModeTransitionAnchor {
  const _ModeTransitionAnchor({
    required this.topBlockIndex,
    required this.sourceSelection,
  });

  final int topBlockIndex;
  final TextSelection sourceSelection;
}

class _FormattedActivationTarget {
  const _FormattedActivationTarget({
    required this.segment,
    required this.segmentSelection,
  });

  final _MarkdownBlockSegment segment;
  final TextSelection segmentSelection;
}

class _TableCellSelection {
  const _TableCellSelection({
    required this.tableId,
    required this.rowIndex,
    required this.columnIndex,
    required this.header,
  });

  final String tableId;
  final int rowIndex;
  final int columnIndex;
  final bool header;

  bool matches(
    String otherTableId, {
    required int rowIndex,
    required int columnIndex,
    required bool header,
  }) {
    return tableId == otherTableId &&
        this.rowIndex == rowIndex &&
        this.columnIndex == columnIndex &&
        this.header == header;
  }

  _TableCellSelection copyWith({
    String? tableId,
    int? rowIndex,
    int? columnIndex,
    bool? header,
  }) {
    return _TableCellSelection(
      tableId: tableId ?? this.tableId,
      rowIndex: rowIndex ?? this.rowIndex,
      columnIndex: columnIndex ?? this.columnIndex,
      header: header ?? this.header,
    );
  }
}

class _StoredMarkTarget {
  const _StoredMarkTarget.formattedBlock(this.blockId)
      : tableId = null,
        rowIndex = null,
        columnIndex = null,
        header = null;

  const _StoredMarkTarget.tableCell({
    required this.tableId,
    required this.rowIndex,
    required this.columnIndex,
    required this.header,
  }) : blockId = null;

  final String? blockId;
  final String? tableId;
  final int? rowIndex;
  final int? columnIndex;
  final bool? header;

  @override
  bool operator ==(Object other) {
    return other is _StoredMarkTarget &&
        other.blockId == blockId &&
        other.tableId == tableId &&
        other.rowIndex == rowIndex &&
        other.columnIndex == columnIndex &&
        other.header == header;
  }

  @override
  int get hashCode => Object.hash(
        blockId,
        tableId,
        rowIndex,
        columnIndex,
        header,
      );
}

class _MarkdownBlockSegment {
  const _MarkdownBlockSegment({
    required this.range,
    required this.source,
    this.block,
    this.containerBlockId,
    this.blockSourceOffset = 0,
  });

  final TextRange range;
  final String source;
  final MarkdownBlock? block;
  final String? containerBlockId;
  final int blockSourceOffset;
}

class _FencedCodeBlock {
  const _FencedCodeBlock({
    required this.fence,
    required this.language,
    required this.code,
    this.info,
  });

  final String fence;
  final String language;
  final String code;
  final String? info;
}

class _TableDimensions {
  const _TableDimensions({
    required this.rows,
    required this.columns,
  });

  final int rows;
  final int columns;
}

enum _TableContextAction {
  addColumnBefore,
  addColumnAfter,
  deleteColumn,
  alignColumnDefault,
  alignColumnLeft,
  alignColumnCenter,
  alignColumnRight,
  addRowAbove,
  addRowBelow,
  deleteRow,
  toggleHeaderRow,
  toggleHeaderColumn,
  deleteTable,
}

class _TablePickerMenuEntry extends PopupMenuEntry<_TableDimensions> {
  const _TablePickerMenuEntry();

  static const double _cellSize = 22;
  static const double _gap = 4;
  static const double _padding = 12;

  @override
  double get height => (_cellSize * 5) + (_gap * 4) + (_padding * 2) + 30;

  @override
  bool represents(_TableDimensions? value) => false;

  @override
  State<_TablePickerMenuEntry> createState() => _TablePickerMenuEntryState();
}

class _TablePickerMenuEntryState extends State<_TablePickerMenuEntry> {
  _TableDimensions _hovered = const _TableDimensions(rows: 3, columns: 3);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('smooth_markdown_editor_table_picker'),
      padding: const EdgeInsets.all(_TablePickerMenuEntry._padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 1; row <= 5; row++) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var column = 1; column <= 5; column++) ...[
                  _TablePickerCell(
                    row: row,
                    column: column,
                    highlighted:
                        row <= _hovered.rows && column <= _hovered.columns,
                    onHover: () => setState(
                      () => _hovered = _TableDimensions(
                        rows: row,
                        columns: column,
                      ),
                    ),
                    onSelect: () => Navigator.of(context).pop(
                      _TableDimensions(rows: row, columns: column),
                    ),
                  ),
                  if (column < 5)
                    const SizedBox(width: _TablePickerMenuEntry._gap),
                ],
              ],
            ),
            if (row < 5) const SizedBox(height: _TablePickerMenuEntry._gap),
          ],
          const SizedBox(height: 8),
          Text(
            '${_hovered.rows} x ${_hovered.columns} table',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TablePickerCell extends StatelessWidget {
  const _TablePickerCell({
    required this.row,
    required this.column,
    required this.highlighted,
    required this.onHover,
    required this.onSelect,
  });

  final int row;
  final int column;
  final bool highlighted;
  final VoidCallback onHover;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlighted
        ? theme.colorScheme.primary.withOpacity(0.18)
        : theme.colorScheme.surface;
    final borderColor = highlighted
        ? theme.colorScheme.primary.withOpacity(0.65)
        : theme.dividerColor;

    return MouseRegion(
      onEnter: (_) => onHover(),
      child: InkWell(
        key: ValueKey(
          'smooth_markdown_editor_table_picker_cell_${row}_$column',
        ),
        onTap: onSelect,
        borderRadius: BorderRadius.circular(3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: _TablePickerMenuEntry._cellSize,
          height: _TablePickerMenuEntry._cellSize,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _LinkEditorResult {
  const _LinkEditorResult({
    required this.url,
    this.text,
    this.remove = false,
  });

  final String url;
  final String? text;
  final bool remove;
}

class _LinkEditorDialog extends StatefulWidget {
  const _LinkEditorDialog({
    required this.initialUrl,
    required this.initialText,
    required this.canRemove,
  });

  final String initialUrl;
  final String? initialText;
  final bool canRemove;

  @override
  State<_LinkEditorDialog> createState() => _LinkEditorDialogState();
}

class _LinkEditorDialogState extends State<_LinkEditorDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController? _textController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _textController = widget.initialText == null
        ? null
        : TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _textController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }

        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          _submit();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        title: const Text('Edit Link'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_textController != null) ...[
                TextField(
                  key: const ValueKey('smooth_markdown_editor_link_text_input'),
                  controller: _textController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Link text',
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                key: const ValueKey('smooth_markdown_editor_link_url_input'),
                controller: _urlController,
                autofocus: _textController == null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'URL',
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        actions: [
          if (widget.canRemove)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(
                const _LinkEditorResult(url: '', remove: true),
              ),
              icon: const Icon(Icons.link_off),
              label: const Text('Remove link'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _submit,
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    Navigator.of(context).pop(
      _LinkEditorResult(
        url: _urlController.text,
        text: _textController?.text,
      ),
    );
  }
}

class _ImageEditorResult {
  const _ImageEditorResult({
    required this.url,
    required this.alt,
    this.title,
  });

  final String url;
  final String alt;
  final String? title;
}

class _ImageEditorDialog extends StatefulWidget {
  const _ImageEditorDialog({
    required this.initialUrl,
    required this.initialAlt,
    required this.initialTitle,
  });

  final String initialUrl;
  final String initialAlt;
  final String initialTitle;

  @override
  State<_ImageEditorDialog> createState() => _ImageEditorDialogState();
}

class _ImageEditorDialogState extends State<_ImageEditorDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _altController;
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _altController = TextEditingController(text: widget.initialAlt);
    _titleController = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _altController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Image'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('smooth_markdown_editor_image_url_input'),
              controller: _urlController,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Image URL',
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('smooth_markdown_editor_image_alt_input'),
              controller: _altController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Alt text',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('smooth_markdown_editor_image_title_input'),
              controller: _titleController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Title',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _submit() {
    Navigator.of(context).pop(
      _ImageEditorResult(
        url: _urlController.text,
        alt: _altController.text,
        title: _titleController.text,
      ),
    );
  }
}

class _BlockMathEditorDialog extends StatefulWidget {
  const _BlockMathEditorDialog({required this.initialLatex});

  final String initialLatex;

  @override
  State<_BlockMathEditorDialog> createState() => _BlockMathEditorDialogState();
}

class _BlockMathEditorDialogState extends State<_BlockMathEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLatex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }

        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }

        final submitShortcut = event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter;
        final modifierPressed = HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed;
        if (submitShortcut && modifierPressed) {
          Navigator.of(context).pop(_controller.text);
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        title: const Text('Edit Block Math'),
        content: SizedBox(
          width: 360,
          child: TextField(
            key: const ValueKey('smooth_markdown_editor_block_math_input'),
            controller: _controller,
            autofocus: true,
            minLines: 5,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter KaTeX expression...',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _CodeLanguage {
  const _CodeLanguage(this.value, this.label);

  final String value;
  final String label;
}

class _EditorCommandItem {
  const _EditorCommandItem({
    required this.title,
    required this.searchText,
    required this.icon,
    required this.command,
  }) : customCommand = null;

  _EditorCommandItem.custom(MarkdownEditorSlashCommand command)
      : title = command.title,
        searchText = command.searchText,
        icon = command.icon,
        command = null,
        customCommand = command;

  final String title;
  final String searchText;
  final IconData icon;
  final MarkdownEditorCommand? command;
  final MarkdownEditorSlashCommand? customCommand;
}

const _supportedCodeLanguages = [
  _CodeLanguage('', 'Plain text'),
  _CodeLanguage('javascript', 'JavaScript'),
  _CodeLanguage('typescript', 'TypeScript'),
  _CodeLanguage('python', 'Python'),
  _CodeLanguage('rust', 'Rust'),
  _CodeLanguage('json', 'JSON'),
  _CodeLanguage('sql', 'SQL'),
  _CodeLanguage('css', 'CSS'),
  _CodeLanguage('html', 'HTML'),
  _CodeLanguage('bash', 'Bash'),
  _CodeLanguage('markdown', 'Markdown'),
  _CodeLanguage('yaml', 'YAML'),
  _CodeLanguage('go', 'Go'),
  _CodeLanguage('java', 'Java'),
  _CodeLanguage('cpp', 'C++'),
  _CodeLanguage('c', 'C'),
  _CodeLanguage('swift', 'Swift'),
  _CodeLanguage('ruby', 'Ruby'),
  _CodeLanguage('php', 'PHP'),
  _CodeLanguage('diff', 'Diff'),
  _CodeLanguage('dockerfile', 'Dockerfile'),
  _CodeLanguage('mermaid', 'Mermaid'),
];

const _builtInSlashCommands = [
  _EditorCommandItem(
    title: 'Text',
    searchText: 'paragraph body plain normal',
    icon: Icons.notes_outlined,
    command: MarkdownEditorCommand.paragraph,
  ),
  _EditorCommandItem(
    title: 'Heading 1',
    searchText: 'heading h1 title',
    icon: Icons.title,
    command: MarkdownEditorCommand.heading1,
  ),
  _EditorCommandItem(
    title: 'Heading 2',
    searchText: 'h2 heading subtitle',
    icon: Icons.title,
    command: MarkdownEditorCommand.heading2,
  ),
  _EditorCommandItem(
    title: 'Heading 3',
    searchText: 'h3 heading',
    icon: Icons.title,
    command: MarkdownEditorCommand.heading3,
  ),
  _EditorCommandItem(
    title: 'Heading 4',
    searchText: 'heading h4',
    icon: Icons.title,
    command: MarkdownEditorCommand.heading4,
  ),
  _EditorCommandItem(
    title: 'Heading 5',
    searchText: 'heading h5',
    icon: Icons.title,
    command: MarkdownEditorCommand.heading5,
  ),
  _EditorCommandItem(
    title: 'Heading 6',
    searchText: 'heading h6',
    icon: Icons.title,
    command: MarkdownEditorCommand.heading6,
  ),
  _EditorCommandItem(
    title: 'Bullet List',
    searchText: 'bullet unordered ul list',
    icon: Icons.format_list_bulleted,
    command: MarkdownEditorCommand.unorderedList,
  ),
  _EditorCommandItem(
    title: 'Numbered List',
    searchText: 'number ordered ol list numbered',
    icon: Icons.format_list_numbered,
    command: MarkdownEditorCommand.orderedList,
  ),
  _EditorCommandItem(
    title: 'Task List',
    searchText: 'todo checklist checkbox task',
    icon: Icons.check_box_outlined,
    command: MarkdownEditorCommand.taskList,
  ),
  _EditorCommandItem(
    title: 'Blockquote',
    searchText: 'blockquote quote',
    icon: Icons.format_quote,
    command: MarkdownEditorCommand.blockquote,
  ),
  _EditorCommandItem(
    title: 'Code Block',
    searchText: 'code fenced block pre',
    icon: Icons.data_object,
    command: MarkdownEditorCommand.codeBlock,
  ),
  _EditorCommandItem(
    title: 'Mermaid Diagram',
    searchText: 'mermaid diagram flowchart chart',
    icon: Icons.account_tree_outlined,
    command: MarkdownEditorCommand.mermaidDiagram,
  ),
  _EditorCommandItem(
    title: 'Block Math',
    searchText: 'math equation',
    icon: Icons.functions,
    command: MarkdownEditorCommand.blockMath,
  ),
  _EditorCommandItem(
    title: 'Horizontal Rule',
    searchText: 'divider separator hr line horizontal rule',
    icon: Icons.horizontal_rule,
    command: MarkdownEditorCommand.horizontalRule,
  ),
  _EditorCommandItem(
    title: 'Image',
    searchText: 'picture photo img',
    icon: Icons.image_outlined,
    command: MarkdownEditorCommand.image,
  ),
  _EditorCommandItem(
    title: 'Table',
    searchText: 'table grid',
    icon: Icons.table_chart_outlined,
    command: MarkdownEditorCommand.table,
  ),
  _EditorCommandItem(
    title: 'Wikilink',
    searchText: 'wiki note link wikilink [[',
    icon: Icons.notes_outlined,
    command: MarkdownEditorCommand.wikilink,
  ),
];
