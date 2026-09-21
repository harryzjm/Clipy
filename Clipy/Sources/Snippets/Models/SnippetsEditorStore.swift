//
//  SnippetsEditorStore.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import AppKit
import SwiftUI
import Magnet
import RxSwift
import RxCocoa
import UniformTypeIdentifiers

@Observable
final class SnippetsEditorStore {

    /// The sidebar's model — and, because `folders` is `@ObservationIgnored`, the store's only
    /// observable copy of the graph. Anything a view redraws on has to be a field of `FolderRow` /
    /// `SnippetRow`, or the `distinctUntilChanged()` in `bind()` will swallow the change.
    private(set) var rows: [FolderRow] = []

    /// Derived; never written by hand. See `SelectionState`.
    private(set) var selectionState = SelectionState()

    var selection: SnippetsSelection? {
        didSet {
            guard selection != oldValue else { return }
            selectionRelay.accept(selection)
        }
    }
    var expandedFolders: Set<String> = []
    var renamingID: SnippetsSelection?
    var isDeleteConfirmationPresented = false
    var isImportConfirmationPresented = false

    /// The detached working copy. Still `@ObservationIgnored`: it holds classes mutated in place,
    /// so observing it would buy nothing. `publish()` is what makes a change visible.
    @ObservationIgnored private var folders: [CPYFolder] = []
    /// Decoded but not yet written. Staged by `stageImport(from:)` and applied only once the
    /// confirmation alert comes back — `importFolders` upserts by identifier, so an accidental drop
    /// would otherwise overwrite existing folders with no undo.
    @ObservationIgnored private var pendingImportFolders: [CPYFolder] = []
    /// The folder graph as a signal, re-emitted by `publish()` after every mutation.
    ///
    /// The payload is the live graph, not a snapshot — two emissions are always the same objects —
    /// so nothing downstream may retain it or compare two of them. Dedupe the *projections*.
    @ObservationIgnored private let foldersRelay = BehaviorRelay<[CPYFolder]>(value: [])
    @ObservationIgnored private let selectionRelay = BehaviorRelay<SnippetsSelection?>(value: nil)
    @ObservationIgnored private let disposeBag = DisposeBag()
    @ObservationIgnored private let box: ClipyBox

    init(box: ClipyBox) {
        self.box = box
        bind()
    }

    /// Forwarders onto the derived `selectionState`. Observable now, because `selectionState` is a
    /// stored property the pipeline writes — not a computed read of the ignored `folders` graph.
    var enclosingFolderIdentifier: String? { selectionState.enclosingFolderIdentifier }

    /// `enable` of the selected item, for the toolbar's toggle icon. `nil` when nothing is selected.
    var isSelectionEnabled: Bool? { selectionState.isSelectionEnabled }

    /// Reloads the detached working copy. Called on every window show and after an import.
    func reload() {
        box
            .snippetTransaction { try $0.fetchFolders() }
            .observe(on: MainScheduler.instance)
            .run(onNext: { [weak self] folders in
                guard let self else { return }
                self.folders = folders
                self.publish()
                // `windowDidLoad` selected the first folder; keep any existing selection on reshow.
                if self.selection == nil, let first = folders.first {
                    self.selection = .folder(first.identifier)
                }
            })
            .disposed(by: disposeBag)
    }

    /// `reload()` for the case where the library was swapped out wholesale — a replacing import, or
    /// the status menu's Delete All Snippets. Both leave `selection` and `expandedFolders` pointing
    /// at identifiers that no longer exist, and `reload()` only picks a new selection when there is
    /// none, so the detail pane would otherwise sit empty on a row the sidebar no longer draws.
    func resetAndReload() {
        selection = nil
        expandedFolders = []
        reload()
    }
}

// MARK: - Bindings
extension SnippetsEditorStore {

