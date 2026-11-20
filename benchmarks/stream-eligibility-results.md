# Streaming compatibility checks and render frames, 20 November 2026

`StreamMarkdown` now carries its compatibility decision forward on both parser backends. When text arrives, it scans the newly completed lines, updates the unfinished delimiter, and checks for plugin markers spanning the publication boundary. The public constructors, parser selection and callback contracts are unchanged.

## Compatibility at publication boundaries

- A two-column header followed by the partial delimiter `| --- |` takes the batch path immediately. Appending ` :---: |` on the same line restores the two-column match and the incremental path. A newline after the one-column delimiter commits the mismatch.
- Closed lines share the batch table scanner. An open delimiter retains its grammar state and preceding header width. This also covers an append that closes several lines at once. Header trimming and delimiter whitespace follow the existing parser rules.
- Built-in markers use the appended suffix and up to 20 preceding UTF-16 units. The gate uses the same case folding and literals as the full check. A split `<|Th` + `In` + `K` activates the original plugin path as soon as its marker matches. Changing the plugin list rechecks prior text. Registry subclasses retain the original full check and getter access order.
- A replacement stream or a change to HTML mode resets the gate. Restoring incremental eligibility starts a fresh parser session when a previous publication used the batch path.

## 435,200-unit document with 16-unit appends

Each Profile run measures both backends, the full and incremental checks, and the paged box and sliver layouts in the same process. Each of the eight timed appends reparsed 46 units and retained 8,001 to 8,008 blocks on both backends. The fixture contains tables and uses the same three inactive AI plugins and native highlighter in every cell. The view stays at the top; the appended paragraph is offscreen. Prefill and three warmup updates are excluded.

Stage values are medians of eight trial medians (eight appends per trial). Frame values use the same eight-sample order statistic as the earlier rendering report, then the median of four trials. The control uses the same production widget and layout with a registry subclass that inherits every getter and selects the full check. Backend, layout and check order are counterbalanced. The macOS run contributes 256 content frames and 256 separate stage samples.

### macOS Profile

| Backend | Check, full → incremental (µs) | Paged UI (ms) | Sliver UI (ms) | Paged raster (ms) | Paged total span (ms) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Dart | 1,656.41 → 0.65 | 3.72 → 1.64 | 5.93 → 1.79 | 1.95 → 1.90 | 5.88 → 3.58 |
| Rust | 1,657.72 → 0.64 | 3.40 → 1.40 | 5.62 → 1.34 | 1.89 → 1.91 | 5.50 → 3.53 |

The check runs in shared Dart code. Its sub-microsecond difference between backends is below the precision useful for comparing implementations. In the incremental condition the separate parser session call took 405 µs for Dart and 331 µs for Rust. Stage and frame samples are collected separately. The fourth Dart box trial was unusually slow with both gates (16.29 ms full, 11.79 ms incremental). All samples are included. [Raw macOS tail samples](evidence/macos-profile-2026-11-20-stream-eligibility.json)

### Android Profile on 25019PNF3C

The physical Android 17 device (1080 × 2400 pixels at DPR 2.8125) reported an input-dispatch ANR during the initial single-publication box prefill. The OS recorded a touch waiting 5,000 ms. No append timings from that attempt are included. The first connection had also been interrupted during startup. Both measured Android layouts use 32 prefill publications of 13,600 units, then the same warmups, 16-unit appends and eight-sample frame statistics as the Mac test. Android runs two counterbalanced frame trials per cell in each layout process. Each layout contributes 64 actual update frames. The **check** microbenchmark still uses the original full prefill and eight trials. [Android ANR exit record](evidence/android-2026-11-20-cold-prefill-anr.txt)

| Layout | Backend | Check, full → incremental (µs) | UI (ms) | Raster (ms) | Total span (ms) |
| --- | --- | ---: | ---: | ---: | ---: |
| Default paged box | Dart | 2,745.90 → 0.85 | 7.68 → 4.31 | 3.84 → 3.73 | 12.05 → 8.32 |
| Default paged box | Rust | 2,739.02 → 1.07 | 7.19 → 3.92 | 3.92 → 3.97 | 11.79 → 8.25 |
| Sliver | Dart | 2,525.39 → 0.78 | 13.24 → 2.56 | 0.84 → 0.85 | 14.90 → 3.65 |
| Sliver | Rust | 2,517.70 → 0.85 | 9.50 → 2.80 | 0.85 → 0.83 | 10.78 → 3.95 |

In the default box, each full-check backend had 2/16 update frames above 16.67 ms total span. Both incremental cells had 0/16. The incremental sliver cells also had 0/16. The default box's post-change total-span medians differ by 0.08 ms. The sliver's full-check Rust UI medians ranged from 5.94 to 13.06 ms across the two trials. The original installed example APK was backed up before testing and its on-device SHA-256 verified after restoration. [Default box raw samples](evidence/android-profile-2026-11-20-eligibility-paged.json) · [Sliver raw samples](evidence/android-profile-2026-11-20-eligibility-sliver.json)

