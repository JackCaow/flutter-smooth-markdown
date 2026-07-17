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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: SmoothMarkdown(
          data: _htmlContent,
          styleSheet: widget.styleSheet,
          config: MarkdownConfig(enableHtml: _enableHtml),
        ),
      ),
    );
  }
}
