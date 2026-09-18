//
//  SnippetMenuConfig.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation

/// The preferences a snippet menu reads, snapshotted once when the menu is built.
///
/// Deliberately smaller than `FilterMenuConfig`: these two keys are everything a snippet item
/// has ever looked at. The title is trimmed to a hardcoded 20 characters and the tooltip is set
/// unconditionally, so the width / tooltip / inline-count preferences never reach this menu.
struct SnippetMenuConfig {
    let isMarkWithNumber: Bool
    let showIconInTheMenu: Bool

    static func current() -> SnippetMenuConfig {
        let defaults = AppEnvironment.current.defaults

        return SnippetMenuConfig(
            isMarkWithNumber: defaults.bool(forKey: Preferences.Menu.menuItemsAreMarkedWithNumbers),
            showIconInTheMenu: defaults.bool(forKey: Preferences.Menu.showIconInTheMenu))
    }
}
