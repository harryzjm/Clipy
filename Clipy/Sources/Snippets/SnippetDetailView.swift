//
//  SnippetDetailView.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI

/// The right-hand pane, replacing `changeItemFocus()` and the two xib views it toggled with
/// `isHidden`: a folder settings view and a `CPYPlaceHolderTextView`.
struct SnippetDetailView: View {

    @Bindable var store: SnippetsEditorStore

    var body: some View {
        switch store.selection {
        case .folder(let identifier):
            FolderSettingsView(folderIdentifier: identifier, store: store)
        case .snippet(let identifier):
            SnippetContentView(snippetIdentifier: identifier, store: store)
                // A fresh identity per snippet rebuilds the editor, which is what the old
                // `textView.undoManager?.removeAllActions()` achieved on every selection change.
                .id(identifier)
        case nil:
            ContentUnavailableView(L10n.Snippets.Detail.NoSelection.title,
                                   systemImage: "text.alignleft",
                                   description: Text(L10n.Snippets.Detail.NoSelection.description))
        }
    }
}

/// Folder title and shortcut.
///
/// The old `recordViewShouldBeginRecording` / `canRecordKeyCombo` both guarded on
/// `selectedFolder != nil`; here that guard is structural — the recorder only exists when a folder
/// is selected — so `ShortcutRecorder` is reused unchanged from the preferences migration.
private struct FolderSettingsView: View {

    let folderIdentifier: String

    @Bindable var store: SnippetsEditorStore

    var body: some View {
        Form {
            Section {
                LabeledContent(L10n.Snippets.Detail.Folder.titleLabel) {
                    TextField(L10n.Snippets.Detail.Folder.titleLabel, text: store.titleBinding(for: folderIdentifier))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 260)
                }
                LabeledContent(L10n.Snippets.Detail.Folder.shortcutLabel) {
                    ShortcutRecorder(keyCombo: store.keyCombo(forFolder: folderIdentifier)) { keyCombo in
                        store.setKeyCombo(keyCombo, forFolder: folderIdentifier)
                    }
                    .frame(width: 170, height: 26)
                }
            } header: {
                Label(L10n.Snippets.Detail.Folder.title, systemImage: "folder.fill")
                    .foregroundStyle(SwiftUI.Color(nsColor: Asset.Color.clipy.color))
            }
        }
        .formStyle(.grouped)
    }
}

/// Snippet body.
///
/// `CPYPlaceHolderTextView` drew its placeholder in `draw(_:)`; here it is an overlay, which is
/// why that class can be deleted outright.
private struct SnippetContentView: View {

    let snippetIdentifier: String

    @Bindable var store: SnippetsEditorStore

    var body: some View {
        let text = store.contentBinding(for: snippetIdentifier)

        TextEditor(text: text)
            .font(.system(size: 14))
            .scrollContentBackground(.hidden)
            .padding(8)
            .overlay(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(L10n.Snippets.emptyContentPlaceholder)
                        .font(.system(size: 14))
                        .foregroundStyle(SwiftUI.Color(nsColor: .disabledControlTextColor))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
    }
}
