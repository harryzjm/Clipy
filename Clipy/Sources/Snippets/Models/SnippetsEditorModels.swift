//
//  SnippetsEditorModels.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import Foundation

/// What the sidebar has selected.
///
/// `CPYSnippetsEditorWindowController` got `Any?` back from `outlineView.item(atRow:)` and
/// type-tested it in four separate places (`selectedFolder`, `selectedSnippet`,
/// `changeItemFocus()` and most of the IBActions). Making the two cases explicit removes those
/// tests and gives `List` a `Hashable` tag to select on.
enum SnippetsSelection: Hashable {
    case folder(String)
    case snippet(String)

    var folderIdentifier: String? {
        guard case .folder(let identifier) = self else { return nil }
        return identifier
    }

    var snippetIdentifier: String? {
        guard case .snippet(let identifier) = self else { return nil }
        return identifier
    }
}

/// What an import file does to the library it lands in. Picked in the confirmation alert, so both
/// the toolbar's Import button and the window's drop destination offer the same two.
enum SnippetImportMode {
    /// Upsert by identifier, appended after what is already there. The historical behaviour.
    case insert
    /// The file *is* the library: everything existing is dropped first.
    case replace
}

/// Value-type projection of `CPYSnippet` for the sidebar.
///
/// See `SnippetsEditorStore.rows` for why the editor does not hand `CPYSnippet` to SwiftUI
/// directly.
struct SnippetRow: Identifiable, Hashable {

    let id: String
    var title: String
    /// The snippet's own flag — what the toolbar button and the context menu toggle.
    var enable: Bool
    /// What the sidebar draws it with. A snippet inside a disabled folder is dimmed even with its
    /// own flag on, because `SnippetMenu.activeFolders` drops every snippet of a disabled folder —
    /// an undimmed row would promise a menu entry that never appears. The one exception is the
    /// folder-hotkey menu (`SnippetMenu(folder:)`), which keeps its folder whatever `enable` says;
    /// that asymmetry is deliberate and documented there, so do not "fix" `activeFolders` to match.
    var isEffectivelyEnabled: Bool

    init(snippet: CPYSnippet, isFolderEnabled: Bool) {
        id = snippet.identifier
        title = snippet.displayTitle
        enable = snippet.enable
        isEffectivelyEnabled = isFolderEnabled && snippet.enable
    }
}

/// Value-type projection of `CPYFolder` for the sidebar.
struct FolderRow: Identifiable, Hashable {

    let id: String
    var title: String
    var enable: Bool
    var snippets: [SnippetRow]

    init(folder: CPYFolder) {
        id = folder.identifier
        title = folder.title
        enable = folder.enable
        snippets = folder.snippets.map { SnippetRow(snippet: $0, isFolderEnabled: folder.enable) }
    }
}

/// What the toolbar needs to know about the selection, flattened into a value.
///
/// `SnippetsEditorStore.folders` is `@ObservationIgnored` and holds `CPYFolder` *class* instances
/// the store mutates in place, so a computed property reading it registers no dependency at all —
/// `SnippetsEditorView.body` only ever tracked `store.selection`, which is why the enable/disable
/// icon never changed when the flag was toggled. This is the observable answer: a stored property
/// the pipeline in `SnippetsEditorStore.bind()` writes.
struct SelectionState: Equatable {

    /// The folder the selection sits in — itself for a folder, the owner for a snippet.
    var enclosingFolderIdentifier: String?

    /// The selected item's *own* `enable`, not the effective one: this is the flag the toolbar
    /// button writes. `nil` when nothing is selected.
    var isSelectionEnabled: Bool?

    init() {}

    init(folders: [CPYFolder], selection: SnippetsSelection?) {
        switch selection {
        case .folder(let identifier):
            let folder = folders.first { $0.identifier == identifier }
            enclosingFolderIdentifier = folder?.identifier
            isSelectionEnabled = folder?.enable
        case .snippet(let identifier):
            let folder = folders.first { folder in
                folder.snippets.contains { $0.identifier == identifier }
            }
            enclosingFolderIdentifier = folder?.identifier
            isSelectionEnabled = folder?.snippets.first { $0.identifier == identifier }?.enable
        case nil:
            break
        }
    }
}
