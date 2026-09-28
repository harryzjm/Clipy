//
//  NSAlert+Confirm.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Cocoa

extension NSAlert {
    /// Modal confirmation for anything that throws data away: clearing history or snippets, and
    /// switching the FTS tokenizer (which clears history). Always asks — there is no "don't ask
    /// again" for any of them, because none is undoable.
    ///
    /// `confirmTitle` labels the destructive button and defaults to `title`.
    static func confirmDestructive(title: String, message: String, confirmTitle: String? = nil) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirmTitle ?? title)
        alert.addButton(withTitle: L10n.Common.cancel)

        NSApp.activate(ignoringOtherApps: true)

        return alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn
    }
}
