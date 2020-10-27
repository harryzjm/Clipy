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

struct FilterMenuConfig {
    let isMarkWithNumber: Bool
    let addNumericKeyEquivalents: Bool

    let isShowToolTip: Bool
    let isShowImage: Bool
    let isShowColorCode: Bool

    let maxWidthOfMenuItem: CGFloat

    let placeInLine: Int
    let placeInsideFolder: Int
    let maxHistory: Int

    static func current() -> FilterMenuConfig {
        let defaults = AppEnvironment.current.defaults
        return FilterMenuConfig(
            isMarkWithNumber: defaults.bool(forKey: Preferences.Menu.menuItemsAreMarkedWithNumbers),
            addNumericKeyEquivalents: defaults.bool(forKey: Preferences.Menu.addNumericKeyEquivalents),
            isShowToolTip: defaults.bool(forKey: Preferences.Menu.showToolTipOnMenuItem),
            isShowImage: defaults.bool(forKey: Preferences.Menu.showImageInTheMenu),
            isShowColorCode: defaults.bool(forKey: Preferences.Menu.showColorPreviewInTheMenu),
            maxWidthOfMenuItem: CGFloat(defaults.float(forKey: Preferences.Menu.maxWidthOfMenuItem)),
            placeInLine: defaults.integer(forKey: Preferences.Menu.numberOfItemsPlaceInline),
            placeInsideFolder: defaults.integer(forKey: Preferences.Menu.numberOfItemsPlaceInsideFolder),
            maxHistory: defaults.integer(forKey: Preferences.General.maxHistorySize))
    }
}
