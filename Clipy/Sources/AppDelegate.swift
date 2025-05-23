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
import RealmSwift
import LetsMove
import LaunchAtLogin

@NSApplicationMain
class AppDelegate: NSObject, NSMenuItemValidation {

    // MARK: - Properties
    let screenshotObserver = ScreenShotObserver()
    let disposeBag = DisposeBag()

    // MARK: - Init
    override func awakeFromNib() {
        super.awakeFromNib()
        // Migrate Realm
        Realm.migration()
    }

    // MARK: - NSMenuItem Validation
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(AppDelegate.clearAllHistory) {
            let realm = try! Realm()
            return !realm.objects(CPYClip.self).isEmpty
        }
        return true
    }

    // MARK: - Class Methods
    static func storeTypesDictionary() -> [String: NSNumber] {
        var storeTypes = [String: NSNumber]()
        CPYClipData.availableTypesString.forEach { storeTypes[$0] = NSNumber(value: true) }
        return storeTypes
    }

    // MARK: - Menu Actions
    @objc func showPreferenceWindow() {
        NSApp.activate(ignoringOtherApps: true)
        CPYPreferencesWindowController.sharedController.showWindow(self)
    }

    @objc func showSnippetEditorWindow() {
        NSApp.activate(ignoringOtherApps: true)
        CPYSnippetsEditorWindowController.sharedController.showWindow(self)
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
            alert.messageText = L10n.clearHistory
            alert.informativeText = L10n.areYouSureYouWantToClearYourClipboardHistory
            alert.addButton(withTitle: L10n.clearHistory)
            alert.addButton(withTitle: L10n.cancel)
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

    @objc func selectClipMenuItem(_ sender: NSMenuItem) {
        guard let primaryKey = sender.representedObject as? String else {
            lError("Cannot fetch clip primary key")
            NSSound.beep()
            return
        }
        let realm = try! Realm()
        guard let clip = realm.object(ofType: CPYClip.self, forPrimaryKey: primaryKey) else {
            lError("Cannot fetch clip data")
            NSSound.beep()
            return
        }

        AppEnvironment.current.pasteService.paste(with: clip)
    }

    @objc func selectSnippetMenuItem(_ sender: AnyObject) {
        guard let primaryKey = sender.representedObject as? String else {
            lError("Cannot fetch snippet primary key")
            NSSound.beep()
            return
        }
        let realm = try! Realm()
        guard let snippet = realm.object(ofType: CPYSnippet.self, forPrimaryKey: primaryKey) else {
            lError("Cannot fetch snippet data")
            NSSound.beep()
            return
        }
        AppEnvironment.current.pasteService.copyToPasteboard(with: snippet.content)
        AppEnvironment.current.pasteService.paste()
    }

    // MARK: - Login Item Methods
    private func promptToAddLoginItems() {
        let alert = NSAlert()
        alert.messageText = L10n.launchClipyOnSystemStartup
        alert.informativeText = L10n.youCanChangeThisSettingInThePreferencesIfYouWant
        alert.addButton(withTitle: L10n.launchOnSystemStartup)
        alert.addButton(withTitle: L10n.donTLaunch)
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
        if #available(macOS 10.13, *) {
            LaunchAtLogin.isEnabled = isEnable
        } else {
            let appPath = Bundle.main.bundlePath
            LoginServiceKit.removeLoginItems(at: appPath)
            guard isEnable else { return }
            LoginServiceKit.addLoginItems(at: appPath)
        }
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
        AppEnvironment.current.dataCleanService.startMonitoring()
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
