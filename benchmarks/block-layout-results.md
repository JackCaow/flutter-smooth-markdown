# Retained block layout and lazy slivers — 2026-11-20

Eligible streaming updates now reuse **32-node layout and paint pages** in both
backends. In the 435k fixture, median UI-frame time drops from **62.80 to 3.28 ms
for Dart**, and **73.34 to 3.10 ms for Rust** (about 95% / 96% less time).
Existing `StreamMarkdown` remains a box with the same external scroll ownership
and exact content height.

The additive `StreamMarkdown.sliver` constructor builds viewport/cache-extent
pages in a parent `CustomScrollView`. It measures about 5 ms per 435k append in
this run. It is not faster than the cached box path in every case; its extra
benefit is avoiding the initial mount of every block, not a guaranteed lower
steady-update time. The complete AST is still parsed/retained.

## Changes and compatibility

- An internal optional `RetainedCoreStream` capability reports actual retained
  **Flutter node counts**. Native source blocks can project into zero or several
  nodes; the count comes from existing native-group end offsets. No Rust source,
  C ABI, SMR1 format or parser policy changed.
- The stream cache removes only the replaced tail. Complete pages retain widget
  identity; a boundary page is rebuilt from retained/new nodes. Page widgets own
  only their node slice and render context, avoiding closures over old full
  snapshot directories.
- Pages retain both layout subtrees and repaint boundaries. Grouping widgets
  alone was insufficient: the box scroll composition otherwise still walked
  the complete paint subtree. Stable page layers now bypass that traversal.
- Spacing is attached before each block except the document's first. This keeps
  exact geometry across page boundaries without changing a completed page when
  the document grows. Width/font/context changes and asynchronous child-size
  changes still use Flutter's normal layout invalidation.
- No internal scroll view/controller was inserted into the default API. The
  sliver constructor explicitly delegates scrolling to its parent; its scroll
  extent uses ordinary variable-height sliver estimates.
- Selectable content retains its complete selection tree. Custom builder
  callbacks and compatibility routes retain complete evaluation. Reverse-axis
  sliver scrolling also uses a complete box tree to preserve Markdown reading
  order. These routes do not gain viewport virtualization.
- Host/theme changes, backend/stream replacement, global references, error
  handling and disposal keep their established invalidation behavior.

## Same-process frame comparison

Apple M4, macOS 27.2, Flutter 3.41.6 / Dart 3.11.4, Profile/AOT; 1600 × 1200
physical test view, DPR 2. Each backend uses the same inactive AI registry,
native highlighter and parser rollback/definition policy. Actual parsed ranges
and retained native-block counts match at every publication, checked outside
frame collection.

A frozen copy of the previous stream widget runs in the **same AOT process**.
Its ordinary identity-map cache takes the unchanged full-Column renderer path.
The current box path and sliver path use the new page cache. Backend and layout
order alternate over three trials; no trial is excluded. Eight measured
paragraph appends follow prefill and three warmups in every cell: **54 cells,
432 actual content-update frames**.

Table values are medians of the three per-trial medians, in milliseconds:

| Document | Backend | Previous box | Compatible paged box | Lazy sliver |
| --- | --- | ---: | ---: | ---: |
| 3,264 UTF-16 units | Dart | 2.74 | 0.95 | 0.37 |
| | Rust | 3.36 | 0.99 | 0.51 |
| 43,520 units | Dart | 7.86 | 0.77 | 1.02 |
| | Rust | 7.80 | 0.71 | 1.02 |
| 435,200 units | Dart | **62.80** | **3.28** | **5.43** |
| | Rust | **73.34** | **3.10** | **5.03** |

435k UI medians for each trial:

| Backend / layout | Trial 1 | Trial 2 | Trial 3 |
| --- | ---: | ---: | ---: |
| Dart previous | 62.10 | 69.81 | 62.80 |
| Dart paged | 3.28 | 3.74 | 3.19 |
| Dart sliver | 6.07 | 5.22 | 5.43 |
| Rust previous | 73.34 | 72.69 | 73.53 |
| Rust paged | 3.02 | 3.29 | 3.10 |
| Rust sliver | 5.01 | 5.31 | 5.03 |

435k tail/raster statistics (medians of per-trial statistics):

| Backend | Previous UI P95 | Paged UI P95 | Sliver UI P95 | Raster median: previous / paged / sliver |
| --- | ---: | ---: | ---: | ---: |
| Dart | 86.95 ms | 7.59 ms | 7.30 ms | 5.46 / 1.96 / 0.85 ms |
| Rust | 98.35 ms | 4.47 ms | 6.25 ms | 5.18 / 1.86 / 0.83 ms |

