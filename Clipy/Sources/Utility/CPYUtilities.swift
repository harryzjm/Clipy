//
//  CPYUtilities.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2015/06/21.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import RealmSwift

final class CPYUtilities {
    static func registerUserDefaultKeys() {
        var defaultValues = [String: Any]()

        defaultValues.updateValue(HotKeyService.defaultKeyCombos, forKey: Constants.UserDefaults.hotKeys)
        /* General */
        defaultValues.updateValue(NSNumber(value: false), forKey: Preferences.General.loginItem)
        defaultValues.updateValue(NSNumber(value: false), forKey: Constants.UserDefaults.suppressAlertForLoginItem)
        defaultValues.updateValue(NSNumber(value: 40), forKey: Preferences.General.maxHistorySize)
        defaultValues.updateValue(NSNumber(value: 0), forKey: Preferences.General.statusTypeItem)
        defaultValues.updateValue(AppDelegate.storeTypesDictionary(), forKey: Constants.UserDefaults.storeTypes)
        defaultValues.updateValue(NSNumber(value: true), forKey: Preferences.General.inputPasteCommand)
        defaultValues.updateValue(NSNumber(value: true), forKey: Preferences.General.reorderClipsAfterPasting)
        defaultValues.updateValue(NSNumber(value: 260), forKey: Preferences.General.maxWidthOfMenuItem)
        defaultValues.updateValue(NSNumber(value: 14), forKey: Preferences.General.menuFontSize)

        /* Menu */
        defaultValues.updateValue(NSNumber(value: 10), forKey: Preferences.Menu.numberOfItemsPlaceInline)
        defaultValues.updateValue(NSNumber(value: 15), forKey: Preferences.Menu.numberOfItemsPlaceInsideFolder)

        defaultValues.updateValue(NSNumber(value: true), forKey: Preferences.Menu.copySameHistory)
        defaultValues.updateValue(NSNumber(value: true), forKey: Preferences.Menu.overwriteSameHistory)

        defaultValues.updateValue(NSNumber(value: true), forKey: Preferences.Menu.showIconInTheMenu)

        defaultValues.updateValue(NSNumber(value: true), forKey: Preferences.Menu.addNumericKeyEquivalents)
        defaultValues.updateValue(NSNumber(value: false), forKey: Preferences.Menu.menuItemsAreMarkedWithNumbers)

        defaultValues.updateValue(NSNumber(value: true), forKey: Preferences.Menu.showAlertBeforeClearHistory)

        defaultValues.updateValue(NSNumber(value: true), forKey: Preferences.Menu.showToolTipOnMenuItem)
        defaultValues.updateValue(NSNumber(value: 200), forKey: Preferences.Menu.maxLengthOfToolTip)

        defaultValues.updateValue(NSNumber(value: true), forKey: Preferences.Menu.showColorPreviewInTheMenu)

        defaultValues.updateValue(NSNumber(value: true), forKey: Preferences.Menu.showImageInTheMenu)
        defaultValues.updateValue(NSNumber(value: 100), forKey: Preferences.Menu.thumbnailWidth)
        defaultValues.updateValue(NSNumber(value: 32), forKey: Preferences.Menu.thumbnailHeight)

        /* Updates */
        defaultValues.updateValue(NSNumber(value: true), forKey: Preferences.Update.enableAutomaticCheck)
        defaultValues.updateValue(NSNumber(value: 86400), forKey: Preferences.Update.checkInterval)

        /* Beta */
        defaultValues.updateValue(NSNumber(value: true), forKey: Preferences.Beta.pastePlainText)
        defaultValues.updateValue(NSNumber(value: 0), forKey: Preferences.Beta.pastePlainTextModifier)
        defaultValues.updateValue(NSNumber(value: false), forKey: Preferences.Beta.deleteHistory)
        defaultValues.updateValue(NSNumber(value: 0), forKey: Preferences.Beta.deleteHistoryModifier)
        defaultValues.updateValue(NSNumber(value: false), forKey: Preferences.Beta.pasteAndDeleteHistory)
        defaultValues.updateValue(NSNumber(value: 0), forKey: Preferences.Beta.pasteAndDeleteHistoryModifier)
        defaultValues.updateValue(NSNumber(value: false), forKey: Preferences.Beta.observerScreenshot)

        AppEnvironment.current.defaults.register(defaults: defaultValues)
        AppEnvironment.current.defaults.synchronize()
    }

    static func applicationSupportFolder() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        let basePath: String = paths.first ?? NSTemporaryDirectory()
        return (basePath as NSString).appendingPathComponent(Constants.Application.name)
    }

    static func prepareSaveToPath(_ path: String) -> Bool {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false

        if (fileManager.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue) == false {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return false
            }
        }
        return true
    }

    static func deleteData(at path: String) {
        autoreleasepool {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: path) {
                try? fileManager.removeItem(atPath: path)
            }
        }
    }
}
