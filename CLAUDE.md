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
`AppEnvironment.current` ([Environments/](Clipy/Sources/Environments/)) is a stack of immutable `Environment` structs holding every service plus `UserDefaults`. Services are reached as `AppEnvironment.current.clipService` etc., and swapped with `AppEnvironment.replaceCurrent(...)`.

The environment also holds one secret and the two stores built from it: `secretService` (the installation key and all encryption), `box` (the databases) and `assetStore` (everything a clip owns outside them). `secretService` is the only default argument in `Environment.init` that does any work — `box` and `assetStore` are derived from it in the body, so they cannot end up under different keys and the keychain is read once per launch. Services that need a store take it as an `init` parameter — `ClipService(box:assetStore:)`, `DataCleanService(box:assetStore:)`, `PasteService(assetStore:)` — and `Environment.init` is what hands it over. That is the only constructor injection; every *other* cross-service reference is `AppEnvironment.current.<service>` at call time.

### Storage: the "box" layer
Storage is MMKV + WCDB (SQLite), in `Sources/Database/`. The layering is:

- **`ClipyBox.shared`** (a `StorageBox`) owns the MMKV store and two `ComponentService`s — `clip` and `snippet` — each with its **own serial `LQueue`** and its own WCDB file (`clip.db`, `snippet.db`). They are separate because clip writes come from the 750 ms pasteboard poll while snippet writes are user-driven.
- **All database access goes through a transaction closure:** `AppEnvironment.current.box.clipTransaction { try $0.fetchClip(...) }` returns an `Observable<T>`, dispatched onto the component's queue and delivered on its observe scheduler. Never touch a `DataStore` directly from outside.
- **The DAO surface lives on the transaction**, in [ClipTransaction+Ext.swift](Clipy/Sources/Database/ClipTransaction+Ext.swift) and `SnippetTransaction+Ext.swift`. Add new queries there, and put raw SQL/WCDB statements in `db/ClipDB.swift` / `db/SnippetDB.swift`.
- **Change notification:** a transaction records its deltas in `ClipStatus`; `beforeCommit()` turns them into a `ClipChangeSet` that `ClipViewTracker` replays into every live `MutableClipListView` *inside the still-open transaction*. `ClipyBox+Signal.swift` exposes this as `observeClips(...)` / `observeSnippets(...)` — long-lived `Observable`s that emit the initial value immediately. `replay` returns `false` when the visible window is unchanged, which is what stops no-op writes from rebuilding menus.
- **Migrations:** override `DataStore.migrationList()` with a new `Migration(version:)`; the applied version is stored in MMKV under `com.clipy.database.<name>.version` and committed per step. Never edit an existing migration's body or version.
- **`clip_fts`** (fts5 full-text index) is kept in step with `clip` by **SQL triggers, not Swift**, because expiry deletes by predicate (`deleteClips(olderThan:)`) and the Swift side never learns which rows were dropped.
- **A file that will not open is offered for deletion, never deleted quietly.** `DataStore.init` probes each database with one read (nothing before it touches the disk — `Database(at:)` is lazy and `setCipher` only records the key) and classifies `NOTADB` / `CORRUPT` as `DatabaseOpenFailure`. It then asks its `DatabaseRecovery`, blocking the owning queue until the answer comes back; saying yes closes the handle, `removeFiles()`, and clears the MMKV version key so the migrations that follow rebuild the schema. `Environment` supplies the one implementation that puts a window up (`DatabaseResetPrompt`, one decision per launch for both files); everything else — tests included — passes nil and keeps the old behaviour, where the handle stays and every transaction through it fails.

### A clip is three pieces of state
Deleting or expiring one means handling all three:
1. a row in `clip` keyed by `data_hash` (a **content hash**, so re-copying the same text upserts and bumps `update_time` — that is how a repeat moves back to the top);
2. the pasteboard payload, `JSONEncoder().encode([TypeContent])` — **inline in the `clip_content` side table when it is ≤ `CPYClip.inlineContentLimit` (10 KiB), otherwise an encrypted `file/<uuid>` file** in Application Support with that *relative* path in `data_path`. The payload is a side table rather than a column on `clip` because every list read decodes `clip` in full (no projection anywhere), so a blob there would be read and compared on every keystroke in the history filter;
3. a thumbnail in `PINCache` keyed by the unix timestamp.

