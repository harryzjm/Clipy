//
//  HotKeyService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/11/19.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import Cocoa
import Magnet

final class HotKeyService: NSObject {
    // MARK: - Properties
    static var defaultKeyCombos: [String: Any] = {
        // HistoryMenu:  ⌘ + Shift + V
        return [Constants.Menu.history: ["keyCode": 9, "modifiers": 768]]
    }()

    fileprivate(set) var historyKeyCombo: KeyCombo?
    fileprivate(set) var restartKeyCombo: KeyCombo?
}

// MARK: - Actions
extension HotKeyService {
    @objc func popupHistoryMenu() {
        AppEnvironment.current.menuManager.popUpMenu(.history)
    }

    @objc func popUpClearHistoryAlert() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        appDelegate.restart()
    }
}

// MARK: - Setup
extension HotKeyService {
    func setupDefaultHotKeys() {
        // Migration new framework
        if !AppEnvironment.current.defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo) {
            migrationKeyCombos()
            AppEnvironment.current.defaults.set(true, forKey: Constants.HotKey.migrateNewKeyCombo)
            AppEnvironment.current.defaults.synchronize()
        }
        // History menu
        change(with: .history, keyCombo: savedKeyCombo(forKey: Constants.HotKey.historyKeyCombo))
        // Restart Clipy
        changeRestartKeyCombo(savedKeyCombo(forKey: Constants.HotKey.restartKeyCombo))
    }

    func change(with type: MenuType, keyCombo: KeyCombo?) {
        switch type {
        case .history:
            historyKeyCombo = keyCombo
        }
        register(with: type, keyCombo: keyCombo)
    }

    func changeRestartKeyCombo(_ keyCombo: KeyCombo?) {
        restartKeyCombo = keyCombo
        AppEnvironment.current.defaults.set(keyCombo?.archive(), forKey: Constants.HotKey.restartKeyCombo)
        AppEnvironment.current.defaults.synchronize()
        // Reset hotkey
        HotKeyCenter.shared.unregisterHotKey(with: "RestartClipy")
        // Register new hotkey
        guard let keyCombo = keyCombo else { return }
        let hotkey = HotKey(identifier: "RestartClipy", keyCombo: keyCombo, target: self, action: #selector(HotKeyService.popUpClearHistoryAlert))
        hotkey.register()
    }

    private func savedKeyCombo(forKey key: String) -> KeyCombo? {
        guard let data = AppEnvironment.current.defaults.object(forKey: key) as? Data else { return nil }
        guard let keyCombo = data.unarchive() as? KeyCombo else { return nil }
        return keyCombo
    }
}

// MARK: - Register
private extension HotKeyService {
    func register(with type: MenuType, keyCombo: KeyCombo?) {
        save(with: type, keyCombo: keyCombo)
        // Reset hotkey
        HotKeyCenter.shared.unregisterHotKey(with: type.rawValue)
        // Register new hotkey
        guard let keyCombo = keyCombo else { return }
        let hotKey = HotKey(identifier: type.rawValue, keyCombo: keyCombo, target: self, action: type.hotKeySelector)
        hotKey.register()
    }

    func save(with type: MenuType, keyCombo: KeyCombo?) {
        AppEnvironment.current.defaults.set(keyCombo?.archive(), forKey: type.userDefaultsKey)
        AppEnvironment.current.defaults.synchronize()
    }
}

// MARK: - Migration
private extension HotKeyService {
    /**
     *  Migration for changing the storage with v1.1.0
     *  Changed framework, PTHotKey to Magnet
     */
    func migrationKeyCombos() {
        guard let keyCombos = AppEnvironment.current.defaults.object(forKey: Constants.UserDefaults.hotKeys) as? [String: Any] else { return }

        // History menu
        if let (keyCode, modifiers) = parse(with: keyCombos, forKey: Constants.Menu.history) {
            if let keyCombo = KeyCombo(QWERTYKeyCode: keyCode, carbonModifiers: modifiers) {
                AppEnvironment.current.defaults.set(keyCombo.archive(), forKey: Constants.HotKey.historyKeyCombo)
            }
        }
    }

    func parse(with keyCombos: [String: Any], forKey key: String) -> (Int, Int)? {
        guard let combos = keyCombos[key] as? [String: Any] else { return nil }
        guard let keyCode = combos["keyCode"] as? Int, let modifiers = combos["modifiers"] as? Int else { return nil }
        return (keyCode, modifiers)
    }
}
