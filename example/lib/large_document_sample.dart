/// One complete section of the mixed Markdown rendering benchmark.
const mixedMarkdownSection = '''## **Shared** Markdown

A paragraph with **strong**, *emphasis*, `inline code`, [a link](/guide), 中文和 emoji 🙂.

- First item
- Second item
  - Nested item

| Name | Count |
| :--- | ---: |
| Alpha | 12 |
| Beta | 34 |

```dart
int greet(String name) => name.length;
```

''';

/// The same 435,200 UTF-16 code units used in the sustained benchmarks.
String buildLargeDocumentSample() => mixedMarkdownSection * 1600;
