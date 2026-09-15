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

/// Value-type projection of `CPYSnippet` for the sidebar.
///
/// See `SnippetsEditorStore.rows` for why the editor does not hand `CPYSnippet` to SwiftUI
/// directly.
struct SnippetRow: Identifiable, Hashable {

    let id: String
    var title: String
    var enable: Bool

    init(snippet: CPYSnippet) {
        id = snippet.identifier
        title = snippet.title
        enable = snippet.enable
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
        snippets = folder.snippets.map(SnippetRow.init(snippet:))
    }
}
