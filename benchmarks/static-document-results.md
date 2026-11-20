# Opening and scrolling a 435k static Markdown file on iPhone

On an iPhone 17 running iOS 27.2.1, the first heading of a 435,200-unit document was rasterized in **52 ms with Dart and 64 ms with Rust** using `SmoothMarkdown.sliver`. The eager box needed **749 ms and 731 ms** respectively. Both sliver runs mounted 15 of the 8,000 top-level blocks at the top. After scrolling 2,400 logical pixels, 18 blocks were mounted and the original first render box was detached. [Raw samples](evidence/ios-static-435k-profile.json)

| Backend and layout | First visible content, ms | Full document index on screen, ms | Process RSS after first content, MiB | Process RSS after scrolling, MiB |
| --- | ---: | ---: | ---: | ---: |
| Dart box | 748.63 | 748.63 | 891.7 | 891.8 |
| Dart sliver | 51.92 | 78.50 | 144.8 | 151.8 |
| Rust box | 730.85 | 730.85 | 902.6 | 904.1 |
| Rust sliver | 63.62 | 95.23 | 146.8 | 164.9 |

The first preview exposed an index of 73 blocks on both backends. The background parse then replaced it with an 8,000-block index. The measured viewport was 874 logical pixels tall. The live children ranged from indices 0–14 to 27–44, including Flutter's scroll cache. A reference to the original first child confirmed `attached == false` at the end. RSS measures the full process, including engine and native allocations.

| Backend and layout | Scroll frames | UI p95 / max, ms | Raster p95 / max, ms | Total span p95 / max, ms |
| --- | ---: | ---: | ---: | ---: |
| Dart box | 193 | 3.59 / 4.16 | 1.90 / 2.67 | 4.76 / 7.96 |
| Dart sliver | 191 | 1.39 / 2.29 | 1.56 / 2.45 | 2.31 / 3.80 |
| Rust box | 193 | 2.99 / 3.62 | 1.70 / 2.05 | 3.91 / 4.95 |
| Rust sliver | 193 | 1.23 / 2.83 | 1.76 / 2.21 | 2.37 / 3.83 |

## Measurement

Each cell ran once in a fresh process of the same signed Flutter Profile binary. The order was Dart box, Rust sliver, Dart sliver, Rust box. A preparation screen warmed the Flutter engine and the parse cache was cleared before opening the document. Open time starts when the app replaces that screen. The clock stops at the engine's raster-finish timestamp for the frame containing a visible `Shared` heading. The second clock stops at the frame exposing the complete index. App launch and display presentation latency are outside these intervals.

All cells use an identical document containing 1,600 copies of the same 272-UTF-16-unit section with a heading, paragraph, list, table and fenced code. Both constructors use enhanced rendering, the specified parser backend and the default selection setting. After the full index is available, the benchmark drives a linear 0–2,400 logical-pixel scroll over 1.6 seconds using vsync ticks. Every cell reached 2,400. The scroll numbers use engine frame timings for that interval and nearest-rank p95. They describe a deterministic scroll, without finger input or fling physics.

The worst adjacent raster-finish gap was 23.43 ms in the Dart sliver run on the 120 Hz display. Frame computation time alone does not capture every missed refresh. One cold open per cell supports a layout comparison on this input. Parser rankings, performance on a single giant paragraph or table, and full-document selection require separate measurements.

## Reproduce

Build the [profile entry point](../example/integration_test/static_document_profile.dart) from `example/` with `flutter build ios --profile --target=integration_test/static_document_profile.dart`. Install the signed app on the device. For each cell, write its name to `Documents/static-cell.txt` in the app's data container, terminate the previous process and launch the same app. Collect `Documents/static-<cell>.json` once its stage reaches `complete`. The four names are `box-dart`, `sliver-rust`, `sliver-dart` and `box-rust`. A single-cell build can also set `--dart-define=STATIC_CELL=<cell>` in a container without a cell-selection file.
