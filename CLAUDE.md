# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build (always target an iOS Simulator by id — the default "My Mac"
# destination fails on provisioning, and "iPhone 17" is ambiguous because
# multiple simulators share that name). List devices with `xcrun simctl list`.
xcodebuild -project HNReader.xcodeproj -scheme HNReader -configuration Debug \
  -destination 'id=742C3D66-151C-436F-B54F-2A5E1D80702E' build
```

**Do not run the test suite.** The `HNReaderTests` target has pre-existing
compile failures (missing symbols, references to non-existent assertions like
`XCTAssertGreater`) that are unrelated to any feature work. Running tests will
report failures that don't reflect the change you made. Verify changes by
building the app target only.

Deployment target: **iOS 26.2**. No CocoaPods, SPM packages, or Fastlane — pure Xcode project.

## Architecture

**Pattern:** MVVM with Swift Concurrency (actors + async/await) and Combine for reactive bindings.

**Layer breakdown:**

- `Services/` — actor-based singletons. All are thread-safe via Swift actors; never call them from `@MainActor` contexts synchronously. Key ones:
  - `HackerNewsAPI` — fetches from Firebase HN API. Max 10 parallel requests, max comment depth 5.
  - `CacheManager` — file-based cache in `Documents/hn_cache/`, 24h expiry. Also persists scroll position and current page to UserDefaults.
  - `WebViewPreloader` — LRU pool of up to 5 `WKWebView` instances; responds to memory warnings by evicting all but the active view.
  - `SocialImageExtractor` — parses HTML meta tags for `og:image` → `twitter:image` → `link[rel=image_src]` → favicon fallback chain.

- `ViewModels/` — `@MainActor` `ObservableObject` classes with `@Published` properties. ViewModels coordinate between Services and Views.
  - `StoryFeedViewModel` uses cache-first loading: serves cached stories immediately, then fetches fresh in background.
  - `CommentsViewModel` builds a `CommentNode` tree from flat `[Comment]` arrays, grouping by `parent` ID.

- `Views/` — UIKit (UIViewController, UICollectionView, UITableView). Views subscribe to ViewModel publishers via Combine `sink`. No SwiftUI.

- `AppTheme.swift` — single source of truth for all colours, metrics (spacing constants), and typography. Always use `AppTheme.Colors`, `AppTheme.Metrics`, and `AppTheme.Typography` rather than raw values.

## Key design decisions to know

**Comment tree:** `CommentsViewModel` fetches comments as a flat array, then organises them into a `[CommentNode]` tree (each node has `children: [CommentNode]` and `isCollapsed: Bool`). `CommentsViewController` uses `CommentTreeFlattener` to flatten the tree back to a list for `UITableView` display, with depth tracked for indentation.

**iPad layout:** `StoryFeedViewController.createLayout(for:)` uses `UICollectionViewCompositionalLayout` with a closure that checks `environment.container.effectiveContentSize.width > 700` to switch between 1-column (iPhone/split-view iPad) and 2-column (full-screen iPad) grids. `StoryCell` overrides `preferredLayoutAttributesFitting` with `systemLayoutSizeFitting(...horizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)` to ensure correct self-sizing at any column width.

**Offline mode:** `StoryFeedViewModel.downloadForOffline()` fetches all stories, comments, and pre-renders articles via `WebViewPreloader.preloadForOffline`. Progress is tracked via `downloadProgress: (completed: Int, total: Int)` published to the `OfflineButton`.

**HTML rendering:** `HTMLTextExtractor` (in `StoryCell.swift`) strips tags and decodes entities including numeric `&#123;`/`&#xABC;` forms. `CommentCell` and `StoryCell` both use it for comment previews.

**Memory management:** `AppDelegate` hooks `UIApplication.didReceiveMemoryWarningNotification` and calls `WebViewPreloader.shared.handleMemoryWarning()`, which evicts all cached WebViews except the currently active one.