    /// Folder title. The old xib had an `NSTextField` here with no action or delegate connected,
    /// so the right-hand title field looked editable but silently did nothing; this one works.
    func titleBinding(for folderIdentifier: String) -> Binding<String> {
        Binding(get: { self.folder(identifier: folderIdentifier)?.title ?? "" },
                set: { newValue in
                    guard let folder = self.folder(identifier: folderIdentifier) else { return }
                    folder.title = newValue
                    folder.merge(in: self.box)
                    self.publish()
                })
    }

    func content(for snippetIdentifier: String) -> String {
        snippet(identifier: snippetIdentifier)?.content ?? ""
    }

    func updateContent(_ newValue: String, for snippetIdentifier: String) {
        guard let snippet = snippet(identifier: snippetIdentifier) else { return }
        let titleBefore = snippet.displayTitle
        snippet.content = newValue
        snippet.merge(in: box)
        if snippet.displayTitle != titleBefore { publish() }
    }

    func language(for snippetIdentifier: String) -> String {
        snippet(identifier: snippetIdentifier)?.language ?? CPYSnippet.plainTextLanguage
    }

    /// No `publish()`: nothing the sidebar or the toolbar projects reads the language.
    func updateLanguage(_ newValue: String, for snippetIdentifier: String) {
        guard let snippet = snippet(identifier: snippetIdentifier) else { return }
        snippet.language = newValue
        snippet.merge(in: box)
    }
}

// MARK: - Hot keys
extension SnippetsEditorStore {

    func keyCombo(forFolder folderIdentifier: String) -> KeyCombo? {
        AppEnvironment.current.hotKeyService.snippetKeyCombo(forIdentifier: folderIdentifier)
    }

    func setKeyCombo(_ keyCombo: KeyCombo?, forFolder folderIdentifier: String) {
        guard let keyCombo else {
            AppEnvironment.current.hotKeyService.unregisterSnippetHotKey(with: folderIdentifier)
            return
        }
        AppEnvironment.current.hotKeyService.registerSnippetHotKey(with: folderIdentifier, keyCombo: keyCombo)
    }
}

// MARK: - Create
extension SnippetsEditorStore {

    func addFolder() {
        let folder = CPYFolder.create(after: folders)
        folders.append(folder)
        folder.merge(in: box)
        publish()
        selection = .folder(folder.identifier)
    }

    func addSnippet() {
        guard let folder = enclosingFolder else {
            NSSound.beep()
            return
        }
        let snippet = folder.createSnippet()
        folder.snippets.append(snippet)
        folder.mergeSnippet(snippet, in: box)
        publish()
        expandedFolders.insert(folder.identifier)
        selection = .snippet(snippet.identifier)
    }
}

// MARK: - Mutate
extension SnippetsEditorStore {

    func toggleEnabled() {
        switch selection {
        case .folder(let identifier):
            guard let folder = folder(identifier: identifier) else { return }
            folder.enable.toggle()
            folder.merge(in: box)
        case .snippet(let identifier):
            guard let snippet = snippet(identifier: identifier) else { return }
            snippet.enable.toggle()
            snippet.merge(in: box)
        case nil:
            NSSound.beep()
            return
        }
        publish()
    }

    /// Deletes the selected item. The confirmation alert lives in the view.
    func deleteSelection() {
        switch selection {
        case .folder(let identifier):
            guard let folder = folder(identifier: identifier) else { return }
            folders.removeAll { $0.identifier == identifier }
            folder.remove(in: box)
            // Folder shortcuts are keyed by identifier in UserDefaults; skipping this leaves a
            // hot key registered forever against a folder that no longer exists.
            AppEnvironment.current.hotKeyService.unregisterSnippetHotKey(with: identifier)
        case .snippet(let identifier):
            guard let folder = folder(containing: identifier),
                  let snippet = snippet(identifier: identifier) else { return }
            folder.snippets.removeAll { $0.identifier == identifier }
            snippet.remove(in: box)
        case nil:
            NSSound.beep()
            return
        }
        selection = nil
        publish()
    }

