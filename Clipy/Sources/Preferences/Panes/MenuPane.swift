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
    @AppStorage(Preferences.Menu.filterMatchMode)
    private var filterMatchMode = FilterMatchMode.like.rawValue
    /// Read-only here: the picker edits `tokenizerDraft`, and the preference only moves once a
    /// switch has committed.
    @AppStorage(Preferences.Menu.ftsTokenizer)
    private var storedTokenizer = ClipFtsTokenizer.verbatim.rawValue
    // Qualified: the app's own `Environment` (the service locator) shadows SwiftUI's.
    @SwiftUI.Environment(FtsTokenizerDraft.self)
    private var tokenizerDraft: FtsTokenizerDraft
    @AppStorage(Preferences.Menu.showToolTipOnMenuItem)
    private var showToolTipOnMenuItem = true
    @AppStorage(Preferences.Menu.maxLengthOfToolTip)
    private var maxLengthOfToolTip = 500

    /// Rows that appear or go away with a picker change — the tokenizer row with FTS, the pending
    /// note with a changed tokenizer.
    ///
    /// Keyed on the values (`.animation(_:value:)`) rather than set on the picker bindings:
    /// `@AppStorage` writes through `UserDefaults` and re-renders from its change notification,
    /// which drops a binding's transaction — so `$filterMatchMode.animation()` never animated.
    private static let revealAnimation = Animation.easeInOut(duration: 0.2)
    private static let revealTransition = AnyTransition.opacity.combined(with: .move(edge: .top))

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
                Toggle(L10n.Preferences.Menu.ToggleLabel.addNumericKeys, isOn: $addNumericKeyEquivalents)
                Toggle(L10n.Preferences.Menu.ToggleLabel.markWithNumbers, isOn: $menuItemsAreMarkedWithNumbers)
                    .disabled(!addNumericKeyEquivalents)
            }

            Section(L10n.Preferences.Menu.SectionHeader.filter) {
                Picker(L10n.Preferences.Menu.PickerLabel.matchMode, selection: $filterMatchMode) {
                    ForEach(FilterMatchMode.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)

                if filterMatchMode == FilterMatchMode.fts.rawValue {
                    tokenizerPicker
                        .transition(Self.revealTransition)
                }
            }

            Section(L10n.Preferences.Menu.SectionHeader.toolTip) {
                Toggle(L10n.Preferences.Menu.ToggleLabel.showToolTip, isOn: $showToolTipOnMenuItem)
                NumberRow(L10n.Preferences.Menu.UnitLabel.tooltipLength, unit: L10n.Preferences.Menu.Unit.chars,
                          range: 1...9999, value: $maxLengthOfToolTip)
                    .disabled(!showToolTipOnMenuItem)
            }
        }
        .formStyle(.grouped)
        .animation(Self.revealAnimation, value: filterMatchMode)
        .animation(Self.revealAnimation, value: tokenizerDraft.selection)
    }

    /// Bound to the draft, never to the preference: switching clears the history, so it is only
    /// applied — after asking — once the window closes.
    @ViewBuilder
    private var tokenizerPicker: some View {
        @Bindable var draft = tokenizerDraft
        Picker(L10n.Preferences.Menu.PickerLabel.tokenizer, selection: $draft.selection) {
            ForEach(ClipFtsTokenizer.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)

        if draft.selection.rawValue != storedTokenizer {
            Text(L10n.Preferences.Menu.Tokenizer.pendingNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .transition(Self.revealTransition)
        }
    }
}