`content` and `dataPath` are exclusive **as stored**, but not in memory: `CPYClip(contents:)` is pure — it derives `dataPath` for an oversized payload but still leaves the bytes in `content`, and `insertClip` is what drops `content` on the floor (`clip.dataPath.isEmpty ? clip.content : nil`) once the file is someone else's problem.

Only `fetchClip(dataHash:)` — the paste path — carries the payload, and only the inline half: the file read happens later, in `loadContents()`. List reads leave `CPYClip.content` nil, and `loadContents()` logs loudly rather than silently pasting nothing if you try to use one of those.

`clip_content` is cleared by the `clip_content_ad` SQL trigger for targeted and predicate deletes (same reason as `clip_fts`: expiry deletes by predicate, so Swift never sees the hashes), and explicitly inside `deleteAllClips()` — a `DELETE` with no `WHERE` is the shape SQLite's truncate optimization targets, and that is not worth betting a whole table on.

### Out-of-database clip state: `ClipAssetStore`
Everything a clip owns outside the databases — the overflow payload file and the `PINCache` thumbnail — goes through `ClipAssetStore`, owned by `Environment` (`AppEnvironment.current.assetStore`) alongside `box` rather than inside it: none of this is database state, and the database layer never touches it — `Database/` deals in `dataPath` strings and leaves the bytes to whoever holds the store. It is handed the same `SecretService` `box` is built from, so the two cannot drift apart. Three things it exists to enforce:

- **One serial queue for all of it.** `ClipAssetStore.queue` (`com.clipy.clip.asset`, `.utility`) runs payload writes, thumbnail rendering, PINCache writes/evictions and the orphan sweep. Nothing in the capture path waits on any of it — which matters because `ClipService.create(with:image:)` is called from the main thread, and the sweep used to delete files on `LQueue.main`.
- **Payload files are encrypted** by `SecretService.seal(_:context:)`, under `SHA256(secretCode ‖ dataPath)` with AES-GCM (`combined`: 12B nonce + ciphertext + 16B tag). A key per file, so a moved or renamed file no longer opens — deliberate. No key at all (keychain unreachable) writes plaintext, matching what the databases do in the same situation. `SecretService` ([Services/SecretService.swift](Clipy/Sources/Services/SecretService.swift)) is the only place in the app that touches the keychain or does any crypto; its keychain item's service/account strings are persisted identifiers, so renaming the type must never change them.
- **A pending buffer covers the write window.** The row lands before the file does, so `store(_:contents:)` buffers the payload by `dataPath` synchronously and `loadPayload` checks it before hitting the disk. A failed write only logs — the row stays, and pasting it reports the real error.

`DataCleanService.cleanDatas()` runs once at launch (retention is a *time window*, `maxHistoryDays`), drops expired rows, then hands the still-referenced file names to `sweepFiles(referencing:)`, which deletes everything else in `file/`. Mark-and-sweep rather than deleting alongside the row, because expiry deletes by predicate and Swift never learns which rows went.

Payload files written before this existed — absolute `<uuid>.data` paths in the Application Support root, unencrypted — are **not** supported. Nothing reads them and nothing sweeps them; those rows fail to paste until they expire.

### Capture and paste
`ClipService.startMonitoring()` polls `NSPasteboard.general.changeCount` every 750 ms on a `userInteractive` serial scheduler, filters by the enabled store types and the excluded-app list, then builds a `CPYClip` from the captured `[TypeContent]` — `CPYClip(contents:)` derives every stored field, including `thumbnailKey`, so storing never waits on the image cache. Pasting goes `AppDelegate.selectClipMenuItem` → fetch by hash → `PasteService`, which writes the pasteboard and **synthesizes ⌘V with `CGEvent`** — this needs Accessibility permission (`AccessibilityService`) and the `inputPasteCommand` preference.

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