    /// Commits an inline rename. Empty titles are refused, as the old
    /// `control(_:textShouldEndEditing:)` refused to end editing on an empty field editor.
    func commitRename(_ title: String) {
        defer { renamingID = nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch renamingID {
        case .folder(let identifier):
            guard let folder = folder(identifier: identifier) else { return }
            folder.title = trimmed
            folder.merge(in: box)
        case .snippet(let identifier):
            guard let snippet = snippet(identifier: identifier) else { return }
            snippet.title = trimmed
            snippet.merge(in: box)
        case nil:
            return
        }
        publish()
    }
}

// MARK: - Reorder
extension SnippetsEditorStore {

    /// `move(fromOffsets:toOffset:)` uses pre-removal destination indices, which is what the old
    /// `acceptDrop` corrected for by hand with
    /// `removedIndex = (index < draggedData.index) ? draggedData.index + 1 : draggedData.index`.
    func moveFolders(from source: IndexSet, to destination: Int) {
        folders.move(fromOffsets: source, toOffset: destination)
        CPYFolder.rearrangesIndex(folders, in: box)
        publish()
    }

    func moveSnippets(in folderIdentifier: String, from source: IndexSet, to destination: Int) {
        guard let folder = folder(identifier: folderIdentifier) else { return }
        folder.snippets.move(fromOffsets: source, toOffset: destination)
        folder.rearrangesSnippetIndex(in: box)
        publish()
    }

    /// Drop-driven folder reorder. Because the offsets above are pre-removal, "immediately
    /// before the target" is the target's own index and "after" is one past it, in both drag
    /// directions: [A,B,C] with A before C is `toOffset` 2 → [B,A,C]; C before A is 0 → [C,A,B].
    func moveFolder(_ identifier: String, relativeTo targetIdentifier: String, position: SnippetsDropPosition) {
        guard identifier != targetIdentifier,
              let from = folders.firstIndex(where: { $0.identifier == identifier }),
              let target = folders.firstIndex(where: { $0.identifier == targetIdentifier })
        else { return }

        let destination = position == .before ? target : target + 1
        // Both of these land the folder back where it started, at the cost of a renumber.
        guard destination != from, destination != from + 1 else { return }

        moveFolders(from: IndexSet(integer: from), to: destination)
    }

    /// Drop-driven snippet move: a reorder when both snippets share a folder, a re-parent at that
    /// position when they do not — the half `.onMove` could not express at all.
    func moveSnippet(_ identifier: String, relativeTo targetIdentifier: String, position: SnippetsDropPosition) {
        guard identifier != targetIdentifier,
              let source = folder(containing: identifier),
              let destination = folder(containing: targetIdentifier),
              let from = source.snippets.firstIndex(where: { $0.identifier == identifier }),
              let target = destination.snippets.firstIndex(where: { $0.identifier == targetIdentifier })
        else { return }

        let slot = position == .before ? target : target + 1
        if source.identifier == destination.identifier {
            guard slot != from, slot != from + 1 else { return }
            moveSnippets(in: source.identifier, from: IndexSet(integer: from), to: slot)
            return
        }
        reparent(source.snippets[from], from: source, to: destination, at: slot)
    }

    /// Appends a snippet to another folder: the "Move to Folder" menu, and a drop onto a folder
    /// row — the only way to reach a collapsed or empty folder, which has no snippet row to aim at.
    func moveSnippet(_ snippetIdentifier: String, toFolder folderIdentifier: String) {
        guard let source = folder(containing: snippetIdentifier),
              let destination = folder(identifier: folderIdentifier),
              source.identifier != destination.identifier,
              let snippet = source.snippets.first(where: { $0.identifier == snippetIdentifier })
        else { return }

        reparent(snippet, from: source, to: destination, at: destination.snippets.count)
    }

