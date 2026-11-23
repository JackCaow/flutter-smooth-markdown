import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_clipboard/super_clipboard.dart' as clip;

import 'markdown_editor_clipboard.dart';

/// Connects a Markdown-editing field to keyboard, selection menu and browser paste.
class EditorClipboardField extends StatefulWidget {
  const EditorClipboardField({
    required this.child,
    this.readClipboard,
    this.onPasteImage,
    this.insertRichMarkdown,
    this.preferPlainText = false,
    super.key,
  });

  final TextField child;
  final Future<MarkdownClipboardContent?> Function()? readClipboard;
  final MarkdownPasteImageCallback? onPasteImage;
  final bool preferPlainText;

  final bool Function(TextSelection selection, String markdown)?
  insertRichMarkdown;

  static Widget contextMenu(BuildContext context, EditableTextState field) {
    final state = field.context
        .findAncestorStateOfType<_EditorClipboardFieldState>()!;
    void paste() {
      field.hideToolbar();
      unawaited(state._paste());
    }

    final items = field.contextMenuButtonItems;
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: field.contextMenuAnchors,
      buttonItems: [
        for (final item in items)
          if (item.type == ContextMenuButtonType.paste)
            ContextMenuButtonItem(
              type: ContextMenuButtonType.paste,
              onPressed: paste,
            )
          else
            item,
        if (!items.any((item) => item.type == ContextMenuButtonType.paste))
          ContextMenuButtonItem(
            type: ContextMenuButtonType.paste,
            onPressed: paste,
          ),
      ],
    );
  }

  @override
  State<EditorClipboardField> createState() => _EditorClipboardFieldState();
}

class _EditorClipboardFieldState extends State<EditorClipboardField> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      clip.ClipboardEvents.instance?.registerPasteEventListener(
        _onBrowserPaste,
      );
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      clip.ClipboardEvents.instance?.unregisterPasteEventListener(
        _onBrowserPaste,
      );
    }
    super.dispose();
  }

  void _onBrowserPaste(clip.ClipboardReadEvent event) {
    if (_canPaste) unawaited(_paste(event.getClipboardReader()));
  }

  bool get _canPaste =>
      widget.child.enabled != false && widget.child.focusNode!.hasFocus;

  Future<void> _paste([Future<clip.ClipboardReader>? event]) async {
    if (!_canPaste) return;
    final field = widget.child;
    final controller = field.controller!;
    final original = controller.value;
    final read = widget.readClipboard;
    final saveImage = widget.onPasteImage;
    final preferPlainText = widget.preferPlainText;
    bool stillCurrent() =>
        mounted &&
        _canPaste &&
        widget.child.key == field.key &&
        widget.child.controller == controller &&
        widget.preferPlainText == preferPlainText &&
        controller.value == original;
    final content = read == null
        ? await readMarkdownClipboard(await event)
        : await read();
    if (content == null || !stillCurrent()) return;
    final markdown = await clipboardContentToMarkdown(
      content,
      onPasteImage: saveImage,
      preferPlainText: preferPlainText,
    );
    if (markdown == null || markdown.isEmpty || !stillCurrent()) return;
    final selection = original.selection.isValid
        ? original.selection
        : TextSelection.collapsed(offset: original.text.length);
    if ((content.image != null || content.html?.isNotEmpty == true) &&
        widget.insertRichMarkdown?.call(selection, markdown) == true) {
      return;
    }
    controller.value = original
        .replaced(selection, markdown)
        .copyWith(
          selection: TextSelection.collapsed(
            offset: selection.start + markdown.length,
          ),
          composing: TextRange.empty,
        );
  }

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      PasteTextIntent: CallbackAction<PasteTextIntent>(
        onInvoke: (intent) {
          unawaited(_paste());
          return null;
        },
      ),
    },
    child: widget.child,
  );
}
