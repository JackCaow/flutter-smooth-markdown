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

**Markdown bold with <u>HTML underline</u> inside**, and
<b>HTML bold with *markdown italic* inside</b>.

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