### Android repeat with physical input

On the same phone, both initial rerun APKs had the same SHA-256 as round one. Sliver completed all 64 update frames with user input. Its incremental total-span medians were 6.54 ms for Dart and 6.90 ms for Rust (0/16 above 16.67 ms in each cell). The default box reproduced an input-dispatch ANR at 13:38:11 SGT during the first default-box cell. The original target did not timestamp the individual prefill and warmup boundaries. Android recorded a MOVE event waiting 5,000 ms and terminated the process. No complete default-box cell from this attempt was available. [Same-APK Sliver samples](evidence/android-profile-2026-11-20-eligibility-sliver-round2.json)

The main-thread sample was in `WidgetTester.dispatchEvent`, evaluating `find.byElementType(...).evaluate().length` for a real touch. Flutter's live widget-test handler traverses the mounted element tree to suggest finders. The application logged finder suggestions before the timeout. Symbolization matched the installed Dart AOT build ID and all 4,542,992 bytes of its `.text` section. This identifies the blocking code in this ANR. The earlier single-prefill ANR has only an exit record. [Android exit record and symbolized stack](evidence/android-2026-11-20-paged-round2-anr.txt)

The frame benchmark now routes physical pointer events to Flutter's gesture system. The optional `--dart-define=VERIFY_DEVICE_SCROLL=true` probe waits for an actual drag after the 435,200-unit prefill, records its offset, returns to the top, then runs the original warmups and eight timed appends. Each measured frame records the viewport offset. Isolated stage timing yields to the event loop between independent sessions, outside the timed intervals. The reader and parser code are unchanged in this repeat.

After the harness fix, both layouts completed all 64 update frames and handled a real upward swipe on the fully prefilled document. Measured offsets confirmed the scroll (149.6 logical pixels in the box, 19.2 in Sliver). There were no finder suggestions and Android's last ANR timestamp remained at the earlier failed attempt. Android still reported skipped vsyncs during preparation; the append numbers exclude startup. The original installed APK was restored and its on-device SHA-256 verified.

| Layout | Backend | Incremental check (µs) | UI with incremental check (ms) | Total span, full → incremental (ms) | Prior round incremental span (ms) |
| --- | --- | ---: | ---: | ---: | ---: |
| Default paged box | Dart | 0.78 | 4.14 | 11.61 → 8.90 | 8.32 |
| Default paged box | Rust | 0.81 | 3.86 | 11.66 → 8.23 | 8.25 |
| Sliver | Dart | 0.98 | 5.69 | 16.80 → 7.39 | 3.65 |
| Sliver | Rust | 1.08 | 3.87 | 16.78 → 5.21 | 3.95 |

The box comparison uses only trial 2 (eight frames per backend and check), where all four cells stayed at the top. All eight frames in the first Dart incremental cell were collected while the viewport moved; that cell's median total span was 9.09 ms and one frame exceeded 16.67 ms. It remains in the raw record. Both Sliver trials stayed at the top (16 frames per cell). In the stationary incremental cells summarized above, no measured total span exceeded 16.67 ms. The first-round column uses two trials per layout. [Box samples and offsets](evidence/android-profile-2026-11-20-eligibility-paged-round2-touch.json) · [Sliver samples and offsets](evidence/android-profile-2026-11-20-eligibility-sliver-round2-touch.json)

### iPhone 17 Profile

A physical iPhone 17 running iOS 27.2.1 used the same 435,200 UTF-16 units, 32 prefill publications and 16-unit appends as the staged Android test. Each layout process recorded 64 content-update frames in two counterbalanced trials. In both processes all recorded scroll offsets were zero. The accepted runs disabled the optional device-drag check at compile time. An earlier run timed out waiting for input and contributed no frame samples.

| Layout | Backend | Staged prefill wall time (s) | Incremental check (µs) | Incremental parser session (µs) | UI (ms) | Total frame span (ms) |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Default box | Dart | 8.10 | 0.500 | 387 | 1.70 | 3.26 |
| Default box | Rust | 8.23 | 0.469 | 310 | 1.85 | 6.23 |
| Sliver | Dart | 3.30 | 0.542 | 467 | 2.63 | 3.01 |
| Sliver | Rust | 3.28 | 0.542 | 355 | 2.44 | 2.98 |

Prefill times are the medians of the two incremental-check trials, including 32 intentional 90 ms waits. The box mounts every layout page inside its parent scroll view. The Sliver mounts pages within the viewport and its cache extent. With the same source and pacing, the Sliver reduced prefill wall time by about 60% on both backends. The difference also includes scheduling and other work outside measured frames. The timed appends reparsed 46 UTF-16 units each. Full compatibility checks ranged from 1.26 to 1.48 ms across the four cells. None of the 128 measured update frames exceeded 16.67 ms. Stage timings and frames were collected separately. [Default box samples](evidence/ios-profile-2026-11-20-paged.json) · [Sliver samples](evidence/ios-profile-2026-11-20-sliver.json)

