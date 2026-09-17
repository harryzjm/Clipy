//
//  BetaPane.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI

/// Replaces `CPYBetaPreferenceViewController` and its xib (10 bindings across two
/// `NSUserDefaultsController` instances).
struct BetaPane: View {

    @AppStorage(Preferences.Beta.pastePlainText)
    private var pastePlainText = true
    @AppStorage(Preferences.Beta.pastePlainTextModifier)
    private var pastePlainTextModifier = ModifierKey.command.rawValue
    @AppStorage(Preferences.Beta.deleteHistory)
    private var deleteHistory = false
    @AppStorage(Preferences.Beta.deleteHistoryModifier)
    private var deleteHistoryModifier = ModifierKey.command.rawValue
    @AppStorage(Preferences.Beta.pasteAndDeleteHistory)
    private var pasteAndDeleteHistory = false
    @AppStorage(Preferences.Beta.pasteAndDeleteHistoryModifier)
    private var pasteAndDeleteHistoryModifier = ModifierKey.command.rawValue
    @AppStorage(Preferences.Beta.observerScreenshot)
    private var observeScreenshot = false

    /// Raw values match `PasteService.isPressedModifier(_:)`.
    private enum ModifierKey: Int, CaseIterable, Identifiable {
        case command = 0, shift = 1, control = 2, option = 3

        var id: Self { self }
        var title: String {
            switch self {
            case .command: return L10n.Preferences.Beta.ModifierKey.command
            case .shift: return L10n.Preferences.Beta.ModifierKey.shift
            case .control: return L10n.Preferences.Beta.ModifierKey.control
            case .option: return L10n.Preferences.Beta.ModifierKey.alt
            }
        }
    }

    var body: some View {
        Form {
            Section(L10n.Preferences.Beta.SectionHeader.action) {
                modifierRow(L10n.Preferences.Beta.ActionLabel.pastePlainText,
                            isOn: $pastePlainText, modifier: $pastePlainTextModifier)
                modifierRow(L10n.Preferences.Beta.ActionLabel.deleteHistory,
                            isOn: $deleteHistory, modifier: $deleteHistoryModifier)
                modifierRow(L10n.Preferences.Beta.ActionLabel.pasteAndDelete,
                            isOn: $pasteAndDeleteHistory, modifier: $pasteAndDeleteHistoryModifier)
            }

            Section(L10n.Preferences.Beta.SectionHeader.screenshot) {
                Toggle(L10n.Preferences.Beta.ToggleLabel.saveScreenshots, isOn: $observeScreenshot)
            }

            Section {
                LabeledContent(L10n.Preferences.Beta.Label.version, value: Bundle.main.appVersion ?? "")
                Text(L10n.Preferences.Beta.Description.betaSettings)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func modifierRow(_ title: String,
                             isOn: Binding<Bool>,
                             modifier: Binding<Int>) -> some View {
        LabeledContent {
            Picker(title, selection: modifier) {
                ForEach(ModifierKey.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .labelsHidden()
            .frame(width: 130)
            .disabled(!isOn.wrappedValue)
        } label: {
            Toggle(title, isOn: isOn)
        }
    }
}
