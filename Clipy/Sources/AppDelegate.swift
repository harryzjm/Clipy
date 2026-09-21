//
//  AppDelegate.swift
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
import RxCocoa
import RxSwift
import RxOptional
import Magnet
import Screeen
import RxScreeen
import LetsMove

class AppDelegate: NSObject {
    // MARK: - Properties
    let screenshotObserver = ScreenShotObserver()
    let disposeBag = DisposeBag()
    /// Built on demand and released when the window closes, so every open starts from a fresh
    /// store. Held here rather than in a `shared` on the controller purely to keep the editor to
    /// one window at a time — see `SnippetsEditorWindowController`.
    private var snippetsEditorWindowController: SnippetsEditorWindowController?

    // MARK: - Class Methods
    static func storeTypesDictionary() -> [String: NSNumber] {
        var storeTypes = [String: NSNumber]()
        TypeContent.availableTypesString.forEach { storeTypes[$0] = NSNumber(value: true) }
        return storeTypes
    }

    // MARK: - Menu Actions
    @objc func showPreferenceWindow() {
        activateApp()

        LQueue.main.dispatchAsync { [weak self] in
            self?.openSettingsWindow()
        }
    }

    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openSettingsWindow() {
        guard let item = settingsMenuItem(), let menu = item.menu else {
            lError("Could not locate the Settings menu item")
            return
        }
        menu.performActionForItem(at: menu.index(of: item))
        bringSettingsWindowForward()
    }

    /// SwiftUI installs the Settings item with a private `menuAction:` selector bound to its own
    /// callback object, so `NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, ...)`
    /// reports success while doing nothing at all. Find the real item and perform that instead.1
    private func settingsMenuItem() -> NSMenuItem? {
        guard let appMenu = NSApp.mainMenu?.items.first?.submenu else { return nil }
        let documented: Set<Selector> = [Selector(("showSettingsWindow:")), Selector(("showPreferencesWindow:"))]
        // Prefer the documented selectors in case a future SwiftUI stops using `menuAction:`,
        // then fall back to the standard ⌘, key equivalent, which is localisation-independent.
        return appMenu.items.first { item in item.action.map { documented.contains($0) } ?? false }
            ?? appMenu.items.first { $0.keyEquivalent == "," && $0.keyEquivalentModifierMask == .command }
    }

