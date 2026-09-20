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

    @State private var isDropTargeted = false

    var body: some View {
        NavigationSplitView {
            SnippetsSidebar(store: store)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            SnippetDetailView(store: store)
        }
        .toolbar { toolbar }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: SnippetsEditorStore.isSnippetsFile) else { return false }
            return store.stageImport(from: url)
        } isTargeted: { isDropTargeted = $0 }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.accentColor, lineWidth: 3)
                    }
                    .padding(4)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isDropTargeted)
        .alert(L10n.Common.deleteItem, isPresented: $store.isDeleteConfirmationPresented) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Common.deleteItem, role: .destructive) { store.deleteSelection() }
        } message: {
            Text(L10n.Alert.DeleteSnippet.message)
        }
        .alert(L10n.Alert.ImportSnippets.title, isPresented: $store.isImportConfirmationPresented) {
            Button(L10n.Common.cancel, role: .cancel) { store.cancelPendingImport() }
            Button(L10n.Snippets.Editor.Toolbar.`import`) { store.confirmPendingImport() }
        } message: {
            Text(L10n.Alert.ImportSnippets.message)
        }
    }

    /// The old actions beeped when nothing was selected; disabled buttons say the same thing
    /// without the noise.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button { store.addSnippet() } label: {
                Label(L10n.Snippets.Editor.Toolbar.addSnippet, systemImage: "note.text.badge.plus")
            }
            .help(L10n.Snippets.Editor.Toolbar.addSnippet)
            .disabled(store.enclosingFolderIdentifier == nil)

            Button { store.addFolder() } label: {
                Label(L10n.Snippets.Editor.Toolbar.addFolder, systemImage: "folder.badge.plus")
            }
            .help(L10n.Snippets.Editor.Toolbar.addFolder)

            Button { store.isDeleteConfirmationPresented = true } label: {
                Label(L10n.Common.deleteItem, systemImage: "trash")
            }
            .help(L10n.Common.deleteItem)
            .disabled(store.selection == nil)

            Button { store.toggleEnabled() } label: {
                Label(L10n.Snippets.Editor.Toolbar.enableDisable,
                      systemImage: store.isSelectionEnabled == false ? "circle.slash" : "checkmark.circle")
            }
            .help(L10n.Snippets.Editor.Toolbar.enableDisable)
            .disabled(store.selection == nil)

            Button { store.importSnippets() } label: {
                Label(L10n.Snippets.Editor.Toolbar.`import`, systemImage: "square.and.arrow.down")
            }
            .help(L10n.Snippets.Editor.Toolbar.`import`)

            Button { store.exportSnippets() } label: {
                Label(L10n.Snippets.Editor.Toolbar.export, systemImage: "square.and.arrow.up")
            }
            .help(L10n.Snippets.Editor.Toolbar.export)
        }
    }
}
