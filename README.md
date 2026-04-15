# react-native-enriched-markdown

> **OpenEvidence fork** of [`software-mansion-labs/react-native-enriched-markdown`](https://github.com/software-mansion-labs/react-native-enriched-markdown). For feature documentation, installation details, API reference, and supported elements, see the [upstream README](https://github.com/software-mansion-labs/react-native-enriched-markdown#readme) and the [docs/](docs/) directory.

## Fork Changes

- **Citation chips** — `[[numbers|label|faviconUrl]]` rendered as styled pill chips with async favicon loading
- **Tail fade-in streaming animation** — canvas overlay approach on both platforms (600ms smoothstep)
- **Display math (CommonMark)** — `$$...$$` block math in the single-view rendering path
- **Android touch handling** — gesture arbitration between links/citations, scroll, and drawer

## Architecture

### Parsing (C++)

All platforms share a single C++ parser (`cpp/parser/MD4CParser.cpp`) built on [md4c](https://github.com/mity/md4c). The parser produces an AST of `MarkdownASTNode` structs (`cpp/parser/MarkdownASTNode.hpp`). Two post-processing passes run after md4c:

1. **Citation extraction** — walks text nodes looking for `[[...]]` patterns, splits them into `Text` + `Citation` AST nodes with `numbers`, `label`, and `faviconUrl` attributes.
2. **Display math promotion** — promotes `LatexMathDisplay` nodes out of wrapping paragraphs so renderers see them as block-level elements.

### React Native Layer (TypeScript)

**`EnrichedMarkdownText`** (`src/native/EnrichedMarkdownText.tsx`) is the main component. It normalizes styles via an LRU cache (`normalizeMarkdownStyle.ts`), memoizes callbacks, and delegates to one of two native components depending on the `flavor` prop (CommonMark vs GitHub).

**`EnrichedMarkdownWithComponents`** (`src/EnrichedMarkdownWithComponents.tsx`) supports embedding arbitrary React components inside markdown. The host app wraps component data in `` ```REACTCOMPONENT `` code fences. `splitMarkdownSegments.ts` splits the markdown string on these fences and produces alternating `{ type: "markdown", content }` and `{ type: "component", name, props }` segments. Each markdown segment renders as its own `EnrichedMarkdownText`; each component segment renders via a registered component from a `ComponentRegistry`.

**Two native component specs** exist (`EnrichedMarkdownNativeComponent.ts` for GitHub flavor, `EnrichedMarkdownTextNativeComponent.ts` for CommonMark) with identical interfaces — required by React Native codegen for separate native view registrations.

### iOS (Objective-C / Objective-C++)

**Text view:** `EnrichedMarkdownText.mm` is a Fabric component that owns a `UITextView`. Markdown is parsed on a serial dispatch queue, rendered to `NSMutableAttributedString` by the renderer pipeline, and applied on the main thread.

**Rendering:** `RendererFactory.m` maps AST node types to renderer classes. Each renderer (`ParagraphRenderer`, `HeadingRenderer`, `CitationRenderer`, etc.) appends styled attributed string ranges to a shared `NSMutableAttributedString`. The `TextViewLayoutManager.mm` subclass of `NSLayoutManager` draws custom backgrounds (code blocks, blockquotes) in `drawBackgroundForGlyphRange:`.

**Citation chips:** `CitationChipAttachment` is an `NSTextAttachment` subclass. It draws the chip (pill background, circular favicon, label) via CoreGraphics in `imageForBounds:textContainer:characterIndex:`. Chip images are cached globally by `NSCache`. Favicons are loaded asynchronously via `NSURLSession` and cached separately; on completion, `invalidateDisplayForCharacterRange:` triggers a re-composite without relayout.

**Streaming animation:** `ENRMTailFadeInAnimator` uses a canvas overlay approach. A transparent `ENRMFadeOverlayView` is added as a subview of the text view. On each `CADisplayLink` frame, the overlay's `drawRect:` uses `NSLayoutManager` line fragment enumeration to compute per-line rectangles for each active fade group, filling them with the resolved background color at a fading alpha (smoothstep easing). Text is always rendered at full opacity — the overlay simply covers and reveals it. This avoids any `NSTextStorage` mutations during animation.

**Spoiler text:** `ENRMSpoilerOverlayManager` adds per-span `ENRMSpoilerOverlayView` subviews on top of the text view, with particle or solid animation modes.

### Android (Kotlin)

**Text view:** `EnrichedMarkdownText.kt` extends `AppCompatTextView`. Parsing and rendering run on a dedicated `Executor`; the result is posted to the main thread via `Handler`. Text is set with `BufferType.EDITABLE` so the buffer implements `Spannable` (required for `LinkLongPressMovementMethod`).

**Rendering:** `RendererFactory` (`renderer/NodeRenderer.kt`) maps AST node types to `NodeRenderer` implementations. Renderers append to a `SpannableStringBuilder` and apply Android spans. Math renderers (`MathInlineRenderer`, `MathDisplayRenderer`) are loaded via reflection from the optional `math` source set to keep the math dependency (`MTMathView`) out of the main build.

**Citation chips:** `CitationChipSpan` is a `ReplacementSpan`. It draws the chip directly on the `Canvas` — rounded rect background, circular favicon via `BitmapShader`, label text. Colors and font size are pulled from `SpanStyleCache` (which reads the JS `citationStyle` config) with hardcoded defaults as fallback. Favicons load asynchronously via `ImageDownloader`; on completion, the span re-seats itself on the `Editable` text (`removeSpan` + `setSpan`) to trigger `DynamicLayout`'s `SpanWatcher`, forcing a redraw.

**Streaming animation:** `TailFadeInAnimator` draws background-colored rectangles over new text in `onDraw` (called after `super.onDraw()`). Each frame, `Choreographer.FrameCallback` triggers `invalidate()`. The overlay color is resolved by walking the view hierarchy via `SpoilerDrawContext.resolveBackgroundColor`, which uses React Native's `BackgroundStyleApplicator` to extract colors from RN's `CompositeBackgroundDrawable`. The cached color resets on configuration changes (dark/light mode).

**Touch handling:** `dispatchTouchEvent` checks whether `ACTION_DOWN` lands on an interactive span (`LinkSpan` or `CitationChipSpan`) via shared `charOffsetAt`/`isInteractiveOffset` extensions (`TouchUtils.kt`). Only interactive hits call `requestDisallowInterceptTouchEvent(true)`; plain-text touches allow parent scroll/drawer gestures. `LinkLongPressMovementMethod` handles link long-press, citation tap dispatch, and spoiler reveal.

---

Upstream library by [Software Mansion](https://swmansion.com/).
