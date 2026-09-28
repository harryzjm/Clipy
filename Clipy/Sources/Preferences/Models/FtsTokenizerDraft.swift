//
//  FtsTokenizerDraft.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import SwiftUI

/// The tokenizer picked in the Menu pane, held back until the Preferences window closes.
///
/// Switching the FTS tokenizer clears the history, so nothing is applied while the window is
/// open. The picker writes only here; `settle()` runs once the window has closed and asks — only
/// when the tokenizer would really change, with FTS still the match mode. Flipping the picker back
/// and forth, or touching only the match mode, ends in no prompt and no change.
///
/// Owned by `PreferencesRootView` rather than `MenuPane`: the pane is rebuilt each time the
/// sidebar selection changes, which would drop a pick made before visiting another pane.
@Observable
final class FtsTokenizerDraft {

    var selection: ClipFtsTokenizer

    init() {
        selection = Self.stored
    }

    /// What `clip_fts` is built with, as mirrored into the preference.
    static var stored: ClipFtsTokenizer {
        AppEnvironment.current.defaults.string(forKey: Preferences.Menu.ftsTokenizer)
            .flatMap(ClipFtsTokenizer.init(rawValue:)) ?? .verbatim
    }

    func reset() {
        selection = Self.stored
    }

    /// Applies a net change of tokenizer, after confirming it. Call after the window has closed.
    ///
    /// The draft goes back to the stored value either way: on Cancel nothing was written, and on
    /// Switch the preference only moves once the rebuild commits — `reset()` runs again then.
    /// With FTS no longer the match mode the pick is dropped silently: it is invisible, and not
    /// worth clearing the history for.
    func settle() {
        let target = selection
        let current = Self.stored
        reset()

        let defaults = AppEnvironment.current.defaults
        guard FilterMatchMode(rawValue: defaults.integer(forKey: Preferences.Menu.filterMatchMode)) == .fts,
              target != current else { return }

        guard NSAlert.confirmDestructive(title: L10n.Alert.SwitchTokenizer.title,
                                         message: L10n.Alert.SwitchTokenizer.message(target.title),
                                         confirmTitle: L10n.Alert.SwitchTokenizer.confirm) else { return }

        AppEnvironment.current.clipService.switchFtsTokenizer(to: target) { [weak self] _ in
            self?.reset()
        }
    }
}
