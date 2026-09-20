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
                .id(identifier)
        case nil:
            ContentUnavailableView(L10n.Snippets.Detail.NoSelection.title,
                                   systemImage: "text.alignleft",
                                   description: Text(L10n.Snippets.Detail.NoSelection.description))
        }
    }
}

private struct FolderSettingsView: View {

    /// Shared by the title field and the shortcut recorder, so the two rows sit on the same fill.
    private static let controlSize = CGSize(width: 170, height: 26)
    private static let controlCornerRadius: CGFloat = 6

    let folderIdentifier: String

    @Bindable var store: SnippetsEditorStore

    @FocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section {
                LabeledContent(L10n.Snippets.Detail.Folder.titleLabel) {
                    TextField(L10n.Snippets.Detail.Folder.titleLabel, text: store.titleBinding(for: folderIdentifier))
                        .labelsHidden()
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.leading)
                        .focused($isTitleFocused)
                        .padding(.horizontal, 6)
                        .frame(width: Self.controlSize.width, height: Self.controlSize.height)
                        .background(SwiftUI.Color(nsColor: .textBackgroundColor),
                                    in: RoundedRectangle(cornerRadius: Self.controlCornerRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: Self.controlCornerRadius)
                                .strokeBorder(SwiftUI.Color.accentColor, lineWidth: isTitleFocused ? 2 : 0)
                        }
                }
                LabeledContent(L10n.Snippets.Detail.Folder.shortcutLabel) {
                    ShortcutRecorder(keyCombo: store.keyCombo(forFolder: folderIdentifier)) { keyCombo in
                        store.setKeyCombo(keyCombo, forFolder: folderIdentifier)
                    }
                    .frame(width: Self.controlSize.width, height: Self.controlSize.height)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                }
            } header: {
                Label(folderTitle, systemImage: "folder.fill")
                    .foregroundStyle(.primary)
            }
        }
        .formStyle(.grouped)
    }

    private var folderTitle: String {
        store.rows.first { $0.id == folderIdentifier }?.title ?? L10n.Snippets.Detail.Folder.title
    }
}

/// Snippet body.
///
/// `CPYPlaceHolderTextView` drew its placeholder in `draw(_:)`; here it is an overlay, which is
/// why that class can be deleted outright.
private struct SnippetContentView: View {

    let snippetIdentifier: String
    let store: SnippetsEditorStore

    @State private var content: String

    init(snippetIdentifier: String, store: SnippetsEditorStore) {
        self.snippetIdentifier = snippetIdentifier
        self.store = store
        _content = State(initialValue: store.content(for: snippetIdentifier))
    }

    var body: some View {
        TextEditor(text: $content)
            .font(.system(size: 14))
            .scrollContentBackground(.hidden)
            .overlay(alignment: .topLeading) {
                if content.isEmpty {
                    Text(L10n.Snippets.emptyContentPlaceholder)
                        .font(.system(size: 14))
                        .foregroundStyle(SwiftUI.Color(nsColor: .placeholderTextColor))
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SwiftUI.Color(nsColor: .textBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 8))
            .padding(10)
            .onChange(of: content) { _, newValue in
                store.updateContent(newValue, for: snippetIdentifier)
            }
    }
}