    /// SwiftUI materialises the `Settings` window asynchronously, and an inactive `LSUIElement`
    /// app does not get it ordered front for free — so poll briefly and order it front ourselves.
    private func bringSettingsWindowForward(retriesRemaining: Int = 20) {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == Constants.Application.settingsWindowIdentifier }) {
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
            window.makeKey()
            return
        }
        guard retriesRemaining > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.bringSettingsWindowForward(retriesRemaining: retriesRemaining - 1)
        }
    }

    @objc func showSnippetEditorWindow() {
        activateApp()
        let controller = snippetsEditorWindowController ?? makeSnippetsEditorWindowController()
        controller.showWindow(self)
    }

    private func makeSnippetsEditorWindowController() -> SnippetsEditorWindowController {
        let controller = SnippetsEditorWindowController()
        controller.onWindowClose = { [weak self] in self?.snippetsEditorWindowController = nil }
        snippetsEditorWindowController = controller
        return controller
    }

    @objc func terminate() {
        NSApp.terminate(nil)
    }

    @objc func restart() {
        guard let path = Bundle.main.resourceURL?.deletingLastPathComponent().deletingLastPathComponent().absoluteString else { return }
        _ = Process.launchedProcess(launchPath: "/usr/bin/open", arguments: [path])
        NSApp.terminate(self)
    }

    @objc func clearAllHistory() {
        let isShowAlert = AppEnvironment.current.defaults.bool(forKey: Preferences.Menu.showAlertBeforeClearHistory)
        if isShowAlert {
            let alert = NSAlert()
            alert.messageText = L10n.Common.clearHistory
            alert.informativeText = L10n.Alert.ClearHistory.message
            alert.addButton(withTitle: L10n.Common.clearHistory)
            alert.addButton(withTitle: L10n.Common.cancel)
            alert.showsSuppressionButton = true

            NSApp.activate(ignoringOtherApps: true)

            let result = alert.runModal()
            if result != NSApplication.ModalResponse.alertFirstButtonReturn { return }

            if alert.suppressionButton?.state == NSControl.StateValue.on {
                AppEnvironment.current.defaults.set(false, forKey: Preferences.Menu.showAlertBeforeClearHistory)
            }
            AppEnvironment.current.defaults.synchronize()
        }

        AppEnvironment.current.clipService.clearAll()
    }

    /// No confirmation, by design — the status menu's twin of Clear History, which only asks
    /// because it has a preference to ask. Deliberately not routed through the editor: the window
    /// may well be closed, so the write goes straight to the box and the editor, if one is open,
    /// is told to re-read afterwards.
    @objc func deleteAllSnippets() {
        AppEnvironment.current.box
            .snippetTransaction { try $0.clearAllFolders() }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                // Folder shortcuts outlive their folders otherwise; they are keyed by identifier
                // in UserDefaults, and every folder just went away.
                AppEnvironment.current.hotKeyService.unregisterAllSnippetHotKeys()
                self?.snippetsEditorWindowController?.resetAndReload()
            }, onError: { error in
                NSSound.beep()
                lError(error)
            })
            .disposed(by: disposeBag)
    }

    @objc func selectClipMenuItem(_ sender: NSMenuItem) {
        guard let primaryKey = sender.representedObject as? String else {
            lError("Cannot fetch clip primary key")
            NSSound.beep()
            return
        }
        AppEnvironment.current.box
            .clipTransaction { try $0.fetchClip(dataHash: primaryKey) }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { clip in
                guard let clip = clip else {
                    lError("Cannot fetch clip data")
                    NSSound.beep()
                    return
                }
                AppEnvironment.current.pasteService.paste(with: clip)
            }, onError: { _ in
                NSSound.beep()
            })
            .disposed(by: disposeBag)
    }

    @objc func selectSnippetMenuItem(_ sender: AnyObject) {
        guard let primaryKey = sender.representedObject as? String else {
            lError("Cannot fetch snippet primary key")
            NSSound.beep()
            return
        }
        AppEnvironment.current.box
            .snippetTransaction { try $0.fetchSnippet(identifier: primaryKey) }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { snippet in
                guard let snippet = snippet else {
                    lError("Cannot fetch snippet data")
                    NSSound.beep()
                    return
                }
                AppEnvironment.current.pasteService.copyToPasteboard(with: snippet.content)
                AppEnvironment.current.pasteService.paste()
            }, onError: { _ in
                NSSound.beep()
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Login Item Methods
    private func promptToAddLoginItems() {
        let alert = NSAlert()
        alert.messageText = L10n.Alert.LoginItem.title
        alert.informativeText = L10n.Alert.LoginItem.message
        alert.addButton(withTitle: L10n.Alert.LoginItem.launch)
        alert.addButton(withTitle: L10n.Alert.LoginItem.dontLaunch)
        alert.showsSuppressionButton = true
        NSApp.activate(ignoringOtherApps: true)

        //  Launch on system startup
        if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
            AppEnvironment.current.defaults.set(true, forKey: Preferences.General.loginItem)
            AppEnvironment.current.defaults.synchronize()
            reflectLoginItemState()
        }
        // Do not show this message again
        if alert.suppressionButton?.state == NSControl.StateValue.on {
            AppEnvironment.current.defaults.set(true, forKey: Constants.UserDefaults.suppressAlertForLoginItem)
            AppEnvironment.current.defaults.synchronize()
        }
    }

    private func toggleAddingToLoginItems(_ isEnable: Bool) {
        LaunchAtLogin.isEnabled = isEnable
    }

    private func reflectLoginItemState() {
        let isInLoginItems = AppEnvironment.current.defaults.bool(forKey: Preferences.General.loginItem)
        toggleAddingToLoginItems(isInLoginItems)
    }
}

// MARK: - NSApplication Delegate
extension AppDelegate: NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Environments
        AppEnvironment.replaceCurrent(environment: AppEnvironment.fromStorage())
        // UserDefaults
        CPYUtilities.registerUserDefaultKeys()
        // Check Accessibility Permission
        AppEnvironment.current.accessibilityService.isAccessibilityEnabled(isPrompt: true)

        // Show Login Item
        #if RELEASE
        if !AppEnvironment.current.defaults.bool(forKey: Preferences.General.loginItem) && !AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.suppressAlertForLoginItem) {
            promptToAddLoginItems()
        }
        #endif

        // Binding Events
        bind()

        // Services
        AppEnvironment.current.clipService.startMonitoring()
        AppEnvironment.current.dataCleanService.cleanDatas()
        AppEnvironment.current.excludeAppService.startMonitoring()
        AppEnvironment.current.hotKeyService.setupDefaultHotKeys()

        // Managers
        AppEnvironment.current.menuManager.setup()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        #if RELEASE
            PFMoveToApplicationsFolderIfNecessary()
        #endif
    }

}

// MARK: - Bind
private extension AppDelegate {
    func bind() {
        // Login Item
        AppEnvironment.current.defaults.rx.observe(Bool.self, Preferences.General.loginItem, retainSelf: false)
            .filterNil()
            .subscribe(onNext: { [weak self] _ in
                self?.reflectLoginItemState()
            })
            .disposed(by: disposeBag)
        // Observe Screenshot
        AppEnvironment.current.defaults.rx.observe(Bool.self, Preferences.Beta.observerScreenshot, retainSelf: false)
            .filterNil()
            .subscribe(onNext: { [weak self] enabled in
                self?.screenshotObserver.isEnabled = enabled
            })
            .disposed(by: disposeBag)
        // Observe Screenshot image
        screenshotObserver.rx.addedImage
            .subscribe(onNext: { image in
                AppEnvironment.current.clipService.create(with: "Screenshot", image: image)
            })
            .disposed(by: disposeBag)
    }
}

extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        true
    }
}
