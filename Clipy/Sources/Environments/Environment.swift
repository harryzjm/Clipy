//
//  Environment.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2017/08/10.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation

struct Environment {

    // MARK: - Properties
    let clipService: ClipService
    let hotKeyService: HotKeyService
    let dataCleanService: DataCleanService
    let pasteService: PasteService
    let excludeAppService: ExcludeAppService
    let accessibilityService: AccessibilityService
    let menuManager: MenuManager
    let secretService: SecretService
    let box: ClipyBox
    let assetStore: ClipAssetStore

    let defaults: UserDefaults

    // MARK: - Initialize
    /// The environment owns one secret and both stores: `secretService` holds the installation
    /// key, everything that reads or writes a database is handed this one `box`, and everything
    /// that touches a clip's out-of-database state — payload files, thumbnails — is handed this
    /// one `assetStore`, instead of reaching for a singleton.
    ///
    /// `secretService` is the only default argument here that does any work, and it sits upstream
    /// of both stores: they are built from it rather than resolving the key separately, so they
    /// cannot disagree and the keychain is read once per launch.
    ///
    /// Everything downstream of it takes `nil` rather than a default value because Swift default
    /// arguments cannot refer to another parameter. Passing one explicitly — which
    /// `AppEnvironment.push` and `replaceCurrent` always do — carries it through untouched.
    init(secretService: SecretService = SecretService(),
         box: ClipyBox? = nil,
         assetStore: ClipAssetStore? = nil,
         clipService: ClipService? = nil,
         hotKeyService: HotKeyService? = nil,
         dataCleanService: DataCleanService? = nil,
         pasteService: PasteService? = nil,
         excludeAppService: ExcludeAppService = ExcludeAppService(applications: []),
         accessibilityService: AccessibilityService = AccessibilityService(),
         menuManager: MenuManager? = nil,
         defaults: UserDefaults = .standard) {
        let box = box ?? ClipyBox(secretCode: secretService.secretCode, recovery: DatabaseResetPrompt())
        let assetStore = assetStore ?? ClipAssetStore(secretService: secretService,
                                                      root: CPYUtilities.applicationSupportFolder())

        self.secretService = secretService
        self.box = box
        self.assetStore = assetStore
        self.clipService = clipService ?? ClipService(box: box, assetStore: assetStore)
        self.hotKeyService = hotKeyService ?? HotKeyService(box: box)
        self.dataCleanService = dataCleanService ?? DataCleanService(box: box, assetStore: assetStore)
        self.pasteService = pasteService ?? PasteService(assetStore: assetStore)
        self.excludeAppService = excludeAppService
        self.accessibilityService = accessibilityService
        self.menuManager = menuManager ?? MenuManager(box: box)
        self.defaults = defaults
    }

}
