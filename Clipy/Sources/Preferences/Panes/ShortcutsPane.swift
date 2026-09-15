//
//  ShortcutsPane.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI
import Magnet

/// Replaces `CPYShortcutsPreferenceViewController` and its xib.
struct ShortcutsPane: View {

    @State private var historyKeyCombo: KeyCombo?
    @State private var snippetKeyCombo: KeyCombo?
    @State private var restartKeyCombo: KeyCombo?
    @State private var didLoad = false

    var body: some View {
        Form {
            Section(L10n.menu) {
                recorder("History:", combo: $historyKeyCombo) { combo in
                    AppEnvironment.current.hotKeyService.change(with: .history, keyCombo: combo)
                }
                recorder("Snippets:", combo: $snippetKeyCombo) { combo in
                    AppEnvironment.current.hotKeyService.change(with: .snippet, keyCombo: combo)
                }
                recorder("Restart:", combo: $restartKeyCombo) { combo in
                    AppEnvironment.current.hotKeyService.changeRestartKeyCombo(combo)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: loadCurrentKeyCombos)
    }

    private func recorder(_ title: String,
                          combo: Binding<KeyCombo?>,
                          apply: @escaping (KeyCombo?) -> Void) -> some View {
        LabeledContent(title) {
            ShortcutRecorder(keyCombo: combo.wrappedValue) { newValue in
                combo.wrappedValue = newValue
                apply(newValue)
            }
            .frame(width: 170, height: 26)
        }
    }

    private func loadCurrentKeyCombos() {
        guard !didLoad else { return }
        didLoad = true
        let service = AppEnvironment.current.hotKeyService
        historyKeyCombo = service.historyKeyCombo
        snippetKeyCombo = service.snippetKeyCombo
        restartKeyCombo = service.restartKeyCombo
    }
}
