//
//  Constants.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/04/17.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation

struct Constants {
    struct Application {
        #if DEBUG
            static let name = "Clipy_Debug"
        #else
            static let name = "Clipy"
        #endif
        static let appcastURL = URL(string: "https://clipy-app.com/appcast.xml")!
    }

    struct Menu {
        static let history = "HistoryMenu"
        static let snippet = "SnippetsMenu"
        static let config = "ConfigMenu"
    }

    struct Common {
        static let index = "index"
        static let title = "title"
        static let snippets = "snippets"
        static let content = "content"
        static let selector = "selector"
        static let draggedDataType = "public.data"
    }

    struct UserDefaults {
        static let hotKeys = "kCPYPrefHotKeysKey"
        static let storeTypes = "kCPYPrefStoreTypesKey"
        static let suppressAlertForLoginItem = "suppressAlertForLoginItem"
        static let suppressAlertForDeleteSnippet = "kCPYSuppressAlertForDeleteSnippet"
        static let excludeApplications = "kCPYExcludeApplications"
    }

    struct Notification {
        static let closeSnippetEditor = "kCPYSnippetEditorWillCloseNotification"
    }

    struct Config {
        static let fileType = "json"
    }

    struct HotKey {
        static let historyKeyCombo = "kCPYHotKeyHistoryKeyCombo"
        static let snippetKeyCombo = "kCPYHotKeySnippetKeyCombo"
        static let restartKeyCombo = "kCPYHotKeyRestartKeyCombo"
        static let migrateNewKeyCombo = "kCPYMigrateNewKeyCombo"
        static let folderKeyCombos = "kCPYFolderKeyCombos"
    }
}
