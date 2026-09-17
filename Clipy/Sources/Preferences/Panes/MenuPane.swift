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
    @AppStorage(Preferences.Menu.filterMatchMode)
    private var filterMatchMode = FilterMatchMode.like.rawValue
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
            Section(L10n.Preferences.Menu.SectionHeader.layout) {
                NumberRow(L10n.Preferences.Menu.UnitLabel.inlineItems, unit: L10n.Preferences.General.Unit.items,
                          range: 0...999, value: $numberOfItemsPlaceInline)
                NumberRow(L10n.Preferences.Menu.UnitLabel.folderItems, unit: L10n.Preferences.General.Unit.items,
                          range: 0...999, value: $numberOfItemsPlaceInsideFolder)
            }

            Section(L10n.Preferences.Menu.SectionHeader.menuItems) {
                Toggle(L10n.Preferences.Menu.ToggleLabel.showIcon, isOn: $showIconInTheMenu)
                Toggle(L10n.Preferences.Menu.ToggleLabel.showColorPreview, isOn: $showColorPreviewInTheMenu)
                Toggle(L10n.Preferences.Menu.ToggleLabel.showAlertBeforeClear, isOn: $showAlertBeforeClearHistory)

                Toggle(L10n.Preferences.Menu.ToggleLabel.addNumericKeys, isOn: $addNumericKeyEquivalents)
                Toggle(L10n.Preferences.Menu.ToggleLabel.markWithNumbers, isOn: $menuItemsAreMarkedWithNumbers)
                    .disabled(!addNumericKeyEquivalents)
            }

            Section(L10n.Preferences.Menu.SectionHeader.filter) {
                Picker(L10n.Preferences.Menu.PickerLabel.matchMode, selection: $filterMatchMode) {
                    ForEach(FilterMatchMode.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }

            Section(L10n.Preferences.Menu.SectionHeader.toolTip) {
                Toggle(L10n.Preferences.Menu.ToggleLabel.showToolTip, isOn: $showToolTipOnMenuItem)
                NumberRow(L10n.Preferences.Menu.UnitLabel.tooltipLength, unit: L10n.Preferences.Menu.Unit.chars,
                          range: 1...9999, value: $maxLengthOfToolTip)
                    .disabled(!showToolTipOnMenuItem)
            }

            Section(L10n.Preferences.Menu.SectionHeader.image) {
                Toggle(L10n.Preferences.Menu.ToggleLabel.showImage, isOn: $showImageInTheMenu)
                NumberRow(L10n.Preferences.Menu.UnitLabel.thumbnailLength, unit: L10n.Preferences.Menu.Unit.pixel,
                          range: 1...999, value: $thumbnailLength)
                    .disabled(!showImageInTheMenu)
            }
        }
        .formStyle(.grouped)
    }
}
