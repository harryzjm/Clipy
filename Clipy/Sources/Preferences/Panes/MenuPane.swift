//
//  MenuPane.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI

/// Replaces `CPYMenuPreferenceViewController.xib` — the heaviest bindings file in the project
/// (14 bindings, no Swift class), including three `enabled` bindings that gated dependent
/// controls. Those are expressed here as `.disabled(...)`.
struct MenuPane: View {

    @AppStorage(Preferences.Menu.numberOfItemsPlaceInline)
    private var numberOfItemsPlaceInline = 10
    @AppStorage(Preferences.Menu.numberOfItemsPlaceInsideFolder)
    private var numberOfItemsPlaceInsideFolder = 15
    @AppStorage(Preferences.Menu.showIconInTheMenu)
    private var showIconInTheMenu = true
    @AppStorage(Preferences.Menu.addNumericKeyEquivalents)
    private var addNumericKeyEquivalents = true
    @AppStorage(Preferences.Menu.menuItemsAreMarkedWithNumbers)
    private var menuItemsAreMarkedWithNumbers = false
    @AppStorage(Preferences.Menu.showAlertBeforeClearHistory)
    private var showAlertBeforeClearHistory = true
    @AppStorage(Preferences.Menu.showToolTipOnMenuItem)
    private var showToolTipOnMenuItem = true
    @AppStorage(Preferences.Menu.maxLengthOfToolTip)
    private var maxLengthOfToolTip = 500
    @AppStorage(Preferences.Menu.showColorPreviewInTheMenu)
    private var showColorPreviewInTheMenu = true
    @AppStorage(Preferences.Menu.showImageInTheMenu)
    private var showImageInTheMenu = true
    @AppStorage(Preferences.Menu.thumbnailLength)
    private var thumbnailLength = 32

    var body: some View {
        Form {
            Section("Layout") {
                NumberRow("Number of items place inline:", unit: "items",
                          range: 0...999, value: $numberOfItemsPlaceInline)
                NumberRow("Number of items place inside a folder:", unit: "items",
                          range: 0...999, value: $numberOfItemsPlaceInsideFolder)
            }

            Section("Menu Items") {
                Toggle("Display icons in menu items", isOn: $showIconInTheMenu)
                Toggle("Show color code preview", isOn: $showColorPreviewInTheMenu)
                Toggle("Show alert panel before clear history", isOn: $showAlertBeforeClearHistory)

                Toggle("Add key equivalents to numeric keys", isOn: $addNumericKeyEquivalents)
                Toggle("Mark menu items with numbers", isOn: $menuItemsAreMarkedWithNumbers)
                    .disabled(!addNumericKeyEquivalents)
            }

            Section("Tool Tip") {
                Toggle("Show tool tip on a menu item", isOn: $showToolTipOnMenuItem)
                NumberRow("Max length of tool tip string:", unit: "chars",
                          range: 1...9999, value: $maxLengthOfToolTip)
                    .disabled(!showToolTipOnMenuItem)
            }

            Section("Image") {
                Toggle("Show Image", isOn: $showImageInTheMenu)
                NumberRow("Length:", unit: "pixel",
                          range: 1...999, value: $thumbnailLength)
                    .disabled(!showImageInTheMenu)
            }
        }
        .formStyle(.grouped)
    }
}
