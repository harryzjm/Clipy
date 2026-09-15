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
import UniformTypeIdentifiers

/// Backing store for the snippets editor.
///
/// Replaces the state that used to live on `CPYSnippetsEditorWindowController`: the `folders`
/// working copy, the `selectedFolder` / `selectedSnippet` computed properties that type-tested
/// `outlineView.item(atRow:)`, and the body of every IBAction.
@Observable
final class SnippetsEditorStore {

    /// The value-type projection the sidebar reads.
    ///
    /// `CPYFolder` and `CPYSnippet` are `NSObject` subclasses with `@objc dynamic` properties;
    /// they are not `@Observable`, so `folder.title = "x"` notifies nobody. Rather than make the
    /// model observable, the graph is re-projected after every mutation. SwiftUI then diffs
    /// values, `List` identity is a stable identifier string, and there is no way to write to the
    /// model and silently fail to redraw.
    private(set) var rows: [FolderRow] = []

    var selection: SnippetsSelection?
    var expandedFolders: Set<String> = []
    var renamingID: SnippetsSelection?
    var isDeleteConfirmationPresented = false

    /// Detached working copy, kept for the same reason the old controller kept one: the editor
    /// writes on every keystroke, so subscribing to `observeSnippets()` would replace this array —
    /// and with it the selection and any in-flight rename — underneath the user on each character.
    @ObservationIgnored private var folders: [CPYFolder] = []
    @ObservationIgnored private let disposeBag = DisposeBag()

    /// The folder a new snippet belongs to: the selected folder, or the selected snippet's owner.
    /// Mirrors the old `selectedFolder` computed property.
    var enclosingFolderIdentifier: String? {
        switch selection {
        case .folder(let identifier):
            return identifier
        case .snippet(let identifier):
            return folder(containing: identifier)?.identifier
        case nil:
            return nil
        }
    }

    /// `enable` of the selected item, for the toolbar's toggle icon. `nil` when nothing is selected.
    var isSelectionEnabled: Bool? {
        switch selection {
        case .folder(let identifier):
            return folder(identifier: identifier)?.enable
        case .snippet(let identifier):
            return snippet(identifier: identifier)?.enable
        case nil:
            return nil
        }
    }

