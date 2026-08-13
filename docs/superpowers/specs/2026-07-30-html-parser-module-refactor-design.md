# HTML Parser Module Refactor Design

## Context

HTML support currently spans `InlineParser`, `BlockParser`, pure HTML helpers,
HTML AST nodes, and renderer builders. The behavior is well covered and the
current performance baseline is healthy, but HTML-specific parsing and AST
construction still live inside the general Markdown parsers. This makes those
parsers harder to navigate and requires maintainers to understand unrelated
HTML rules when changing core Markdown parsing.

This refactor moves HTML parsing behind two internal module interfaces while
preserving all public and observable behavior.

## Goals

- Concentrate inline HTML behavior in one internal module.
- Concentrate block HTML behavior in one internal module.
- Keep pure lexing and sanitization helpers platform independent.
- Reduce HTML-specific responsibilities in `InlineParser` and `BlockParser`.
- Avoid repeated lexing of a block's opening tag after it has been recognized.
- Preserve the current public interface, AST, rendering, security, fallback,
  and streaming behavior.

## Non-goals

- Adding tags, attributes, CSS properties, or HTML entity decoding.
- Changing `MarkdownConfig.enableHtml` or its default value.
- Changing HTML AST node types, renderer builders, or style configuration.
- Moving the existing `details` and `summary` path into the opt-in HTML parser.
- Changing output for malformed, unsafe, unknown, or incomplete HTML.
- Claiming a large parsing performance improvement from a structural refactor.

## Architecture

### Inline HTML module

Add `lib/src/parser/html/html_inline_parser.dart` with an internal
`HtmlInlineParser` module. Its interface accepts source text, a start offset,
the current nesting depth, and an internal callback that parses child inline
Markdown. It returns either no match or an `HtmlInlineParseResult` containing
the generated nodes and consumed character count.

Its implementation owns:

- matching paired, void, self-closing, stray closing, and incomplete tags;
- mapping whitelisted formatting tags to existing AST nodes;
- stripping unknown tags while preserving parsed child content;
- creating safe links, images, and styled spans;
- applying the existing unsafe URL and invalid attribute fallbacks;
- preserving verbatim content for HTML `code` tags.

`InlineParser` retains Markdown precedence, the `enableHtml` guard, the cheap
`<` start check, and recursion depth policy. At the existing HTML decision
point it delegates to `HtmlInlineParser` and appends the returned nodes.

### Block HTML module

Add `lib/src/parser/html/html_block_parser.dart` with an internal
`HtmlBlockParser` module. It exposes a lightweight line probe and a block parse
operation. A successful probe carries the already-lexed opening tag so block
parsing does not lex the same tag again.

Its implementation owns:

- recognizing standalone HTML `hr` lines and whitelisted block starts;
- scanning same-name nesting across lines;
- preserving text before and after the terminating close tag;
- consuming incomplete blocks through the end of the current input;
- parsing the `align` attribute and the implicit `center` alignment;
- mapping HTML `blockquote` to the existing `BlockquoteNode`;
- creating the existing `HtmlBlockNode` for other supported block tags.

The module receives an internal callback for parsing block child Markdown.
`BlockParser` retains Markdown block precedence and decides when to probe HTML.
Paragraph termination uses the same lightweight probe contract.

### HTML utilities

Keep `lib/src/parser/html/html_utils.dart` limited to stateless, pure Dart
lexing and safety functions. It continues to own tag lexing, close-tag scans,
URL checks, color and dimension parsing, and inline CSS declaration parsing.
It does not construct AST nodes or orchestrate Markdown parsing.

### Unchanged layers

`MarkdownParser`, HTML AST nodes, renderer builders, `StreamMarkdown`, public
exports, configuration, and theme fields remain unchanged. The refactor stops
at the parser's internal module seams.

## Data Flow

```text
MarkdownParser
  -> BlockParser
       -> HtmlBlockParser
       -> InlineParser
            -> HtmlInlineParser
  -> existing AST
  -> existing renderer
```

When HTML is disabled, the general parsers do not invoke the HTML modules.
When inline parsing encounters a plausible `<`, `HtmlInlineParser.tryParse`
either returns no match so `<` remains literal, or returns a result with a
strictly positive consumed count. Block parsing probes HTML only at the same
precedence points used today and passes a successful probe into block parsing.

Child content is parsed through callbacks into the existing Markdown parsers.
The HTML modules do not duplicate Markdown syntax rules and do not depend on
renderer code.

## Compatibility And Fallbacks

The following behavior is invariant:

- Invalid tags remain literal text.
- Unknown valid tags are removed while their child content is retained.
- Unsafe anchors retain their child text without a link node.
- Unsafe or missing image sources degrade to alt text or no node.
- Stray closing tags are consumed silently.
- Explicitly self-closed non-void tags produce no content.
- Unclosed paired tags consume through the current input end.
- HTML inside code spans, code blocks, and math remains protected.
- `details` and `summary` continue through their dedicated parser path.
- `enableHtml: false` keeps HTML literal and retains the existing fast path.

User-controlled input must not cause parsing exceptions. A block parse
operation receives a validated probe result; mismatches between those internal
values are programming errors guarded by assertions rather than user-facing
exceptions.

## Testing Strategy

Implementation follows characterization-first migration:

1. Add focused interface tests for inline no-match, positive consumption,
   unknown-tag splicing, unsafe URL fallback, and incomplete-tag behavior.
2. Add focused interface tests for block probing, reuse of the probed opening
   tag, nested multiline blocks, trailing same-line content, alignment, and
   incomplete blocks.
3. Move the current implementation behind the new interfaces without changing
   expected AST values.
4. Keep all existing parser, renderer, integration, streaming, and performance
   tests passing.

The verification commands are:

```bash
flutter test test/parser/html_utils_test.dart \
  test/parser/html_nodes_test.dart \
  test/parser/html_inline_test.dart \
  test/parser/html_block_test.dart \
  test/renderer/html_builder_test.dart \
  test/integration/html_integration_test.dart \
  test/performance/html_parse_benchmark_test.dart

dart analyze \
  lib/src/parser/html/html_utils.dart \
  lib/src/parser/html/html_inline_parser.dart \
  lib/src/parser/html/html_block_parser.dart \
  lib/src/parser/inline_parser.dart \
  lib/src/parser/block_parser.dart

git diff --check
```

The existing generous benchmark guards remain the performance acceptance
criteria. The refactor must not add a stricter timing assertion based on a
single local run.

## Success Criteria

- `InlineParser` contains no HTML tag-to-AST mapping or HTML attribute logic.
- `BlockParser` contains no HTML close-tag scanning, alignment parsing, or HTML
  block AST construction.
- The two HTML parser modules expose only the information their callers need.
- No public type, constructor, configuration default, or export changes.
- Existing HTML behavior and focused tests remain green.
- Static analysis and whitespace validation pass.
- Changes remain limited to parser internals and their focused tests.
