# Native API map

Flutter is the behavior reference for the [iOS Swift package](https://github.com/JackCaow/ios-smooth-markdown) and [Android Compose library](https://github.com/JackCaow/android-smooth-markdown). The three APIs use their platform's naming and types, but aim to keep the same feature switches and default behavior. Use each native repository's README for installation.

| Task | Flutter | iOS | Android |
| --- | --- | --- | --- |
| Render a document | `SmoothMarkdown(data: text)` | `SmoothMarkdownView(markdown: text)` | `SmoothMarkdown(markdown = text)` |
| Render incoming chunks | `StreamMarkdown(stream: chunks)` | `StreamMarkdownView(chunks: chunks)` | `StreamMarkdown(chunks = chunks)` |
| Edit Markdown | `SmoothMarkdownEditor(data: text)` or pass a controller | Create `MarkdownEditorController`, then `SmoothMarkdownEditor(controller: controller)` | Create `MarkdownEditorController`, then `SmoothMarkdownEditor(controller = controller)` |
| Choose a theme | `styleSheet` | `styleSheet` | `styleSheet` |
| Enhanced headings, quotes and code | `useEnhancedComponents` | `useEnhancedComponents` | `useEnhancedComponents` |
| Native text selection | `selectable` | `selectable` | `selectable` |
| Custom parsed nodes | `plugins`, `builderRegistry` | `plugins`, `builderRegistry` | `plugins`, `builderRegistry` |

The document and stream readers default to standard components (`useEnhancedComponents: false`), HTML off, and selection off. The editors default to enhanced preview components. All three readers expose link and image tap callbacks. Flutter passes a link URL string through `onTapLink`; iOS accepts the same string callback and retains its native `onLinkTap(URL)` callback, while Android uses `onLinkClick` with a string. Flutter and iOS accept `onTapImage(source, alt, title)`; Android exposes the same payload through `onImageClickWithMetadata`. Reader caching is on by default; streaming bypasses the document cache.

## Differences to handle explicitly

- Flutter groups parser switches in `MarkdownConfig`. Native libraries currently expose selected switches directly rather than a matching configuration object.
- Flutter's `MarkdownConfig.enableLatex` defaults to `false`. The current native readers render supported math by default. Set the Flutter option explicitly when comparing the same document; a future native config change should include a migration path.
- Flutter's editor starts in Formatted mode. Native `MarkdownEditorController` instances start in Source mode; set `controller.mode = .formatted` on iOS or `controller.mode = MarkdownEditorMode.FORMATTED` on Android before presenting the editor when matching Flutter's first screen.
- iOS retains its older URL-based tap callback alongside the string alias. If both are supplied, both run; avoid registering the same action twice.
- iOS and Android streaming readers expose an `onComplete` callback for finite sources. A hot Android `StateFlow` does not normally complete, so it will not call `onComplete`.
- A custom builder or plugin can create a separate native selection surface. Do not assume selection spans every custom renderer on every platform.
- The Android module is currently consumed from source; a published Maven coordinate is not available yet. The iOS package has no version tag yet, so shipped apps should pin a commit.

When adding a shared feature, update the corresponding reader and stream entry points together, add the same behavior to each platform's Demo, and verify the synchronized Flutter example fixtures. Keep differences in defaults or callback payloads visible here until they are resolved.
