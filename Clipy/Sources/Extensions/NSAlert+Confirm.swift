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
    /// Modal confirmation for anything that throws data away: clearing history or snippets.
    /// Always asks — there is no "don't ask again" for either, because neither is undoable.
    ///
    /// `title` also labels the destructive button.
    static func confirmDestructive(title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: title)
        alert.addButton(withTitle: L10n.Common.cancel)

        NSApp.activate(ignoringOtherApps: true)

        return alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn
    }
}