Each trial has only eight content samples, so its P95 is its maximum; this is
an observational tail statistic, not a precise population percentile. All 24
435k frames per backend exceed 16.67 ms with the previous box layout. All 24
per backend are below that UI budget with either new layout. This does not
establish phone FPS, 120 Hz smoothness or scrolling throughput.

## Where the 435k backend difference comes from

This section measures the earlier full-document compatibility check. The
[incremental check follow-up](stream-eligibility-results.md) measures the
updated widget on the same input and on 1,600 successive publications.

A separate macOS Profile/AOT probe runs the production eligibility check and
stream sessions on the same prefixes as the frame test. Each 16-unit append
reparses **46 UTF-16 units** on both backends, retaining 8,001 to 8,008 completed
blocks. The eligibility check receives the full growing document each time.
This fixture contains tables and registers three inactive AI plugins.

| Per append | Dart | Rust |
| --- | ---: | ---: |
| Shared Dart eligibility check | 1.687 ms | 1.680 ms |
| Session update through publication of Flutter nodes | 0.418 ms | 0.345 ms |

Rust saves about **0.073 ms (17%)** in the session call on this input. The shared
check alone takes roughly four to five times as long as that call. Both backends
subsequently use the same Flutter layout and paint code. The separately measured
default box frame medians differ by **0.177 ms (5.4%)**.

The probe precomputes inputs, discards a warmup pair, alternates backend order
across eight trials, and times eight appends per trial after prefill and three
warmup appends. The table reports medians of the eight trial medians. Prefix
construction, widgets and frame scheduling are outside these timings. The stage
and frame measurements come from different runs and cannot be subtracted to
derive a layout time.
[Raw stage samples](evidence/macos-profile-2026-11-20-render-append-stages.json)
and [reproducible probe](../example/integration_test/render_append_stages_test.dart).

## Scope and measurement details

UI time is engine `FrameTiming.buildDuration`: eligibility/parsing inside the
widget build, building/updating widgets, layout, paint preparation and scene
submission. Raster time is the raster-thread duration, not isolated GPU time.
Chunk buffering, throttle waiting and chunk-to-display latency are separate.

Content updates that affect only an offscreen sliver page may need **no layout**.
The probe therefore tags the actual dirty stream element at engine draw-frame
entry, captures a timeline timestamp inside that frame's build interval, and
accepts exactly one engine timing per publication. Idle frames are excluded.
The layout-only marker used in the previous report would miss these updates.

The scroll position remains at the top. Publications wait until their content
frame executes, then wait 90 ms, above the 50 ms throttle. Prefill/first paint,
three warmup updates and scrolling are excluded. Large blocks are not split:
one giant paragraph, table or code block still needs its own full layout. The
corpus is the existing repeated mixed section fixture, not a general bound for
all Markdown documents.

Interrupted exploratory runs left two benchmark apps alive. They were stopped;
their affected/incomplete data were rejected. The accepted run used one
benchmark app and completed successfully. Desktop load can still vary. The
earlier [render report](render-results.md) uses a different protocol and is
historical evidence, not the before control for the speedups above.

## Verification

- Box geometry and positions match flat rendering across page boundaries,
  including headings, tables, lists, code blocks and narrow-width resize, for
  both backends. Retained prefix widget identities remain stable.
- A render-object paint counter verifies a tail append does not repaint prefix
  pages, while a width change correctly invalidates their paint.
- Lazy viewport tests confirm offscreen blocks are unmounted, reach the tail by
  scrolling, and preserve the parent's scroll position during append. Reverse
  scroll order, full selection mounting, loading/errors, stream replacement and
  custom callback invocation are covered.
- Focused layout/paint tests: **11 passed**. Full Flutter suite: **1,178 passed**,
  with the same three pre-existing Mermaid golden differences. Example tests:
  **5 passed**. Web preview and default Wasm dry run succeeded (existing font
  notice remains). Analysis: **zero errors/warnings**, 308 style/info notices.

## Usage and evidence

Existing callers need no changes. For lazy mounting:

```dart
CustomScrollView(
  controller: scrollController,
  slivers: [StreamMarkdown.sliver(stream: chunks)],
)
```

- [All 432 accepted frame samples](evidence/macos-profile-2026-11-20-block-layout.json)
- [Three-trial distributions and payload fingerprints](evidence/macos-block-layout-2026-11-20-summary.json)
- Frozen control: `example/integration_test/support/legacy_stream_markdown.dart`.
- Reproduce with the existing `core_performance_driver.dart` and target
  `integration_test/render_performance_test.dart` in macOS Profile mode. This
  host uses the documented temporary arm64-only Xcode configuration.
