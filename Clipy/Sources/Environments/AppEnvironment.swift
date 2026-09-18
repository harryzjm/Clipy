//
//  AppEnvironment.swift
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

struct AppEnvironment {

    // MARK: - Properties
    private static var stack = [Environment()]

    static var current: Environment {
        // `stack` is seeded with one environment and is never emptied — `popLast` has no callers
        // and `replaceCurrent` pushes before it removes. Falling back to a fresh `Environment()`
        // here would build a second `ClipyBox` over the same files, and the two would never see
        // each other's changes.
        return stack.last!
    }

    // MARK: - Stacks
    static func push(environment: Environment) {
        stack.append(environment)
    }

    @discardableResult
    static func popLast() -> Environment? {
        return stack.popLast()
    }

    static func replaceCurrent(environment: Environment) {
        push(environment: environment)
        stack.remove(at: stack.count - 2)
    }

    static func push(secretService: SecretService = current.secretService,
                     box: ClipyBox = current.box,
                     assetStore: ClipAssetStore = current.assetStore,
                     clipService: ClipService = current.clipService,
                     hotKeyService: HotKeyService = current.hotKeyService,
                     dataCleanService: DataCleanService = current.dataCleanService,
                     pasteService: PasteService = current.pasteService,
                     excludeAppService: ExcludeAppService = current.excludeAppService,
                     accessibilityService: AccessibilityService = current.accessibilityService,
                     menuManager: MenuManager = current.menuManager,
                     defaults: UserDefaults = current.defaults) {
        push(environment: Environment(secretService: secretService,
                                      box: box,
                                      assetStore: assetStore,
                                      clipService: clipService,
                                      hotKeyService: hotKeyService,
                                      dataCleanService: dataCleanService,
                                      pasteService: pasteService,
                                      excludeAppService: excludeAppService,
                                      accessibilityService: accessibilityService,
                                      menuManager: menuManager,
                                      defaults: defaults))
    }

    static func replaceCurrent(secretService: SecretService = current.secretService,
                               box: ClipyBox = current.box,
                               assetStore: ClipAssetStore = current.assetStore,
                               clipService: ClipService = current.clipService,
                               hotKeyService: HotKeyService = current.hotKeyService,
                               dataCleanService: DataCleanService = current.dataCleanService,
                               pasteService: PasteService = current.pasteService,
                               excludeAppService: ExcludeAppService = current.excludeAppService,
                               accessibilityService: AccessibilityService = current.accessibilityService,
                               menuManager: MenuManager = current.menuManager,
                               defaults: UserDefaults = current.defaults) {
        replaceCurrent(environment: Environment(secretService: secretService,
                                                box: box,
                                                assetStore: assetStore,
                                                clipService: clipService,
                                                hotKeyService: hotKeyService,
                                                dataCleanService: dataCleanService,
                                                pasteService: pasteService,
                                                excludeAppService: excludeAppService,
                                                accessibilityService: accessibilityService,
                                                menuManager: menuManager,
                                                defaults: defaults))
    }

    static func fromStorage(defaults: UserDefaults = .standard) -> Environment {
        var excludeApplications = [CPYAppInfo]()
        if let data = defaults.object(forKey: Constants.UserDefaults.excludeApplications) as? Data, let applications = data.unarchive() as? [CPYAppInfo] {
            excludeApplications = applications
        }
        let excludeAppService = ExcludeAppService(applications: excludeApplications)
        return Environment(secretService: current.secretService,
                           box: current.box,
                           assetStore: current.assetStore,
                           clipService: current.clipService,
                           hotKeyService: current.hotKeyService,
                           dataCleanService: current.dataCleanService,
                           pasteService: current.pasteService,
                           excludeAppService: excludeAppService,
                           accessibilityService: current.accessibilityService,
                           menuManager: current.menuManager,
                           defaults: current.defaults)
    }

 }
