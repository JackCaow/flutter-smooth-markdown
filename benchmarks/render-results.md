# Actual streaming render frames — 2026-11-20

This is the pre-block-layout measurement. See the
[retained-page and lazy-sliver follow-up](block-layout-results.md) for current
implementation and same-process before/after results.

**Switching to Rust has not established a consistent rendering improvement.**
The two backends share the Flutter renderer. At 435k, even the lighter-load
trials spend roughly **64–75 ms on the UI thread per content update**, versus
about 5 ms raster time. Every measured 435k content frame exceeds the 16.67 ms
UI budget for 60 Hz. Faster parsing alone does not resolve this bottleneck.

These are new actual `StreamMarkdown` frame measurements after the paged
snapshot optimization, not the parser-only timings in
[the RSS investigation](sustained-rss-results.md).

## Results and variation

Apple M4, macOS 27.2, Flutter 3.41.6 / Dart 3.11.4, Profile/AOT. The test view is
1600 × 1200 physical pixels at DPR 2 (800 × 600 logical). Three trials per
backend/size alternate backend order. Tables summarize the **median of three
per-trial statistics**, rather than presenting pooled percentiles.

UI time is `FrameTiming.buildDuration`: parsing/eligibility, widget building,
layout, paint preparation and scene submission on the UI thread. Raster is the
engine raster-thread duration. It is not isolated GPU execution time.

| Prefilled document | Dart UI median / P95 | Rust UI median / P95 | Dart / Rust raster median |
| --- | ---: | ---: | ---: |
| 3,264 UTF-16 units | 3.11 / 3.71 ms | 3.40 / 3.99 ms | 1.74 / 1.88 ms |
| 43,520 units | 6.82 / 7.81 ms | 6.87 / 8.54 ms | 1.01 / 0.97 ms |
| 435,200 units | 74.66 / 92.74 ms | 64.60 / 104.42 ms | 4.95 / 4.92 ms |

Host variation is material. Concurrent background Java/Swift compilation was
observed during the third trial. **All trials are retained**, including that
contended trial. Their UI medians span:

| Document | Dart per-trial medians | Rust per-trial medians |
| --- | --- | --- |
| 3.2k | 1.11, 3.19, 3.11 ms | 0.78, 3.75, 3.40 ms |
| 43k | 6.34, 6.82, 23.91 ms | 6.69, 6.87, 23.37 ms |
| 435k | 74.66, 72.77, 240.63 ms | 64.60, 64.01, 284.74 ms |

The third 435k trial includes a 1,150 ms Dart UI outlier; the raw distribution
is preserved. These data are unsuitable for a precise universal Rust speedup
percentage or a phone FPS claim. The robust finding is that the 435k UI work
already exceeds the 60 Hz budget in the lighter-load trials, and raster work is
substantially smaller than UI work.

Content frames exceeding 16.67 ms UI time:

| Document | Dart | Rust |
| --- | ---: | ---: |
| 3.2k | 0 / 72 | 0 / 72 |
| 43k | 25 / 72 | 21 / 72 |
| 435k | **24 / 24** | **24 / 24** |

These are per-update frame-budget observations, not an observed dropped-frame
rate during scrolling or a claim that publications arrive at 60 Hz.

## What was measured

- The real `StreamMarkdown` widget receives identical chunks with the same
  inactive Thinking/Artifact/ToolCall registry, enhanced components, native
  highlighter, and committed-widget identity cache in both backends.
- The prefill uses the existing mixed section fixture, including headings,
  inline formatting, lists, tables, code, Chinese and emoji. Each publication
  adds a complete small paragraph. Actual parsed source ranges and native block
  retention match Dart at every publication, checked outside frame collection.
- Prefill and three warmup publications are excluded. The test records 24
  content updates at 3.2k/43k and eight at 435k, in each of three trials per
  backend: **336 content frames** overall.
- A render-object probe captures `Timeline.now` during content layout. Only
  engine `FrameTiming` records whose build interval contains that marker count.
  The expected content-frame count is asserted in every cell. Continuously
  scheduled idle frames from the live test binding and delayed timing batches
  are excluded, preventing artificially low averages.
- The next chunk arrives 90 ms after layout completes, above the existing
  50 ms throttle. This prevents publication merging in either backend. Results
  include the actual widget update, not merely an AST traversal stopwatch.
- Scroll position stays at the top in the existing `SingleChildScrollView` /
  full-document `Column` composition. There is no auto-scroll, scrolling FPS,
  cold-first-paint, image loading or physical-device acceptance in this probe.

## Rendering work still performed

`StreamMarkdown.build` scans the full result to build an identity set and prune
the committed-widget cache on each publication. `MarkdownRenderer.render`
still traverses all top-level nodes, constructs the full child/spacing lists
and returns a `Column`. Cached inner widgets avoid rebuilding their contents,
but do not make these whole-document passes or parent layout incremental.

Rust changes the parser and shared highlighting logic. Widget construction,
layout and rendering remain on Flutter. The measurements locate the dominant
stage on the UI thread; they do not separately assign percentages to the
eligibility scan, list construction, element updates and layout.

The next rendering work should target block-level lazy construction and local
updates/layout, preserving the current public API and scroll composition
contracts. This round only adds measurement tooling; production rendering
behavior is unchanged.

## Evidence and reproduction

- [All frame samples and matched layout timestamps](evidence/macos-profile-2026-11-20-render.json)
- [Three-trial summaries, ranges and budget counts](evidence/macos-render-2026-11-20-summary.json)
- Probe: `example/integration_test/render_performance_test.dart`.
- Accepted integration run passed, with exact content-frame counts and no
  Flutter errors. Focused static analysis has no errors or warnings.

```sh
cd example
flutter drive --profile --no-pub -d macos \
  --driver test_driver/core_performance_driver.dart \
  --target integration_test/render_performance_test.dart
```

This host uses the existing arm64-only `XCODE_XCCONFIG_FILE` workaround. The
driver writes `build/core-performance/profile-render.json` separately from
parser and RSS results. No result from an incomplete or failed selector probe
is included in the accepted evidence.
