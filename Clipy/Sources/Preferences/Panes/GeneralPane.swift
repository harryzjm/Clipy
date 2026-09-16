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
/// subscriptions in `MenuManager` and `AppDelegate` keep firing as before.
struct GeneralPane: View {

    @AppStorage(Preferences.General.loginItem)
    private var loginItem = false
    @AppStorage(Preferences.General.inputPasteCommand)
    private var inputPasteCommand = true
    @AppStorage(Preferences.General.maxHistoryDays)
    private var maxHistoryDays = 30
    @AppStorage(Preferences.General.maxShowHistorySize)
    private var maxShowHistorySize = 25
    @AppStorage(Preferences.General.statusTypeItem)
    private var statusTypeItem = MenuManager.StatusType.black.rawValue
    @AppStorage(Preferences.General.maxWidthOfMenuItem)
    private var maxWidthOfMenuItem = 260
    @AppStorage(Preferences.General.menuFontSize)
    private var menuFontSize = 14

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Launch on Login", isOn: $loginItem)
                Toggle("Input \"⌘ + V\" after menu item selection", isOn: $inputPasteCommand)
            }

            Section("Clipboard History") {
                NumberRow("Keep clipboard history for:", unit: "days",
                          range: 1...3650, value: $maxHistoryDays)
                NumberRow("Max display clipboard size:", unit: "items",
                          range: 1...9999, value: $maxShowHistorySize)
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
