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
/// subscriptions in `MenuManager` (the status icon) and `AppDelegate` keep firing as before. The
/// menu-shape keys have no subscriber at all any more — `FilterMenu` and `SnippetMenu` snapshot
/// them when they are built, which is on every popup.
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
            Section(L10n.Preferences.General.SectionHeader.behavior) {
                Toggle(L10n.Preferences.General.ToggleLabel.launchOnLogin, isOn: $loginItem)
                Toggle(L10n.Preferences.General.ToggleLabel.inputPasteCommand, isOn: $inputPasteCommand)
            }

            Section(L10n.Preferences.General.SectionHeader.clipboardHistory) {
                NumberRow(L10n.Preferences.General.UnitLabel.keepFor, unit: L10n.Preferences.General.Unit.days,
                          range: 1...3650, value: $maxHistoryDays)
                NumberRow(L10n.Preferences.General.UnitLabel.maxDisplaySize, unit: L10n.Preferences.General.Unit.items,
                          range: 1...9999, value: $maxShowHistorySize)
            }

            Section(L10n.Preferences.General.SectionHeader.appearance) {
                // The old popup bound `selectedTag` with tags 1 (black) and 2 (white), while
                // `MenuManager.StatusType` is 0 = black, 1 = white — so picking "black" stored 1
                // and produced the white icon, and picking "white" stored 2, fell through
                // `?? .black` and produced the black one. Tagging by `rawValue` makes the label
                // match the icon; already-stored 0/1 values keep rendering exactly as they do now.
                // The xib's untagged "None" entry stored 0 and also resolved to black, so it never
                // hid the icon — it is dropped rather than carried over as a lie.
                Picker(L10n.Preferences.General.PickerLabel.statusBarIconStyle, selection: $statusTypeItem) {
                    ForEach(MenuManager.StatusType.allCases) { type in
                        Text(type.title).tag(type.rawValue)
                    }
                }
                NumberRow(L10n.Preferences.General.UnitLabel.maxWidth, unit: L10n.Preferences.General.Unit.px,
                          range: 1...9999, value: $maxWidthOfMenuItem)
                NumberRow(L10n.Preferences.General.UnitLabel.menuFontSize, unit: L10n.Preferences.General.Unit.px,
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
        case .black: return L10n.Preferences.General.StatusType.black
        case .white: return L10n.Preferences.General.StatusType.white
        }
    }
}