    /// The one cross-folder path, shared by both drops and the menu. The order of the store
    /// calls is load-bearing: `insertSnippet` re-parents the row, which
    /// is what makes the following `removeSnippet` on the source folder a documented no-op (see
    /// `CPYFolder.removeSnippet(_:)`). Swapping them deletes the snippet.
    private func reparent(_ snippet: CPYSnippet, from source: CPYFolder, to destination: CPYFolder, at index: Int) {
        guard source !== destination,
              let from = source.snippets.firstIndex(where: { $0.identifier == snippet.identifier })
        else { return }

        source.snippets.remove(at: from)
        let slot = max(0, min(index, destination.snippets.count))
        destination.snippets.insert(snippet, at: slot)

        destination.insertSnippet(snippet, index: slot, in: box)
        source.removeSnippet(snippet, in: box)
        // The source keeps a hole in its `index` sequence, and `appendSnippet` picks a new
        // snippet's index from the row *count* — a hole collides on the next Add Snippet.
        source.rearrangesSnippetIndex(in: box)

        publish()

        // Two `@Observable` writes a same-folder reorder never makes, and an animated row move
        // is the one thing they can disturb: even a redundant write invalidates everything
        // reading them inside the transaction the move is animating in. So write only on a real
        // change, and let the selection land after the move is committed — on `RunLoop.main` in
        // `.common`, since a drag is tracking and the main queue may not be drained.
        if !expandedFolders.contains(destination.identifier) {
            expandedFolders.insert(destination.identifier)
        }
        let moved = SnippetsSelection.snippet(snippet.identifier)
        guard selection != moved else { return }
        RunLoop.main.perform(inModes: [.common]) { [weak self] in self?.selection = moved }
    }
}

// MARK: - Import / Export
extension SnippetsEditorStore {

    /// Picking a file only stages it; `confirmPendingImport()` is what writes.
    func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.urls.first else { return }

        stageImport(from: url)
    }

    /// The single gate both the toolbar button and the window's drop destination go through.
    /// Returns whether `url` was accepted, so a drop can refuse the file and let the Finder animate
    /// it back. A file that will not parse is rejected quietly — beep and log, no alert.
    @discardableResult
    func stageImport(from url: URL) -> Bool {
        // A second staged import would silently replace the first while its alert is still up.
        guard !isImportConfirmationPresented else { return false }
        guard Self.isSnippetsFile(url) else {
            NSSound.beep()
            lError("Not a JSON file: \(url.lastPathComponent)")
            return false
        }

        do {
            let importFolders = try Self.decodeFolders(at: url)
            guard !importFolders.isEmpty else {
                NSSound.beep()
                lError("No folders in \(url.lastPathComponent)")
                return false
            }
            pendingImportFolders = importFolders
            isImportConfirmationPresented = true
            return true
        } catch {
            NSSound.beep()
            lError(error)
            return false
        }
    }

    func cancelPendingImport() {
        pendingImportFolders = []
    }

    /// `.insert` upserts the file on top of what is there; `.replace` makes the file the whole
    /// library. Only the write and what it invalidates differ — the error path is shared, and both
    /// end in a re-read, because either way the working copy no longer matches the database.
    func confirmPendingImport(mode: SnippetImportMode) {
        let importFolders = pendingImportFolders
        pendingImportFolders = []
        guard !importFolders.isEmpty else { return }

        // Identifiers the import does not carry over. Read before the write, used after it.
        let droppedFolders = mode == .replace
            ? folders.map { $0.identifier }.filter { identifier in
                !importFolders.contains { $0.identifier == identifier }
            }
            : []

        if mode == .insert {
            // Offset against the working copy as of *now*, not as of the drop. A replacing import
            // has nothing to append after, so the file's own indices are the order.
            if let lastIndex = folders.map({ $0.index }).max() {
                importFolders.forEach { $0.index += lastIndex }
            }
        }

        box
            .snippetTransaction { transaction in
                // One closure, one transaction: a failure between the two rolls the old graph back.
                if mode == .replace {
                    try transaction.clearAllFolders()
                }
                try transaction.importFolders(importFolders)
            }
            .observe(on: MainScheduler.instance)
            .run(onNext: { [weak self] in
                // Folder shortcuts are keyed by identifier in UserDefaults, exactly as in
                // `deleteSelection()`; a folder the import dropped would keep one forever. After
                // the write, so a failed import never costs the user a hot key.
                droppedFolders.forEach {
                    AppEnvironment.current.hotKeyService.unregisterSnippetHotKey(with: $0)
                }
                guard mode == .replace else {
                    self?.reload()
                    return
                }
                self?.resetAndReload()
            }, onError: { [weak self] error in
                NSSound.beep()
                lError(error)
                self?.reload()
            })
            .disposed(by: disposeBag)
    }

