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

The document and stream readers default to standard components (`useEnhancedComponents: false`), HTML off, and selection off. The editors default to enhanced preview components. All three readers expose link and image tap callbacks; callback names and URL types differ by platform. Flutter passes a link URL string through `onTapLink`; Android uses `onLinkClick` with a string, while iOS has a native `URL` callback named `onLinkTap`. Image callbacks can provide source, alt text and title in all three libraries. Reader caching is on by default; streaming bypasses the document cache.

## Differences to handle explicitly

- Flutter groups parser switches in `MarkdownConfig`. Native libraries currently expose selected switches directly rather than a matching configuration object.
- Flutter's `MarkdownConfig.enableLatex` defaults to `false`. The current native readers render supported math by default. Set the Flutter option explicitly when comparing the same document; a future native config change should include a migration path.
- Flutter's `onTapLink` uses a string. The native callback type may be a platform URL type; convert at the application boundary if sharing business logic.
- A custom builder or plugin can create a separate native selection surface. Do not assume selection spans every custom renderer on every platform.
- The Android module is currently consumed from source; a published Maven coordinate is not available yet. The iOS package has no version tag yet, so shipped apps should pin a commit.

When adding a shared feature, update the corresponding reader and stream entry points together, add the same behavior to each platform's Demo, and verify the synchronized Flutter example fixtures. Keep differences in defaults or callback payloads visible here until they are resolved.
