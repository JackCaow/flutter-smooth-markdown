import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

class EditorDemoPage extends StatefulWidget {
  const EditorDemoPage({super.key});

  @override
  State<EditorDemoPage> createState() => _EditorDemoPageState();
}

class _EditorDemoPageState extends State<EditorDemoPage> {
  late final MarkdownEditorController _controller;
  String _lastExport = '';

  @override
  void initState() {
    super.initState();
    _controller = MarkdownEditorController(text: _initialMarkdown);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Markdown Editor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Scratch-style editor preview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Toolbar, slash commands, wikilinks, Mermaid preview, math editing, search, focus mode, and copy/export menu.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final editorHeight = constraints.maxHeight > 56
                      ? constraints.maxHeight - 56
                      : constraints.maxHeight;
                  return SmoothMarkdownEditor(
                    controller: _controller,
                    initialMode: MarkdownEditorMode.formatted,
                    wikilinkSuggestions: const [
                      'Daily Notes',
                      'Project Plan',
                      'Research Index',
                      'Scratch Reference',
                    ],
                    onTapWikilink: (target) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Wikilink: $target')),
                      );
                    },
                    onExportMarkdown: (markdown) {
                      setState(() => _lastExport = markdown);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Markdown export requested'),
                        ),
                      );
                    },
                    height: editorHeight,
                  );
                },
              ),
            ),
            if (_lastExport.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Last export: ${_lastExport.length} characters',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _initialMarkdown = '''
# Scratch-style Markdown Editor

This editor keeps Markdown as source while giving you formatted blocks. Try **bold**, *italic*, `inline code`, links, and [[Daily Notes]].

- [x] Toolbar commands
- [x] Slash commands
- [x] Wikilink autocomplete
- [ ] Keep iterating on full WYSIWYG parity

> Use the search icon to find `Mermaid`, or press Cmd/Ctrl+F.

```mermaid
graph TD
  A[Write Markdown] --> B{Preview}
  B -->|Formatted| C[Tap a block to edit]
  B -->|Source| D[Raw Markdown]
```

\$\$
E = mc^2
\$\$

```dart
void main() {
  print('SmoothMarkdownEditor');
}
```

| Feature | Status |
|---|---|
| Copy HTML | Done |
| Export Markdown | Callback |
| Focus mode | Done |
''';
