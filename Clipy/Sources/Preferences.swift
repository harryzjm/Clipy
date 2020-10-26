// 
//  Preferences.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
// 
//  Created by Aphro Hares on 2020/10/26.
// 
//  Copyright © 2015-2020 Clipy Project.
//

import Foundation

struct Preferences {
    struct General {
        static let loginItem = "loginItem"
        static let inputPasteCommand = "kCPYPrefInputPasteCommandKey"

        static let maxHistorySize = "kCPYPrefMaxHistorySizeKey"
        static let reorderClipsAfterPasting = "kCPYPrefReorderClipsAfterPasting"

        static let showStatusItem = "kCPYPrefShowStatusItemKey"
    }

    struct Menu {
        static let numberOfItemsPlaceInline = "kCPYPrefNumberOfItemsPlaceInlineKey"
        static let numberOfItemsPlaceInsideFolder = "kCPYPrefNumberOfItemsPlaceInsideFolderKey"
        static let maxWidthOfMenuItem = "kCPYPrefMaxWidthOfMenuItemKey"

        static let copySameHistory = "kCPYPrefCopySameHistroy"
        static let overwriteSameHistory = "kCPYPrefOverwriteSameHistroy"

        static let menuItemsAreMarkedWithNumbers = "menuItemsAreMarkedWithNumbers"

        static let showIconInTheMenu = "kCPYPrefShowIconInTheMenuKey"

        static let addNumericKeyEquivalents = "addNumericKeyEquivalents"

        static let addClearHistoryMenuItem = "kCPYPrefAddClearHistoryMenuItemKey"
        static let showAlertBeforeClearHistory = "kCPYPrefShowAlertBeforeClearHistoryKey"

        static let showToolTipOnMenuItem = "showToolTipOnMenuItem"
        static let maxLengthOfToolTip = "maxLengthOfToolTipKey"

        static let showColorPreviewInTheMenu = "kCPYPrefShowColorPreviewInTheMenu"

        static let showImageInTheMenu = "showImageInTheMenu"
        static let thumbnailWidth = "thumbnailWidth"
        static let thumbnailHeight = "thumbnailHeight"
    }

    struct Beta {
        static let pastePlainText = "kCPYBetaPastePlainText"
        static let pastePlainTextModifier = "kCPYBetaPastePlainTextModifier"
        static let deleteHistory = "kCPYBetaDeleteHistory"
        static let deleteHistoryModifier = "kCPYBetaDeleteHistoryModifier"
        static let pasteAndDeleteHistory = "kCPYBetaPasteAndDeleteHistory"
        static let pasteAndDeleteHistoryModifier = "kCPYBetapasteAndDeleteHistoryModifier"

        static let observerScreenshot = "kCPYBetaObserveScreenshot"
    }

    struct Update {
        static let enableAutomaticCheck = "kCPYEnableAutomaticCheckKey"
        static let checkInterval = "kCPYUpdateCheckIntervalKey"
    }
}
