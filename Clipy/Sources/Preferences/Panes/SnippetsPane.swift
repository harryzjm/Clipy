//
//  SnippetsPane.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI

/// Chrome switches for the source editor in the snippets window.
///
/// All three are on by default, matching what `CodeEditSourceEditor` itself defaults to — the
/// point of the pane is that the detail column is narrow enough that someone will want the
/// minimap, or the gutter, out of the way. `SnippetContentView` reads the same keys through
/// `@AppStorage`, so a toggle lands on an open editor immediately.
struct SnippetsPane: View {

    @AppStorage(Preferences.Snippets.editorShowGutter)
    private var editorShowGutter = true
    @AppStorage(Preferences.Snippets.editorWrapLines)
    private var editorWrapLines = true
    @AppStorage(Preferences.Snippets.editorShowMinimap)
    private var editorShowMinimap = true

    var body: some View {
        Form {
            Section(L10n.Preferences.Snippets.SectionHeader.editor) {
                Toggle(L10n.Preferences.Snippets.ToggleLabel.showGutter, isOn: $editorShowGutter)
                Toggle(L10n.Preferences.Snippets.ToggleLabel.wrapLines, isOn: $editorWrapLines)
                Toggle(L10n.Preferences.Snippets.ToggleLabel.showMinimap, isOn: $editorShowMinimap)
            }
        }
        .formStyle(.grouped)
    }
}
