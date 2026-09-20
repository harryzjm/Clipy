//
//  NSMenu+Highlight.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Cocoa

extension NSMenu {

    /// Moves AppKit's own highlight, or clears it with `nil`.
    ///
    /// There is no public API for this, and it is needed for exactly one reason: replacing
    /// `items` while an item is highlighted misbehaves, so a filtering menu clears the highlight
    /// first and puts it on the new first row afterwards. Guarded by `responds(to:)` — losing the
    /// selector costs the auto-selection, not the menu.
    func highlight(menuItem: NSMenuItem?) {
        let highlightItem = NSSelectorFromString("highlightItem:")
        if responds(to: highlightItem) {
            perform(highlightItem, with: menuItem)
        }
    }
}
