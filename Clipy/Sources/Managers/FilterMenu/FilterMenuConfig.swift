// 
//  FilterMenuConfig.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
// 
//  Created by Aphro Hares on 2020/10/27.
// 
//  Copyright © 2015-2020 Clipy Project.
//

import Foundation
import Cocoa

struct FilterMenuConfig {
    let isMarkWithNumber: Bool
    let addNumericKeyEquivalents: Bool

    let isShowToolTip: Bool

    let maxWidthOfMenuItem: CGFloat

    let placeInLine: Int
    let placeInsideFolder: Int
    let maxShowHistory: Int

    let matchMode: FilterMatchMode
    /// Only consulted in `.fts` mode, where it decides how the query is split into tokens.
    let ftsTokenizer: ClipFtsTokenizer

    let showIconInTheMenu: Bool

    let menuFontSize: CGFloat

    static func current() -> FilterMenuConfig {
        let defaults = AppEnvironment.current.defaults

        return FilterMenuConfig(
            isMarkWithNumber: defaults.bool(forKey: Preferences.Menu.menuItemsAreMarkedWithNumbers),
            addNumericKeyEquivalents: defaults.bool(forKey: Preferences.Menu.addNumericKeyEquivalents),
            isShowToolTip: defaults.bool(forKey: Preferences.Menu.showToolTipOnMenuItem),
            maxWidthOfMenuItem: CGFloat(defaults.float(forKey: Preferences.General.maxWidthOfMenuItem)),
            placeInLine: defaults.integer(forKey: Preferences.Menu.numberOfItemsPlaceInline),
            placeInsideFolder: defaults.integer(forKey: Preferences.Menu.numberOfItemsPlaceInsideFolder),
            maxShowHistory: defaults.integer(forKey: Preferences.General.maxShowHistorySize),
            matchMode: FilterMatchMode(rawValue: defaults.integer(forKey: Preferences.Menu.filterMatchMode)) ?? .like,
            ftsTokenizer: defaults.string(forKey: Preferences.Menu.ftsTokenizer).flatMap(ClipFtsTokenizer.init(rawValue:)) ?? .verbatim,
            showIconInTheMenu: defaults.bool(forKey: Preferences.Menu.showIconInTheMenu),
            menuFontSize: CGFloat(defaults.float(forKey: Preferences.General.menuFontSize)))
    }
}
