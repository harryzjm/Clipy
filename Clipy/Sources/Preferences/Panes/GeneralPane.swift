//
//  GeneralPane.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI

/// Replaces `CPYGeneralPreferenceViewController.xib`, which had no Swift class at all — it was
/// loaded through a bare `NSViewController(nibName:)` and its whole behaviour lived in eight
/// Cocoa Bindings against the shared `NSUserDefaultsController`.
///
/// The keys and their value semantics are unchanged, so the existing `defaults.rx.observe(...)`
/// subscriptions in `MenuManager`, `FilterMenu` and `AppDelegate` keep firing as before.
struct GeneralPane: View {

    @AppStorage(Preferences.General.loginItem)
    private var loginItem = false
    @AppStorage(Preferences.General.inputPasteCommand)
    private var inputPasteCommand = true
    @AppStorage(Preferences.General.maxHistorySize)
    private var maxHistorySize = 100
    @AppStorage(Preferences.General.maxShowHistorySize)
    private var maxShowHistorySize = 25
    @AppStorage(Preferences.General.reorderClipsAfterPasting)
    private var sortOrder = SortOrder.lastUsed.rawValue
    @AppStorage(Preferences.General.statusTypeItem)
    private var statusTypeItem = MenuManager.StatusType.black.rawValue
    @AppStorage(Preferences.General.maxWidthOfMenuItem)
    private var maxWidthOfMenuItem = 260
    @AppStorage(Preferences.General.menuFontSize)
    private var menuFontSize = 14

    /// The old popup bound `selectedIndex`, so the stored value is the row index.
    /// `FilterMenu` reads it back as a Bool (`ascending = !bool`), so the order must not change.
    private enum SortOrder: Int, CaseIterable, Identifiable {
        case dateCreated = 0
        case lastUsed = 1

        var id: Self { self }
        var title: String {
            switch self {
            case .dateCreated: return "Date Created"
            case .lastUsed: return "Last Used"
            }
        }
    }

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Launch on Login", isOn: $loginItem)
                Toggle("Input \"⌘ + V\" after menu item selection", isOn: $inputPasteCommand)
            }

            Section("Clipboard History") {
                NumberRow("Max clipboard history size:", unit: "items",
                          range: 1...9999, value: $maxHistorySize)
                NumberRow("Max display clipboard size:", unit: "items",
                          range: 1...9999, value: $maxShowHistorySize)
                Picker("Sort history order by:", selection: $sortOrder) {
                    ForEach(SortOrder.allCases) { Text($0.title).tag($0.rawValue) }
                }
            }

            Section("Appearance") {
                // The old popup bound `selectedTag` with tags 1 (black) and 2 (white), while
                // `MenuManager.StatusType` is 0 = black, 1 = white — so picking "black" stored 1
                // and produced the white icon, and picking "white" stored 2, fell through
                // `?? .black` and produced the black one. Tagging by `rawValue` makes the label
                // match the icon; already-stored 0/1 values keep rendering exactly as they do now.
                // The xib's untagged "None" entry stored 0 and also resolved to black, so it never
                // hid the icon — it is dropped rather than carried over as a lie.
                Picker("Status Bar icon style:", selection: $statusTypeItem) {
                    ForEach(MenuManager.StatusType.allCases) { type in
                        Text(type.title).tag(type.rawValue)
                    }
                }
                NumberRow("Max width of menu item:", unit: "px",
                          range: 1...9999, value: $maxWidthOfMenuItem)
                NumberRow("The menu icon size", unit: "px",
                          range: 1...100, value: $menuFontSize)
            }
        }
        .formStyle(.grouped)
    }
}

extension MenuManager.StatusType: CaseIterable, Identifiable {
    static var allCases: [MenuManager.StatusType] { [.black, .white] }
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .black: return "Black"
        case .white: return "White"
        }
    }
}