    /// The drop destination's filter. Falls back to the extension for a URL the file system will not
    /// answer a content type for.
    static func isSnippetsFile(_ url: URL) -> Bool {
        if let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType {
            return type.conforms(to: .json)
        }
        return url.pathExtension.lowercased() == "json"
    }

    /// Split out of `stageImport(from:)` so the file format can be tested without a window.
    static func decodeFolders(at url: URL) throws -> [CPYFolder] {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([CPYFolder].self, from: data)
    }

    /// The exported shape is the hand-written `CodingKeys` on `CPYFolder` / `CPYSnippet`, which is
    /// the documented snippets file format (see `script/translate.py`). It must not drift.
    func exportSnippets() {
        let ordered = folders.sorted { $0.index < $1.index }

        let panel = NSSavePanel()
        panel.canSelectHiddenExtension = true
        panel.allowedContentTypes = [.json]
        panel.allowsOtherFileTypes = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        panel.nameFieldStringValue = "snippets"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            try encoder.encode(ordered).write(to: url, options: .atomic)
        } catch {
            NSSound.beep()
            lError(error)
        }
    }
}

// MARK: - Lookup
private extension SnippetsEditorStore {

    /// Both derived pipelines, built once.
    ///
    /// No `observe(on:)` anywhere — `BehaviorRelay` delivers synchronously on the calling thread,
    /// and three callers (`addFolder`, `addSnippet`, `moveSnippet`) set `selection` on the line
    /// after `publish()`; with an async hop `List` would be handed a tag for a row it has not seen
    /// in `rows` yet and would drop it.
    ///
    /// Both sinks are write-only: they assign one observed property and call nothing else. A sink
    /// that re-entered a relay would deliver values out of order.
    func bind() {
        foldersRelay
            .map { $0.map(FolderRow.init(folder:)) }
            .distinctUntilChanged()
            .run(onNext: { [weak self] rows in self?.rows = rows })
            .disposed(by: disposeBag)

        // Load-bearing dedupe, not an optimisation: `combineLatest` fires on either input, and
        // `titleBinding` publishes on every keystroke — without it the toolbar would invalidate
        // once per character typed into the folder title field.
        Observable
            .combineLatest(foldersRelay, selectionRelay) { SelectionState(folders: $0, selection: $1) }
            .distinctUntilChanged()
            .run(onNext: { [weak self] state in self?.selectionState = state })
            .disposed(by: disposeBag)
    }

    /// Re-emits the working copy after an in-place mutation, which is what drives `rows` and
    /// `selectionState`. Replaces `rebuild()` — the projection itself now lives in `bind()`,
    /// declared once. Main thread only; every caller already is.
    func publish() {
        foldersRelay.accept(folders)
    }

    /// Model-side twin of `SelectionState.enclosingFolderIdentifier`. Store internals read the
    /// working copy directly and only the views read the derived state, so a missed `publish()`
    /// can leave the UI stale but can never make a mutation write to the wrong folder.
    var enclosingFolder: CPYFolder? {
        switch selection {
        case .folder(let identifier):
            return folder(identifier: identifier)
        case .snippet(let identifier):
            return folder(containing: identifier)
        case nil:
            return nil
        }
    }

    func folder(identifier: String) -> CPYFolder? {
        folders.first { $0.identifier == identifier }
    }

    func folder(containing snippetIdentifier: String) -> CPYFolder? {
        folders.first { folder in
            folder.snippets.contains { $0.identifier == snippetIdentifier }
        }
    }

    func snippet(identifier: String) -> CPYSnippet? {
        for folder in folders {
            if let snippet = folder.snippets.first(where: { $0.identifier == identifier }) {
                return snippet
            }
        }
        return nil
    }
}
