//
//  DatabaseResetPrompt.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Cocoa

/// Why a database will not open, in the two cases where deleting the file is the way out.
enum DatabaseOpenFailure {
    /// SQLite's `NOTADB`. Under SQLCipher this is what a wrong key looks like: page 1 decrypts
    /// into something that is not a SQLite header, which is indistinguishable from a file that
    /// was never a database. The usual cause is the keychain — an item that cannot be read mints
    /// no replacement (see `SecretService.Keychain.Lookup`), so the launch runs keyless over
    /// files that are not.
    case keyMismatch
    /// SQLite's `CORRUPT`: the file is a database, and unreadable.
    case corrupted
}

/// Asked whether an unopenable database may be thrown away and rebuilt empty.
///
/// The decision is the app's, not the storage layer's: it costs the user their history, and
/// `DataStore` has no business putting a window on screen. `nil` — which is what tests and any
/// other headless caller get — keeps the behaviour this replaced: the handle stays, and every
/// transaction through it fails.
protocol DatabaseRecovery: AnyObject {
    /// Called on the queue that owns the database, and blocks it until it returns. That is
    /// deliberate: no transaction may run against a file that is about to be deleted.
    func shouldReset(databaseNamed name: String, failure: DatabaseOpenFailure) -> Bool
}

/// Puts "Clipy cannot open its database" in front of the user, and asks whether to start over.
///
/// One decision per launch. `clip.db` and `snippet.db` are encrypted with the same key, so
/// whatever breaks one breaks the other, and the second store to ask gets the answer the first
/// one got instead of a second alert. The lock is held across the alert precisely for that: a
/// store asking from the other queue waits for the answer rather than opening its own window.
final class DatabaseResetPrompt: DatabaseRecovery {

    private let decision = Atomic<Bool?>(value: nil)

    func shouldReset(databaseNamed name: String, failure: DatabaseOpenFailure) -> Bool {
        var reset = false
        decision.adapt { decided in
            if let decided {
                reset = decided
                return
            }
            reset = Self.ask(about: failure)
            decided = reset
        }
        lInfo("Reset of \(name):", reset ? "accepted" : "declined")
        return reset
    }
}

// MARK: - Alert
private extension DatabaseResetPrompt {

    /// Runs the alert on the main thread and blocks the caller until it is answered.
    ///
    /// `MainRunLoopScheduler.perform` rather than `DispatchQueue.main.async`: the main queue is
    /// not drained while a menu runs its tracking loop, and a database can first be opened from
    /// inside one — a keystroke in the history filter is a clip transaction. Blocking the calling
    /// queue is the point: it is the queue that owns the database, and nothing on it may run
    /// until the file's fate is settled.
    static func ask(about failure: DatabaseOpenFailure) -> Bool {
        guard !Thread.isMainThread else { return runModal(about: failure) }

        var reset = false
        let answered = DispatchSemaphore(value: 0)
        MainRunLoopScheduler.perform {
            reset = runModal(about: failure)
            answered.signal()
        }
        answered.wait()
        return reset
    }

    static func runModal(about failure: DatabaseOpenFailure) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = L10n.Alert.DatabaseReset.title
        switch failure {
        case .keyMismatch:
            alert.informativeText = L10n.Alert.DatabaseReset.keyMismatch
        case .corrupted:
            alert.informativeText = L10n.Alert.DatabaseReset.corrupted
        }

        alert.addButton(withTitle: L10n.Alert.DatabaseReset.keep)
        alert.addButton(withTitle: L10n.Alert.DatabaseReset.delete)
        // Keeping the file is the default, because the other button is unrecoverable. Clearing
        // the key equivalent AppKit hands the second button is what keeps Return and Escape from
        // reaching it: neither is a way to agree to deleting a history.
        alert.buttons.last?.keyEquivalent = ""
        alert.buttons.last?.hasDestructiveAction = true

        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertSecondButtonReturn
    }
}
