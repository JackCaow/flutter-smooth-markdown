# Shared Rust core and stable Flutter APIs

Flutter vendors `smooth-rust-core` 0.2.0 at commit
`3e89ac88a49696bf9a45814b39ea06bd3703d692`, the same owned C ABI used by
[Android](https://github.com/JackCaow/android-smooth-markdown) and
[iOS](https://github.com/JackCaow/ios-smooth-markdown).
The upstream base revision, applied local patches and resulting SHA-256 source
manifest live in `rust-core/`. Inline-allocation and bridge-memory patches are
tracked in `tools/rust-core-patches/`; existing C entry points, wire bytes and
Flutter APIs remain compatible. The suffix entry is an additive ABI-1 extension.
Flutter never fetches a floating branch during a build.

## Existing consumers

Keep using `SmoothMarkdown`, `StreamMarkdown`, `SmoothMarkdownEditor`,
`MarkdownEditorController`, `MarkdownParser`, `ParserPluginRegistry` and
`BuilderRegistry`. Their existing constructor arguments, callback signatures and
AST types remain supported. Custom `codeBuilder` callbacks take precedence over
the built-in code/diff views. `MarkdownParser.parseBlocksOnly` intentionally
retains its existing pre-inline Dart AST contract.

Native targets automatically use Rust for ordinary Markdown and inline parsing.
User-defined plugins retain Dart callback ordering, including overrides of built-in syntax.
The safe HTML whitelist, disclosures, and legacy ragged table delimiters keep
the existing Flutter parser. The editable document codec uses the
Dart parser so source-only blocks, reference definitions and in-progress
whitespace stay aligned with their source ranges. The AST adapter
preserves Flutter list-item shape, separates task/bullet groups, and keeps the
existing code-fence newline convention. Source editing, rendering, selection,
Mermaid layout, images and formula layout remain Flutter responsibilities.
The editor's `markdownToHtml` keeps its established copy/export behavior;
`MarkdownCore.exportHtml` exposes the shared CommonMark/GFM exporter separately.

For staged migration or a behavior rollback:

```dart
SmoothMarkdown(
  data: source,
  config: const MarkdownConfig(
    parserBackend: MarkdownParserBackend.legacyDart,
  ),
);
final parser = MarkdownParser(backend: MarkdownParserBackend.legacyDart);
```

`automatic` is the default. `rust` requires a native engine on standard parsing
paths and reports an unsupported target explicitly. Parse-cache entries from
explicit backends cannot contaminate the default cache.

`StreamMarkdown` keeps its existing chunk/throttling/reset/error APIs. Eligible
streams retain committed AST blocks using one owned incremental session. Native
`automatic`/`rust` use Rust; `legacyDart` and Web `automatic` use the established
Dart parser with the same two-block mutable tail policy. Static
`MarkdownParser.parse` remains a full parse with its existing semantics. Enabled
HTML, legacy ragged tables, disclosures, active extension markers and
unknown plugins use the batch compatibility route. Standard tables and comparison
operators are eligible. Exact built-in plugins with no matching trigger in the
prefix can bypass hooks; active host plugins still execute synchronously in the
batch parser. This does not make active thinking/artifact/tool blocks incremental.
The streaming compatibility check retains the state of an unfinished table
delimiter. Adding a missing separator cell can restore incremental parsing
immediately; a completed ragged delimiter keeps the document on the batch path.
Built-in plugin markers are checked across chunk boundaries. Editing the
registered plugin list rechecks earlier text, and a custom registry subclass
keeps the full check because its getters may change between calls.
Both sessions roll back their last two top-level blocks on append, invalidate
globally after `]:`, and reset on non-append edits. Sessions are released on
stream replacement, backend changes, compatibility transitions and disposal,
with a native finalizer as a backstop for Rust. Committed built-in block widgets
use the same identity cache and pruning in both backends. Host rebuilds and inherited-context
changes invalidate their widgets. Custom builders keep per-publication evaluation.
Native results remain immutable `List<MarkdownNode>` snapshots. Internally, they
share completed 128-node pages and copy only the page directory, a partial
boundary page and newly decoded tail nodes. Old snapshots cannot observe later
updates or disposal. This avoids a full retained-node list copy per update;
the Dart backend retains its existing list publication implementation.
The existing `StreamMarkdown` box retains 32-node layout pages so parents such
as a `Column` or `SingleChildScrollView` can measure its full height. For long
content, let a `CustomScrollView` own the viewport and choose the entry that
matches the input.

```dart
CustomScrollView(
  controller: scrollController,
  slivers: [
    SmoothMarkdown.sliver(data: document),
    // For a live response, use StreamMarkdown.sliver(stream: chunks).
  ],
)
```

The default non-selectable sliver builds individual top-level blocks as they
enter the visible area or Flutter's nearby scroll cache. Scrolling away allows
Flutter to release their elements and render objects. An append reuses the
contents of mounted, unchanged blocks. A document consisting of a single long
paragraph, table or code fence can still incur layout work for that whole block.
Flutter estimates the scroll extent as it encounters variable-height content.

For large static documents, compatible input can show complete initial blocks
while the full parser resolves the rest. Reference definitions and incompatible
syntax suppress this preview. On native targets the full parse can use a
worker isolate; Flutter Web runs `compute` on the browser event loop.
Custom parser callbacks that must execute in the caller stay on its isolate.
For input larger than the native limit of 8,388,608 UTF-16 code units,
automatic mode selects the Dart parser. An ongoing native stream switches
sessions once when a publication crosses that limit.

Full-document selection and reverse vertical scrolling use a single box so
offscreen selection and reading order keep their existing behavior. In the
streaming API, active plugin, HTML and custom builder paths which require
whole-document evaluation also retain the box layout.

## Code and diff

The method names mirror the native libraries: `normalizedCodeLanguage`,
`highlightedCode`, `highlightedLines`, and `highlightedDiff`.

```dart
final tokens = MarkdownCore.highlightedCode(code, language: 'App.tsx');
final lines = MarkdownCore.highlightedLines(code, language: 'dart', tabWidth: 4);
final rows = MarkdownCore.highlightedDiff(patch, language: 'dart');
final html = MarkdownCore.exportHtml(markdown); // escapes raw HTML by default
```

Tokens have `start`, `length`, `end`, and a named `MarkdownHighlightKind`.
Offsets count UTF-16 code units, directly usable with Dart `String.substring`.
Line tokens refer to display text after tab expansion. Diff rows have a role,
highlighted line, old/new line numbers, and optional `changedStart` and
`changedLength`. Highlights run on each entire file or hunk side, preserving
multiline lexical state. These APIs never expose pointers, wire IDs, or Rust
allocation lifetimes. Unknown languages produce plain text.

```dart
MarkdownCodeView(code: code, language: 'dart');
MarkdownDiffView(patch: unifiedDiff, language: 'dart');
```

Both views accept `syntaxTheme`, `textStyle`, `showLineNumbers`, `selectable`,
`tabWidth`, and `padding`. The source viewer and default unified diff scroll
horizontally. For a two-column review, set `layout: MarkdownDiffLayout.sideBySide`.
Each removal is aligned with its corresponding addition within the hunk.
Unmatched lines leave an empty cell on the opposite side.

For large patches, place the diff directly in a vertical `CustomScrollView`.
The sliver builds unified rows or side-by-side row pairs in and near the
viewport. Long lines wrap within the available width. Parsing and syntax
highlighting still run on the complete patch to preserve multiline syntax.
Use `selectable: true` to mount the complete patch for selection across
offscreen rows.

```dart
CustomScrollView(
  slivers: [
    MarkdownDiffView.sliver(
      patch: unifiedDiff,
      language: 'dart',
      layout: MarkdownDiffLayout.sideBySide,
    ),
  ],
)
```

Normal and enhanced Markdown code blocks use the same highlighter. A fence
whose info is `diff dart` renders a Dart-highlighted diff; `diff` alone produces
a plain-language diff. Set `MarkdownConfig(enableCodeHighlight: false)` to
retain plain code. Existing custom code builders remain authoritative.

Style tokens by semantic kind, retaining all defaults with `copyWith`:

```dart
final colors = MarkdownSyntaxTheme.fromBrightness(Brightness.dark).copyWith(
  styles: {
    MarkdownHighlightKind.variableParameter: TextStyle(color: Colors.orange),
  },
);
SmoothMarkdown(data: source, config: MarkdownConfig(syntaxTheme: colors));
MarkdownDiffView(patch: patch, language: 'dart', syntaxTheme: colors);
```

## Platforms and build requirements

This source integration requires **Flutter 3.38+ / Dart 3.10+**, Rust/Cargo,
and the Rust target for each native architecture. The build hook compiles the
vendored dependency-free crate offline and bundles its dynamic library through
Dart code assets. End-user devices require no Rust installation. CI/source-build
machines do require the Rust toolchain; this change does not publish prebuilt
binary packages. Flutter handles bundling/signing the native asset. The hook builds the native asset at Rust optimization level 3 for throughput.
It enables the
private `flutter-compact-ast` feature; the default Rust build retains its original
public struct API. Apps do not need a new configuration flag.

```sh
rustup target add aarch64-apple-darwin
flutter pub get
flutter test
cd example
flutter run -d macos
# Or the standalone code/diff screen:
flutter run -d macos -t lib/core_preview_main.dart
```

The build hook maps macOS arm64/x64, iOS arm64 device and arm64/x64 simulator,
Android arm/arm64/x86/x64, Linux arm64/x64 and Windows arm64/x64. Android builds
use Flutter's selected NDK compiler. Cross-compilation needs the corresponding
platform SDK/linker in addition to `rustup target add`. The example's macOS
minimum is 12.0 to match the current Xcode toolchain.

Web uses the existing Dart parser and Dart highlighter behind the same public
models and views. It does not bundle the Rust engine or require Cargo. Web token
classification and its compatibility HTML exporter are not claimed to have full
Rust CommonMark/highlighting parity. `MarkdownCore.isNative` reports the engine.
A WebAssembly implementation can replace the private transport later without
changing the supported token/line/diff APIs.

## Core upgrades and validation

```sh
python3 tools/sync-rust-core.py /path/to/clean/smooth-rust-core
(cd rust-core && shasum -a 256 -c SOURCE.sha256)
cargo test --locked --manifest-path rust-core/Cargo.toml
flutter test test/rust test/parser test/editor test/stream test/renderer
cd example
flutter test
flutter build web -t lib/core_preview_main.dart
```

Upgrade the pinned snapshot, adapt the private wire layer if required, and run
both shared-core contract tests and the existing Flutter compatibility suite.
The sync script stages the source and checks local patches before replacing
vendored files. If upstream changes overlap a patch, review the conflict; remove
the patch when upgrading to an upstream revision that already contains it.
`python3 benchmarks/probes/native_profile.py` also compares full ASTs against
the unpatched base on conformance fixtures and generated input with host hooks.
Keep format/ownership checks and source offsets in the private transport;
application integration should continue to use named Flutter models. The
vendored Rust tests include all CommonMark/GFM fixture and stream-prefix gates.

The example library includes **Code & Diff**, with Source/Diff/Markdown tabs,
theme and line-number toggles. The standalone entry is
`example/lib/core_preview_main.dart`.

### Release verification (2026-11-20)

- The project was tested with Flutter 3.41.6 and Dart 3.11.4 on Apple Silicon. The Rust source manifest and default/compact Rust test suites were checked.
- The example suite covers gallery navigation, editable and selectable content, code review, long documents and streamed answers. The Web build uses the Dart fallback.
- Android arm64 was installed and exercised on a physical device. iPhone 17 Profile runs exercised first content, scrolling, streaming and native code assets. The ordinary example was also built, installed and opened on the iPhone.
- The macOS example was launched and its highlighted diff inspected. Linux and Windows builds are pending platform acceptance.
- The Mermaid state, subgraph and dark-state golden tests have known differences on the macOS test host. See the release PR for the comparison with the base revision.

Performance is measured separately from functional acceptance. See
[the incremental compatibility check and frame measurements](../benchmarks/stream-eligibility-results.md),
[the retained-block and lazy-sliver results](../benchmarks/block-layout-results.md),
[the actual streaming render-frame comparison](../benchmarks/render-results.md),
[the latest sustained-stream RSS investigation](../benchmarks/sustained-rss-results.md),
[the latest bridge CPU/memory results](../benchmarks/bridge-optimization-results.md),
[the equal-strategy Dart/Rust incremental comparison](../benchmarks/equal-incremental-results.md),
[the static batch Profile results](../benchmarks/batch-round2-results.md)
and [the original diagnosis](../benchmarks/README.md). Native paged snapshots
reduce the 435k retained RSS increment from 25.70 to 17.08 MiB, close to the
unchanged Dart control's 17.89 MiB. Sampled streaming peaks remain higher in Rust.
The 435k CPU comparison shows a small cost versus the old Rust bridge while
remaining faster than same-strategy Dart. These are Mac host parser
measurements, not Android FPS or new rendering-speed claims.
