//
//  SnippetsEditorView.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI

/// Root of the snippets editor.
///
/// Replaces the `CPYSplitView` and the six-button strip the xib laid out by hand — each button an
/// on/off PNG pair from `Asset.Snippet` with a 9 pt caption label above it. Those are now SF
/// Symbols in a standard toolbar, matching the preferences migration.
struct SnippetsEditorView: View {

    @Bindable var store: SnippetsEditorStore

    var body: some View {
        NavigationSplitView {
            SnippetsSidebar(store: store)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
        } detail: {
            SnippetDetailView(store: store)
        }
        .toolbar { toolbar }
        .alert(L10n.deleteItem, isPresented: $store.isDeleteConfirmationPresented) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.deleteItem, role: .destructive) { store.deleteSelection() }
        } message: {
            Text(L10n.areYouSureWantToDeleteThisItem)
        }
    }

    /// The old actions beeped when nothing was selected; disabled buttons say the same thing
    /// without the noise.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button { store.addSnippet() } label: {
                Label("Add Snippet", systemImage: "note.text.badge.plus")
            }
            .help("Add Snippet")
            .disabled(store.enclosingFolderIdentifier == nil)

            Button { store.addFolder() } label: {
                Label("Add Folder", systemImage: "folder.badge.plus")
            }
            .help("Add Folder")

            Button { store.isDeleteConfirmationPresented = true } label: {
                Label(L10n.deleteItem, systemImage: "trash")
            }
            .help(L10n.deleteItem)
            .disabled(store.selection == nil)

            Button { store.toggleEnabled() } label: {
                Label("Enable/Disable",
                      systemImage: store.isSelectionEnabled == false ? "circle.slash" : "checkmark.circle")
            }
            .help("Enable/Disable")
            .disabled(store.selection == nil)

            Button { store.importSnippets() } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .help("Import")

            Button { store.exportSnippets() } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export")
        }
    }
}
