# react-native-enriched-markdown

> **OpenEvidence fork** of [`software-mansion-labs/react-native-enriched-markdown`](https://github.com/software-mansion-labs/react-native-enriched-markdown).

A React Native library that renders Markdown content as native text and provides a rich text input with Markdown output. Supports iOS, Android, macOS, and Web. Requires the New Architecture (Fabric) for native platforms.

## Changes in this fork

- **Citation chips** — inline `[[numbers|label|faviconUrl]]` syntax rendered as styled chips with favicons and grouped count suffixes, with an `onCitationPress` callback
- **Tail fade-in streaming animation** — new text appended during streaming fades in at word-level granularity with smoothstep easing over 600ms
- **Display math (CommonMark)** — block-level LaTeX (`$$...$$`) now renders in the CommonMark flavor path (previously GitHub-only)
- **Android touch handling fix** — links and citations correctly respond to taps even when parent views intercept `ACTION_CANCEL`; scroll and drawer gestures are preserved for plain-text areas

## Features

### EnrichedMarkdownText

- Fully native text rendering (no WebView)
- Web support via [react-native-web](https://necolas.github.io/react-native-web/) + [md4c](https://github.com/mity/md4c) compiled to WebAssembly
- High-performance Markdown parsing with [md4c](https://github.com/mity/md4c)
- CommonMark standard compliant
- GitHub Flavored Markdown (GFM)
- LaTeX math rendering (block `$$...$$` in both flavors, inline `$...$` in all flavors)
- [Markdown Streaming](docs/MARKDOWN_STREAMING.md) support (via [react-native-streamdown](https://github.com/software-mansion-labs/react-native-streamdown))
- Fully customizable styles for all elements
- Text selection and copy support
- Custom text selection context menu items
- Interactive link handling
- Citation chips with favicons, labels, and grouped counts
- Spoiler text with animated particle overlay and tap-to-reveal
- Native image interactions (iOS: Copy, Save to Camera Roll)
- Native platform features (Translate, Look Up, Search Web, Share)
- Accessibility support (VoiceOver on iOS, TalkBack on Android, semantic HTML on web)
- Full RTL (right-to-left) support including text, lists, blockquotes, tables, and task lists

### EnrichedMarkdownInput

- Rich text input with Markdown output
- Imperative API for toggling styles and managing links
- Native context menu with formatting submenu
- Real-time style state detection
- Auto-link detection with customizable regex
- Smart copy/paste with Markdown preservation
- Customizable bold, italic, and link colors

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [EnrichedMarkdownText](#enrichedmarkdowntext-1)
  - [Usage](docs/TEXT.md#usage)
  - [Supported Markdown Elements](docs/TEXT.md#supported-markdown-elements)
  - [Copy Options](docs/TEXT.md#copy-options)
  - [Accessibility](docs/TEXT.md#accessibility)
  - [RTL Support](docs/TEXT.md#rtl-support)
  - [Customizing Styles](docs/TEXT.md#customizing-styles)
  - [LaTeX Math](docs/LATEX_MATH.md)
  - [Image Caching](docs/IMAGE_CACHING.md)
  - [Markdown Streaming](docs/MARKDOWN_STREAMING.md)
- [EnrichedMarkdownInput](#enrichedmarkdowninput-1)
  - [Usage](docs/INPUT.md#usage)
  - [Inline Styles](docs/INPUT.md#inline-styles)
  - [Links](docs/INPUT.md#links)
  - [Auto-Link Detection](docs/INPUT.md#auto-link-detection)
  - [Style Detection](docs/INPUT.md#style-detection)
  - [Other Events](docs/INPUT.md#other-events)
  - [Customizing Styles](docs/INPUT.md#customizing-enrichedmarkdowninput--styles)
- [API Reference](#api-reference)
- [Web Support](docs/WEB.md)
- [macOS Support](docs/MACOS.md)

## Prerequisites

**Native (iOS / Android / macOS)**

- Requires [the React Native New Architecture (Fabric)](https://reactnative.dev/architecture/landing-page)
- Supported React Native releases: `0.81`, `0.82`, `0.83`, and `0.84`
- macOS support via [react-native-macos](https://github.com/microsoft/react-native-macos) `0.81+`

**Web**

- Requires [`react-native-web`](https://necolas.github.io/react-native-web/) and Metro (or another bundler with `.web.tsx` platform resolution)
- No New Architecture requirement — the web renderer runs entirely in JavaScript via WebAssembly
- Only `EnrichedMarkdownText` is supported on web (`EnrichedMarkdownInput` is native-only)
- LaTeX math requires the optional [`katex`](https://katex.org/) peer dependency

## Installation

### Web

No steps beyond having `react-native-web` configured. For LaTeX math, install the optional peer dependency:

```sh
npm install katex
# or
yarn add katex
```

See [Web Support](docs/WEB.md) for full setup details, supported features, and prop behaviour.

### Bare React Native app (iOS / Android)

#### 1. Install the library

Point your package manager at this fork's repository or a local path as appropriate for your setup.

#### 2. Install iOS / macOS dependencies

The library includes native code so you will need to re-build the native app.

```sh
# iOS
cd ios && bundle install && bundle exec pod install

# macOS (react-native-macos)
cd macos && bundle install && bundle exec pod install
```

### Expo app

#### 1. Install the library

```sh
npx expo install react-native-enriched-markdown
```

#### 2. Run prebuild

```sh
npx expo prebuild
```

> [!NOTE]
> The library won't work in Expo Go as it needs native changes.

> [!IMPORTANT]
> **iOS: Save to Camera Roll**
>
> If your Markdown content includes images and you want users to save them to their photo library, add the following to your `Info.plist`:
>
> ```xml
> <key>NSPhotoLibraryAddUsageDescription</key>
> <string>This app needs access to your photo library to save images.</string>
> ```

## EnrichedMarkdownText

See [EnrichedMarkdownText](docs/TEXT.md) for detailed documentation on usage examples, GFM tables, task lists, link handling, supported elements, copy options, accessibility, RTL support, and customizing styles.

## EnrichedMarkdownInput

See [EnrichedMarkdownInput](docs/INPUT.md) for detailed documentation on usage examples, inline styles, links, style detection, events, and customizing styles.

## API Reference

See the [API Reference](docs/API_REFERENCE.md) for a detailed overview of all the props, methods, and events available.

## Web Support

See [Web Support](docs/WEB.md) for details on supported features, web-specific prop behaviour, and known limitations.

## macOS Support

`react-native-enriched-markdown` supports macOS via [react-native-macos](https://github.com/microsoft/react-native-macos). See [macOS Support](docs/MACOS.md) for details on macOS-specific features, known limitations, and the example app.

## License

`react-native-enriched-markdown` is licensed under [The MIT License](./LICENSE).

---

Upstream library by [Software Mansion](https://swmansion.com/). 