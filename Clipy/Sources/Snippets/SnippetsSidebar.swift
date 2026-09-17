//
//  SnippetsSidebar.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI

/// The folder/snippet tree, replacing the `NSOutlineView` and its data source and delegate.
///
/// Built from an explicit `ForEach` of `DisclosureGroup`s rather than `List(_, children:)`,
/// because the old behaviour expands folders programmatically in two places — after adding a
/// snippet, and after moving one into another folder. `List(children:)` owns its expansion state
/// internally and offers no way to do that; `DisclosureGroup(isExpanded:)` bound to the store does.
struct SnippetsSidebar: View {

    @Bindable var store: SnippetsEditorStore

    var body: some View {
        List(selection: $store.selection) {
            ForEach(store.rows) { folder in
                DisclosureGroup(isExpanded: store.expansionBinding(for: folder.id)) {
                    ForEach(folder.snippets) { snippet in
                        SnippetsSidebarRow(title: snippet.title,
                                           isFolder: false,
                                           isEnabled: snippet.enable,
                                           selection: .snippet(snippet.id),
                                           parentIdentifier: folder.id,
                                           store: store)
                            .tag(SnippetsSelection.snippet(snippet.id))
                    }
                    .onMove { store.moveSnippets(in: folder.id, from: $0, to: $1) }
                } label: {
                    SnippetsSidebarRow(title: folder.title,
                                       isFolder: true,
                                       isEnabled: folder.enable,
                                       selection: .folder(folder.id),
                                       parentIdentifier: nil,
                                       store: store)
                        .tag(SnippetsSelection.folder(folder.id))
                }
            }
            .onMove { store.moveFolders(from: $0, to: $1) }
        }
        .listStyle(.sidebar)
    }
}

/// One row, plus its inline rename editor and context menu.
///
/// Reproduces what `CPYSnippetsEditorCell.draw(withFrame:in:)` did by hand: folders drew an icon
/// and `Asset.Color.clipy`, snippets drew neither, and a disabled item of either kind drew in
/// `.disabledControlTextColor`.
private struct SnippetsSidebarRow: View {

    let title: String
    let isFolder: Bool
    let isEnabled: Bool
    let selection: SnippetsSelection
    let parentIdentifier: String?

    @Bindable var store: SnippetsEditorStore

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        content
            .font(.system(size: 14))
            .contextMenu { menu }
    }

    @ViewBuilder
    private var content: some View {
        if store.renamingID == selection {
            TextField("", text: $draft)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onAppear {
                    draft = title
                    isFocused = true
                }
                .onSubmit { store.commitRename(draft) }
                // `control(_:textShouldEndEditing:)` also committed when the field editor lost
                // focus; `.onSubmit` alone does not fire for that.
                .onChange(of: isFocused) { _, focused in
                    guard !focused, store.renamingID == selection else { return }
                    store.commitRename(draft)
                }
                .onExitCommand { store.renamingID = nil }
        } else {
            HStack(spacing: 4) {
                if isFolder {
                    SwiftUI.Image(systemName: "folder.fill")
                        .foregroundStyle(iconColor)
                }
                Text(title)
                    .foregroundStyle(titleColor)
            }
            // `simultaneousGesture`, not `onTapGesture`: a plain tap gesture swallows the single
            // click and the `List` never updates its selection.
            .simultaneousGesture(TapGesture(count: 2).onEnded { beginRename() })
        }
    }

    @ViewBuilder
    private var menu: some View {
        Button(L10n.Snippets.Sidebar.ContextMenu.rename) { beginRename() }
        Button(isEnabled ? L10n.Snippets.Sidebar.ContextMenu.disable : L10n.Snippets.Sidebar.ContextMenu.enable) {
            store.selection = selection
            store.toggleEnabled()
        }
        if let snippetIdentifier = selection.snippetIdentifier, otherFolders.isEmpty == false {
            Menu(L10n.Snippets.Sidebar.ContextMenu.moveToFolder) {
                ForEach(otherFolders) { folder in
                    Button(folder.title) {
                        store.moveSnippet(snippetIdentifier, toFolder: folder.id)
                    }
                }
            }
        }
        Divider()
        Button(L10n.Snippets.Sidebar.ContextMenu.delete, role: .destructive) {
            store.selection = selection
            store.isDeleteConfirmationPresented = true
        }
    }

    private var otherFolders: [FolderRow] {
        store.rows.filter { $0.id != parentIdentifier }
    }

    private var titleColor: SwiftUI.Color {
        guard isEnabled else { return SwiftUI.Color(nsColor: .disabledControlTextColor) }
        return isFolder ? SwiftUI.Color(nsColor: Asset.Color.clipy.color) : .primary
    }

    private var iconColor: SwiftUI.Color {
        isEnabled ? SwiftUI.Color(nsColor: Asset.Color.clipy.color) : SwiftUI.Color(nsColor: .disabledControlTextColor)
    }

    private func beginRename() {
        store.selection = selection
        store.renamingID = selection
    }
}