    /// Reloads the detached working copy. Called on every window show and after an import.
    func reload() {
        AppEnvironment.current.box
            .snippetTransaction { try $0.fetchFolders() }
            .observe(on: MainScheduler.instance)
            .run(onNext: { [weak self] folders in
                guard let self else { return }
                self.folders = folders
                self.rebuild()
                // `windowDidLoad` selected the first folder; keep any existing selection on reshow.
                if self.selection == nil, let first = folders.first {
                    self.selection = .folder(first.identifier)
                }
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - Bindings
extension SnippetsEditorStore {

    func expansionBinding(for folderIdentifier: String) -> Binding<Bool> {
        Binding(get: { self.expandedFolders.contains(folderIdentifier) },
                set: { isExpanded in
                    if isExpanded {
                        self.expandedFolders.insert(folderIdentifier)
                    } else {
                        self.expandedFolders.remove(folderIdentifier)
                    }
                })
    }

    /// Folder title. The old xib had an `NSTextField` here with no action or delegate connected,
    /// so the right-hand title field looked editable but silently did nothing; this one works.
    func titleBinding(for folderIdentifier: String) -> Binding<String> {
        Binding(get: { self.folder(identifier: folderIdentifier)?.title ?? "" },
                set: { newValue in
                    guard let folder = self.folder(identifier: folderIdentifier) else { return }
                    folder.title = newValue
                    folder.merge()
                    self.rebuild()
                })
    }

    /// Snippet body. Writes on every keystroke, exactly as the old
    /// `textView(_:shouldChangeTextIn:replacementString:)` did — `merge()` is fire-and-forget onto
    /// the box queue, so the keystroke never waits on I/O, and there is no debounce window in
    /// which a close or quit could lose the last edit.
    ///
    /// No `rebuild()`: `SnippetRow` does not carry `content`, so the sidebar cannot be stale.
    func contentBinding(for snippetIdentifier: String) -> Binding<String> {
        Binding(get: { self.snippet(identifier: snippetIdentifier)?.content ?? "" },
                set: { newValue in
                    guard let snippet = self.snippet(identifier: snippetIdentifier) else { return }
                    snippet.content = newValue
                    snippet.merge()
                })
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
        folder.merge()
        rebuild()
        selection = .folder(folder.identifier)
    }

    func addSnippet() {
        guard let identifier = enclosingFolderIdentifier, let folder = folder(identifier: identifier) else {
            NSSound.beep()
            return
        }
        let snippet = folder.createSnippet()
        folder.snippets.append(snippet)
        folder.mergeSnippet(snippet)
        rebuild()
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
            folder.merge()
        case .snippet(let identifier):
            guard let snippet = snippet(identifier: identifier) else { return }
            snippet.enable.toggle()
            snippet.merge()
        case nil:
            NSSound.beep()
            return
        }
        rebuild()
    }

    /// Deletes the selected item. The confirmation alert lives in the view.
    func deleteSelection() {
        switch selection {
        case .folder(let identifier):
            guard let folder = folder(identifier: identifier) else { return }
            folders.removeAll { $0.identifier == identifier }
            folder.remove()
            // Folder shortcuts are keyed by identifier in UserDefaults; skipping this leaves a
            // hot key registered forever against a folder that no longer exists.
            AppEnvironment.current.hotKeyService.unregisterSnippetHotKey(with: identifier)
        case .snippet(let identifier):
            guard let folder = folder(containing: identifier),
                  let snippet = snippet(identifier: identifier) else { return }
            folder.snippets.removeAll { $0.identifier == identifier }
            snippet.remove()
        case nil:
            NSSound.beep()
            return
        }
        selection = nil
        rebuild()
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
            folder.merge()
        case .snippet(let identifier):
            guard let snippet = snippet(identifier: identifier) else { return }
            snippet.title = trimmed
            snippet.merge()
        case nil:
            return
        }
        rebuild()
    }
}

// MARK: - Reorder
extension SnippetsEditorStore {

    /// `move(fromOffsets:toOffset:)` uses pre-removal destination indices, which is what the old
    /// `acceptDrop` corrected for by hand with
    /// `removedIndex = (index < draggedData.index) ? draggedData.index + 1 : draggedData.index`.
    func moveFolders(from source: IndexSet, to destination: Int) {
        folders.move(fromOffsets: source, toOffset: destination)
        CPYFolder.rearrangesIndex(folders)
        rebuild()
    }

    func moveSnippets(in folderIdentifier: String, from source: IndexSet, to destination: Int) {
        guard let folder = folder(identifier: folderIdentifier) else { return }
        folder.snippets.move(fromOffsets: source, toOffset: destination)
        folder.rearrangesSnippetIndex()
        rebuild()
    }

    /// Moves a snippet to another folder, appending it at the end. Replaces the cross-folder drag
    /// the outline view supported; the entry point is now the row's "Move to Folder" menu.
    ///
    /// The order of the two store calls is load-bearing: `insertSnippet` re-parents the row, which
    /// is what makes the following `removeSnippet` on the source folder a documented no-op (see
    /// `CPYFolder.removeSnippet(_:)`). Swapping them deletes the snippet.
    func moveSnippet(_ snippetIdentifier: String, toFolder folderIdentifier: String) {
        guard let fromFolder = folder(containing: snippetIdentifier),
              let toFolder = folder(identifier: folderIdentifier),
              fromFolder.identifier != toFolder.identifier,
              let index = fromFolder.snippets.firstIndex(where: { $0.identifier == snippetIdentifier })
        else { return }

        let snippet = fromFolder.snippets[index]
        let destination = toFolder.snippets.count
        toFolder.snippets.append(snippet)
        fromFolder.snippets.remove(at: index)
        toFolder.insertSnippet(snippet, index: destination)
        fromFolder.removeSnippet(snippet)

        rebuild()
        expandedFolders.insert(toFolder.identifier)
        selection = .snippet(snippetIdentifier)
    }
}

// MARK: - Import / Export
extension SnippetsEditorStore {

    func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.urls.first else { return }

        do {
            let data = try Data(contentsOf: url)
            let importFolders = try JSONDecoder().decode([CPYFolder].self, from: data)
            if let lastIndex = folders.map({ $0.index }).max() {
                importFolders.forEach { $0.index += lastIndex }
            }
            AppEnvironment.current.box
                .snippetTransaction { try $0.importFolders(importFolders) }
                .observe(on: MainScheduler.instance)
                .run(onNext: { [weak self] in
                    self?.reload()
                }, onError: { [weak self] error in
                    NSSound.beep()
                    lError(error)
                    self?.reload()
                })
                .disposed(by: disposeBag)
        } catch {
            NSSound.beep()
            lError(error)
        }
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

    func rebuild() {
        rows = folders.map(FolderRow.init(folder:))
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
