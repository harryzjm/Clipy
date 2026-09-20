//
//  SnippetMenuConfig.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Cocoa

/// The preferences a snippet menu reads, snapshotted once when the menu is built.
///
/// Deliberately smaller than `FilterMenuConfig`: the title is trimmed to a hardcoded 20
/// characters and the tooltip is set unconditionally, so the width / tooltip / inline-count
/// preferences never reach this menu. The font size is here only because a filtered row draws
/// an `attributedTitle`, which has to name its own font.
struct SnippetMenuConfig {
    let isMarkWithNumber: Bool
    let showIconInTheMenu: Bool
    let menuFontSize: CGFloat

    /// The font size defaults rather than being required: the test target never runs
    /// `CPYUtilities.registerUserDefaultKeys()`, and a menu built with a 0pt font draws nothing.
    init(isMarkWithNumber: Bool, showIconInTheMenu: Bool, menuFontSize: CGFloat = NSFont.systemFontSize) {
        self.isMarkWithNumber = isMarkWithNumber
        self.showIconInTheMenu = showIconInTheMenu
        self.menuFontSize = menuFontSize
    }

    static func current() -> SnippetMenuConfig {
        let defaults = AppEnvironment.current.defaults
        let fontSize = CGFloat(defaults.float(forKey: Preferences.General.menuFontSize))

        return SnippetMenuConfig(
            isMarkWithNumber: defaults.bool(forKey: Preferences.Menu.menuItemsAreMarkedWithNumbers),
            showIconInTheMenu: defaults.bool(forKey: Preferences.Menu.showIconInTheMenu),
            menuFontSize: fontSize > 0 ? fontSize : NSFont.systemFontSize)
    }
}
