Clipy is a macOS menu-bar clipboard manager (a fork of Clipy/Clipy). App target plus a `ClipyTests` unit test target hosted inside it.

## Commands

Dependencies are CocoaPods; **always open/build `Clipy.xcworkspace`, never `Clipy.xcodeproj`.**

```bash
bundle install && bundle exec pod install --repo-update
```

```bash
xcodebuild -workspace Clipy.xcworkspace -scheme Clipy -configuration Debug build
```

- **Lint:** `swiftlint` (config `.swiftlint.yml`, scoped to `Clipy/Sources`). Note the Xcode `SwiftLint` build phase runs `swiftlint --fix` from the *system* PATH (`/opt/homebrew/bin`), so every build rewrites source files in place — expect a dirty tree after building. `bundle exec danger` lints via the Pods binary instead.
- **Codegen:** the `SwiftGen` build phase runs `${PODS_ROOT}/SwiftGen/bin/swiftgen` against `swiftgen.yml` on every build, regenerating `Clipy/Generated/LocalizedStrings.swift` (from `Clipy/Resources/en.lproj/Localizable.strings`) and `Clipy/Generated/AssetsImages.swift` (from `Images.xcassets`). Edit the sources, never the generated files. 
- **Tests:** `ClipyTests` is a unit test bundle hosted inside `Clipy.app` (`TEST_HOST`/`BUNDLE_LOADER`), added via CocoaPods `inherit! :search_paths` rather than its own pod list — it gets the app's pods (RxSwift, WCDB.swift, MMKV, …) through search paths and links them at runtime through the host process, so `@testable import Clipy` and `import RxSwift` both work without re-embedding frameworks. Run with:
  ```bash
  xcodebuild -workspace Clipy.xcworkspace -scheme Clipy -configuration Debug -destination 'platform=macOS' test
  ```
  `fastlane test` (`scan`) also targets it now, though `scan_clipy` passes `skip_build: true` so a `build-for-testing` needs to happen first.
- Deployment target is **macOS 14.0** (Podfile pins Pods to the same). The README's "macOS 10.15 / Xcode 12.3" line is stale.

## Architecture

### Lifecycle
SwiftUI `App` lifecycle ([ClipyApp.swift](Clipy/Sources/ClipyApp.swift)) whose only scene is `Settings`; `LSUIElement` is true, so there is no dock icon or main window. All real startup work happens in `AppDelegate.applicationDidFinishLaunching` via `@NSApplicationDelegateAdaptor`. The status menu opens Settings by locating SwiftUI's own menu item and performing it — `NSApp.sendAction(Selector(("showSettingsWindow:")))` silently no-ops (see [AppDelegate.swift:68](Clipy/Sources/AppDelegate.swift:68)).

### Service locator
`AppEnvironment.current` ([Environments/](Clipy/Sources/Environments/)) is a stack of immutable `Environment` structs holding every service plus `UserDefaults`. Services are reached as `AppEnvironment.current.clipService` etc., and swapped with `AppEnvironment.replaceCurrent(...)`. This is the only DI seam — services are not injected through initializers.

### Storage: the "box" layer
Storage is MMKV + WCDB (SQLite), in `Sources/Database/`. The layering is:

- **`ClipyBox.shared`** (a `StorageBox`) owns the MMKV store and two `ComponentService`s — `clip` and `snippet` — each with its **own serial `LQueue`** and its own WCDB file (`clip.db`, `snippet.db`). They are separate because clip writes come from the 750 ms pasteboard poll while snippet writes are user-driven.
- **All database access goes through a transaction closure:** `AppEnvironment.current.box.clipTransaction { try $0.fetchClip(...) }` returns an `Observable<T>`, dispatched onto the component's queue and delivered on its observe scheduler. Never touch a `DataStore` directly from outside.
- **The DAO surface lives on the transaction**, in [ClipTransaction+Ext.swift](Clipy/Sources/Database/ClipTransaction+Ext.swift) and `SnippetTransaction+Ext.swift`. Add new queries there, and put raw SQL/WCDB statements in `db/ClipDB.swift` / `db/SnippetDB.swift`.
- **Change notification:** a transaction records its deltas in `ClipStatus`; `beforeCommit()` turns them into a `ClipChangeSet` that `ClipViewTracker` replays into every live `MutableClipListView` *inside the still-open transaction*. `ClipyBox+Signal.swift` exposes this as `observeClips(...)` / `observeSnippets(...)` — long-lived `Observable`s that emit the initial value immediately. `replay` returns `false` when the visible window is unchanged, which is what stops no-op writes from rebuilding menus.
- **Migrations:** override `DataStore.migrationList()` with a new `Migration(version:)`; the applied version is stored in MMKV under `com.clipy.database.<name>.version` and committed per step. Never edit an existing migration's body or version.
- **`clip_fts`** (fts5 full-text index) is kept in step with `clip` by **SQL triggers, not Swift**, because expiry deletes by predicate (`deleteClips(olderThan:)`) and the Swift side never learns which rows were dropped.

### A clip is three pieces of state
Deleting or expiring one means handling all three:
1. a row in `clip` keyed by `data_hash` (a **content hash**, so re-copying the same text upserts and bumps `update_time` — that is how a repeat moves back to the top);
2. the full pasteboard payload as a JSON `<uuid>.data` file in Application Support;
3. a thumbnail in `PINCache` keyed by the unix timestamp.

`DataCleanService.cleanDatas()` runs once at launch (retention is a *time window*, `maxHistoryDays`), drops expired rows, then sweeps `.data` files nothing references — it filters to `.data` only, because the databases live in a `db/` subdirectory of that same folder.

### Capture and paste
`ClipService.startMonitoring()` polls `NSPasteboard.general.changeCount` every 750 ms on a `userInteractive` serial scheduler, filters by the enabled store types and the excluded-app list, then writes a `CPYClipData`. Pasting goes `AppDelegate.selectClipMenuItem` → fetch by hash → `PasteService`, which writes the pasteboard and **synthesizes ⌘V with `CGEvent`** — this needs Accessibility permission (`AccessibilityService`) and the `inputPasteCommand` preference.

### Menus and the run loop trap
`MenuManager` owns the status item and the snippets menu. The history menu is `FilterMenu`, a custom `NSMenu` with an embedded search field (`TextFieldMenuItem`).

**`NSMenu` runs a nested tracking run loop, so the main dispatch queue is not drained while a menu is open.** Anything that must update a live menu has to go through `MainRunLoopScheduler` (`CFRunLoopPerformBlock` in `.common` + `.eventTracking`) or `RunLoopLocalEventMonitor` for keys — using `MainScheduler`/`DispatchQueue.main` means the update only lands after the menu closes.

Search modes live in `FilterMatchMode` (`like` / `glob` / `fts`). Adding one means filling in both halves the compiler asks for: how to query (`ClipDB.fetchClips(filter:limit:)`) and how to mark the hit (`ClipFilter.highlightRanges(in:)`).

### Preferences and snippets UI
Preference **keys** are string constants in [Preferences.swift](Clipy/Sources/Preferences.swift); **defaults** are registered in `CPYUtilities.registerUserDefaultKeys()`. Both must be updated when adding a setting. The UI is SwiftUI panes under `Sources/Preferences/Panes/`, listed in `PreferencesRootView.Pane`. The snippets editor is a separate `SnippetsEditorWindowController.shared` hosting SwiftUI over an `@Observable SnippetsEditorStore`, which deliberately keeps a **detached working copy** of the folder graph rather than subscribing to `observeSnippets()` — otherwise each keystroke would replace the array and drop the selection.

## Conventions

- **RxSwift is the concurrency model** (services, storage, preference observation). SwiftUI views use `@Observable`. There is no Combine and essentially no `async`/`await`; follow the surrounding style rather than introducing a third model.
- **Log with the `SMLog` globals** — `lError` / `lWarning` / `lInfo` / `lDebug` / `lVerbose` — not `print`.
- **Persisted raw values are API.** The legacy `kCPYPref…` `UserDefaults` key strings and `FilterMatchMode`'s `Int` raw values are written to users' defaults; changing either silently resets their settings.