## Growing from empty to 435,200 units

The second macOS Profile test delivers 1,600 complete 272-unit Markdown sections per cell through the public `StreamMarkdown` widget, using its default paged box. Each send waits for the preceding content frame, with the widget's own 50 ms throttle. It includes the first publication, growth in table and code blocks, and all updates up to 435,200 units. Each backend runs one full and one incremental sequence. Each cell starts a fresh process from the same application binary. The stage probe times the two checks separately on each prefix and verifies identical parser ranges and retained blocks at all 1,600 publications. No stage clocks run inside the measured frames.

UI time is the engine's `FrameTiming.buildDuration`. It includes eligibility, parsing, widget updates, layout, paint preparation and scene submission. Raster time is the engine's raster-thread interval. Total span is `FrameTiming.totalSpan`, measured from vsync start to raster finish. Stream buffering and throttle waiting precede the frame. Neither test scrolls the viewport.

| Backend | Median check per publication, full → incremental (µs) | Sum of 1,600 checks (ms) | UI median (ms) | Raster median (ms) | Total span median (ms) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Dart | 852.68 → 1.65 | 1,356.00 → 3.23 | 9.76 → 1.88 | 5.34 → 1.44 | 94.16 → 4.94 |
| Rust | 863.59 → 1.67 | 1,410.05 → 2.96 | 2.67 → 2.24 | 1.52 → 1.80 | 7.04 → 44.21 |

Each of the four fresh processes measured both checks for both backends on the same prefixes outside the frames, alternating which check ran first. The table reports the median of the four sequence medians and the median of the four sequence sums. Each frame column summarizes all 1,600 publications in **one** process per backend/check combination. The accepted process order was Dart incremental, Rust incremental, Rust full, Dart full. The same compiled binary produced all 6,400 content frames. An earlier combined run hit its overall 12-minute timeout. One separate Rust full attempt lost its driver connection before completion. Neither contributes any samples here.

Across these sequences, the gate saves more than 99% of measured check time. **Whole-frame spans vary considerably.** Rust's UI median fell from 2.67 to 2.24 ms while its measured total-span median rose from 7.04 to 44.21 ms. Under the incremental check, 612/1,600 Dart frames and 949/1,600 Rust frames exceeded 16.67 ms total. In the last 200 publications, median UI / total were 2.67 / 69.94 ms for Dart and 9.01 / 123.12 ms for Rust. Subtracting each frame's actual build and raster durations from its span left last-200 medians of 61.52 and 98.19 ms, respectively. These clocks combine waiting before UI work and the gap before raster; they cannot identify the source of that delay. The desktop remained in use, and the accepted Rust full run briefly overlapped the Android builds. With one frame sequence per cell, the large cross-run frame differences do not establish a causal speedup or slowdown from the shared check or a stable backend ranking. [All growth check samples, frame durations and build fingerprint](evidence/macos-profile-2026-11-20-sustained-render-eligibility.json)

## Verification and reproduction

The differential tests compare the incremental decision with the full check on each prefix. They exercise every split of each marker, Unicode case folding, 600 generated documents, mutable registries and overridden getters. Public-widget tests exercise both Dart and native Rust, including switching routes as a delimiter changes, opening a thinking block, replacing a stream and toggling HTML. All 11 focused VM tests and all five browser differential tests passed. The full Flutter suite finished with 1,189 passing tests and the three existing Mermaid golden mismatches. The five example tests passed. The Web preview and its Wasm dry run built successfully. The Dart analyzer reported 305 info diagnostics and zero errors or warnings.

Run each command from `example/`. On the measured M4 host, `XCODE_XCCONFIG_FILE` points to a temporary config containing `ARCHS = arm64` and `ONLY_ACTIVE_ARCH = YES`.

```sh
flutter drive --profile --no-pub -d macos --driver test_driver/core_performance_driver.dart --target integration_test/stream_eligibility_performance_test.dart
target=integration_test/sustained_render_eligibility_test.dart
flutter build macos --profile --no-pub -t "$target"
for cell in dart-incremental rust-incremental rust-full dart-full; do
  SMOOTH_RENDER_CELL="$cell" flutter drive --profile --no-pub -d macos \
    --use-application-binary build/macos/Build/Products/Profile/flutter_smooth_markdown_example.app \
    --driver test_driver/core_performance_driver.dart --target "$target"
done
```

The Android frame target is `integration_test/android_stream_eligibility_test.dart`. Build its Profile APK for `android-arm64` with `--dart-define=RENDER_LAYOUT=sliver` or `--dart-define=RENDER_LAYOUT=paged`, then run that APK with the same driver, `-d DEVICE_ID`, `--profile`, `--keep-app-running` and `--use-application-binary build/app/outputs/flutter-apk/app-profile.apk`. It uses the example package ID. The accepted device runs used a backed-up example installation.
