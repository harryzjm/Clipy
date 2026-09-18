//
//  PasteService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/11/23.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import Cocoa
import Sauce

final class PasteService {

    // MARK: - Properties
    /// Where an overflowed payload is read back from. Injected rather than reached for, so the
    /// one production call to `CPYClip.loadContents(assetStore:)` names the same store the
    /// capture path wrote through.
    private let assetStore: ClipAssetStore
    fileprivate let lock = NSRecursiveLock(name: "com.clipy-app.Clipy.Pastable")
    fileprivate var isPastePlainText: Bool {
        guard AppEnvironment.current.defaults.bool(forKey: Preferences.Beta.pastePlainText) else { return false }

        let modifierSetting = AppEnvironment.current.defaults.integer(forKey: Preferences.Beta.pastePlainTextModifier)
        return isPressedModifier(modifierSetting)
    }
    fileprivate var isDeleteHistory: Bool {
        guard AppEnvironment.current.defaults.bool(forKey: Preferences.Beta.deleteHistory) else { return false }

        let modifierSetting = AppEnvironment.current.defaults.integer(forKey: Preferences.Beta.deleteHistoryModifier)
        return isPressedModifier(modifierSetting)
    }
    fileprivate var isPasteAndDeleteHistory: Bool {
        guard AppEnvironment.current.defaults.bool(forKey: Preferences.Beta.pasteAndDeleteHistory) else { return false }

        let modifierSetting = AppEnvironment.current.defaults.integer(forKey: Preferences.Beta.pasteAndDeleteHistoryModifier)
        return isPressedModifier(modifierSetting)
    }

    // MARK: - Initialize
    init(assetStore: ClipAssetStore) {
        self.assetStore = assetStore
    }

    // MARK: - Modifiers
    private func isPressedModifier(_ flag: Int) -> Bool {
        let flags = NSEvent.modifierFlags
        if flag == 0 && flags.contains(.command) {
            return true
        } else if flag == 1 && flags.contains(.shift) {
            return true
        } else if flag == 2 && flags.contains(.control) {
            return true
        } else if flag == 3 && flags.contains(.option) {
            return true
        }
        return false
    }
}

// MARK: - Copy
extension PasteService {
    func paste(with clip: CPYClip) {
        // Handling modifier actions
        let isPastePlainText = self.isPastePlainText
        let isPasteAndDeleteHistory = self.isPasteAndDeleteHistory
        let isDeleteHistory = self.isDeleteHistory
        guard isPastePlainText || isPasteAndDeleteHistory || isDeleteHistory else {
            copyToPasteboard(with: clip)
            paste()
            return
        }

        // Increment change count for don't copy paste item
        if isPasteAndDeleteHistory {
            AppEnvironment.current.clipService.incrementChangeCount()
        }
        // Paste history. `copyToPasteboard(with:)` applies the plain-text setting itself, so both
        // cases go through the same call — and the payload is decoded exactly once, there.
        if isPastePlainText || isPasteAndDeleteHistory {
            copyToPasteboard(with: clip)
            paste()
        }
        // Delete clip
        if isDeleteHistory || isPasteAndDeleteHistory {
            AppEnvironment.current.clipService.delete(with: clip)
        }
    }

    func copyToPasteboard(with string: String?) {
        guard let string = string else { return }
        lock.lock(); defer { lock.unlock() }

        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(string, forType: .string)
    }

    /// The one place a stored payload is decoded — everywhere else `CPYClip.content` stays an
    /// opaque blob.
    func copyToPasteboard(with clip: CPYClip) {
        lock.lock(); defer { lock.unlock() }

        // A missing or unreadable payload is already logged by `loadContents()`.
        guard let contents = clip.loadContents(assetStore: assetStore) else { return }
        if isPastePlainText {
            copyToPasteboard(with: contents.stringValue)
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes(contents.compactMap(\.toPasteboardType), owner: nil)
        contents.forEach { type in
            type.recover(to: pasteboard)
        }
    }
}

// MARK: - Paste
extension PasteService {
    func paste() {
        guard AppEnvironment.current.defaults.bool(forKey: Preferences.General.inputPasteCommand) else { return }
        // Check Accessibility Permission
        guard AppEnvironment.current.accessibilityService.isAccessibilityEnabled(isPrompt: false) else {
            AppEnvironment.current.accessibilityService.showAccessibilityAuthenticationAlert()
            return
        }

        let vKeyCode = Sauce.shared.keyCode(for: .v)
        LQueue.main.dispatch {
            let source = CGEventSource(stateID: .combinedSessionState)
            // Disable local keyboard events while pasting
            source?.setLocalEventsFilterDuringSuppressionState([.permitLocalMouseEvents, .permitSystemDefinedEvents], state: .eventSuppressionStateSuppressionInterval)
            // Press Command + V
            let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
            keyVDown?.flags = .maskCommand
            // Release Command + V
            let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
            keyVUp?.flags = .maskCommand
            // Post Paste Command
            keyVDown?.post(tap: .cgAnnotatedSessionEventTap)
            keyVUp?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
