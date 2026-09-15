//
//  PreferencesRootView.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI

/// Root of the `Settings` scene.
///
/// Replaces `CPYPreferencesWindowController`, which drove a hand-built tab strip out of six
/// `NSButton`/`NSImageView`/`NSTextField` outlet triples, swapped panes by removing every
/// subview except the toolbar, and resized the window by computing frames itself.
struct PreferencesRootView: View {

    enum Pane: String, CaseIterable, Identifiable {
        case general, menu, type, excluded, shortcuts, beta

        var id: Self { self }

        var title: String {
            switch self {
            case .general: return L10n.general
            case .menu: return L10n.menu
            case .type: return L10n.type
            case .excluded: return "Excluded Apps"
            case .shortcuts: return L10n.shortcuts
            case .beta: return "Beta"
            }
        }

        /// SF Symbols rather than the old `Asset.Preference.*` on/off PNG pairs: they pick up
        /// the system tint and the macOS 26 material treatment automatically.
        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .menu: return "list.bullet"
            case .type: return "doc.on.doc"
            case .excluded: return "nosign"
            case .shortcuts: return "command"
            case .beta: return "flask"
            }
        }
    }

    @State private var selection: Pane? = .general

    private var current: Pane { selection ?? .general }

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.symbol)
                    .tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            detail
                .navigationTitle(current.title)
                .frame(minWidth: 480, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity)
        }
        .frame(minWidth: 680, minHeight: 470)
    }

    @ViewBuilder
    private var detail: some View {
        switch current {
        case .general: GeneralPane()
        case .menu: MenuPane()
        case .type: TypePane()
        case .excluded: ExcludeAppPane()
        case .shortcuts: ShortcutsPane()
        case .beta: BetaPane()
        }
    }
}
