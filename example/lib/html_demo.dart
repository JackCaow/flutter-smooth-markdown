import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

/// Demo page showing HTML tag rendering
class HtmlDemo extends StatefulWidget {
  const HtmlDemo({
    super.key,
    this.styleSheet,
  });

  final MarkdownStyleSheet? styleSheet;

  @override
  State<HtmlDemo> createState() => _HtmlDemoState();
}

class _HtmlDemoState extends State<HtmlDemo> {
  bool _enableHtml = true;
  bool _isStreaming = false;
  StreamController<String>? _streamController;

  static const String _htmlContent = '''
# HTML Tags Demo

Enable `MarkdownConfig(enableHtml: true)` to render a safe whitelist of
HTML tags. Toggle the switch in the app bar to compare.

## Inline Formatting

- Bold: <b>b tag</b> and <strong>strong tag</strong>
- Italic: <i>i tag</i> and <em>em tag</em>
- Underline: <u>u tag</u> and <ins>ins tag</ins>
- Strikethrough: <s>s</s>, <del>del</del>, <strike>strike</strike>
- Highlight: <mark>marked text</mark>
- Keyboard: press <kbd>Ctrl</kbd> + <kbd>C</kbd> to copy
- Code: <code>const x = 1;</code>
- Sub/sup: H<sub>2</sub>O and E = mc<sup>2</sup>
- Line break: first line<br>second line

## Mixing Markdown and HTML

HTML and Markdown can be nested in either direction. These four cases cover
each combination of inline vs. block on both sides.

### Inline ↔ inline

**Markdown bold with <u>HTML underline</u> inside**, and
<b>HTML bold with *markdown italic* inside</b>.

### HTML inline inside Markdown structure

HTML tags work inside markdown headers and list items:

#### A header with a tag: Note <sup>2</sup>

- List item with <b>bold</b>, <i>italic</i>, and <mark>mark</mark>
- Another item with an <a href="https://flutter.dev">HTML link</a> inside

### Markdown inside HTML styling tags

`<font>` and `<span>` run their children back through the markdown inline
parser, so styling composes with markdown emphasis and code:

- <font color="red">red with **bold** inside</font>
- <span style="font-size: 22px;">sized with *italic* and `code` inside</span>

### HTML block wrapping Markdown blocks

`<div>` and `<center>` blocks re-parse their contents as markdown blocks, so
headings, lists, and paragraphs work inside them (the opening tag must sit
at the start of its own line):

<div>

### A heading inside `<div>`

- a list item inside `<div>`
- another item with **bold**

A normal paragraph inside `<div>`, with <i>inline HTML</i> too.

</div>

## Colors and Sizes

- <font color="red">font color red</font>
- <font color="#1E88E5" size="5">font color and size</font>
- <span style="color: green;">span green</span>
- <span style="background-color: yellow; color: black;">span highlight</span>
- <span style="font-size: 22px;">span font size</span>

## Links and Images

- HTML link: <a href="https://flutter.dev" title="Flutter">flutter.dev</a>
- Unsafe links are stripped: <a href="javascript:alert(1)">safe text only</a>
- Sized image: <img src="https://picsum.photos/300/150" alt="demo" width="300" height="150">

## Block Elements

<center>

**This block is centered** via `<center>`.

</center>

<div align="right">

Right-aligned via `<div align="right">`.

</div>

<p>A paragraph tag with plain content.</p>

<blockquote>
An HTML blockquote with *markdown* inside.
</blockquote>

<hr>

## Unknown Tags

Unknown tags are stripped while keeping their content:
<video>this text is kept, the video tag is not</video>.

## Image `src` Policy

Image sources are constrained by what the renderer can actually load: only
`http`/`https` and local paths. Schemes that pass link-safety but cannot be
loaded as images fall back to the alt text instead of a broken placeholder.

- Network image (loads): <img src="https://picsum.photos/320/120" alt="network" width="320" height="120">
- Protocol-relative URL (rejected → alt text): <img src="//picsum.photos/120/120" alt="protocol-relative">
- `mailto:` scheme (rejected → alt text): <img src="mailto:a@b.com" alt="mailto-not-an-image">
- `tel:` scheme (rejected → alt text): <img src="tel:+12345" alt="tel-not-an-image">
- Unsafe scheme (rejected → alt text): <img src="javascript:alert(1)" alt="javascript-blocked">

## Streaming Tag Withholding

While streaming, a tag split across chunks (e.g. `<font colo` arriving
before `r="red">`) is withheld until its closing `>` arrives, so the partial
tag is never flashed as literal text. Tap the play button and watch this
line render in one piece:

<font color="purple">purple text arrives tag-complete, never as `<font colo`</font>

This withholding only applies when HTML is enabled. Toggle HTML off and
stream again: the same line, plus prose like `a < b` and `<3 hearts`, must
still render verbatim without being swallowed mid-stream.

## Non-Breaking Renderer API

`BlockRenderer` stays a plain single-argument `(nodes) => widget` callback,
so existing custom block renderers keep working. The optional render-context
override (used, for example, by HTML blocks to apply text alignment) lives
on a separate additive `ContextualBlockRenderer` typedef — covered by
`test/renderer/widget_builder_test.dart`.

## Still Safe

Plain comparisons stay literal: 1 < 2, a < b, and <3 hearts.
Inline code is protected: `<b>not bold</b>`.
''';

  /// Splits the demo content into word-level chunks with their trailing
  /// whitespace, approximating how a token stream would arrive.
  static List<String> _chunkContent(String content) {
    return RegExp(r'\S+\s*')
        .allMatches(content)
        .map((match) => match[0]!)
        .toList();
  }

  /// Streams the demo content chunk by chunk to simulate live output.
  Future<void> _startStreaming() async {
    if (_isStreaming) return;

    final controller = StreamController<String>();
    setState(() {
      _isStreaming = true;
      _streamController = controller;
    });

    for (final chunk in _chunkContent(_htmlContent)) {
      if (!mounted || controller.isClosed) break;
      controller.add(chunk);
      await Future.delayed(const Duration(milliseconds: 40));
    }

    if (mounted) {
      setState(() => _isStreaming = false);
      await controller.close();
    }
  }

  /// Stops the active stream and returns to the static view.
  void _stopStreaming() {
    _streamController?.close();
    setState(() {
      _streamController = null;
      _isStreaming = false;
    });
  }

  @override
  void dispose() {
    _streamController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HTML Tags Demo'),
        actions: [
          Row(
            children: [
              const Text('HTML'),
              Switch(
                value: _enableHtml,
                onChanged: (value) => setState(() => _enableHtml = value),
              ),
            ],
          ),
          IconButton(
            tooltip: _isStreaming ? 'Stop streaming' : 'Simulate streaming',
            icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
            onPressed: _isStreaming ? _stopStreaming : _startStreaming,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isStreaming) const LinearProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _streamController == null
                  ? SmoothMarkdown(
                      data: _htmlContent,
                      styleSheet: widget.styleSheet,
                      config: MarkdownConfig(enableHtml: _enableHtml),
                    )
                  : StreamMarkdown(
                      stream: _streamController!.stream,
                      styleSheet: widget.styleSheet,
                      config: MarkdownConfig(enableHtml: _enableHtml),
                      loadingWidget:
                          const Center(child: CircularProgressIndicator()),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
