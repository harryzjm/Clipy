//
//  DataStore.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation
import WCDBSwift
import MMKV

/// Base wrapper around a single WCDB `Database` file.
///
/// Ported from `ServiceBox/db/DataStore.swift`. `secretCode` is the SQLCipher key, handed down
/// from `ClipyBox`; it covers this file and, for `clip.db`, the FTS index inside it. The same key
/// seals the overflow payloads in `file/` — see `ClipAssetStore` — so the whole store is
/// encrypted, not just the index.
///
/// Subclasses override `migrationList()` to declare their schema; the applied version is
/// recorded in MMKV under `com.clipy.database.<name>.version`.
class DataStore {

    /// Slow-statement logging threshold, in milliseconds.
    var traceThreshold: UInt64 { 10 }

    /// Logs every statement, not just slow ones. For debugging.
    var enableSQL: Bool { false }

    let basePath: String
    let name: String
    let store: MMKV

    private let databasePath: String
    private var database: Database!
    /// Asked before an unopenable file is deleted. Nil leaves a broken database broken.
    private let recovery: DatabaseRecovery?

    var db: Database { database }

    init(rootPath: String, name: String, secretCode: Data? = nil, store: MMKV, recovery: DatabaseRecovery? = nil) {
        self.name = name
        self.basePath = rootPath
        self.databasePath = (rootPath as NSString).appendingPathComponent(name)
        self.store = store
        self.recovery = recovery

        self.database = openDatabase(secretCode)

        migratorIfNeed(database)
        trace(database)
    }

    deinit {
        database.close()
    }

    private func openDatabase(_ secretCode: Data?) -> Database {
        let manager = FileManager.default
        if !manager.fileExists(atPath: databasePath) {
            do {
                try manager.createDirectory(atPath: basePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                lError("Failed to create database directory:", error)
            }
        }

        let db = Database(at: databasePath)
        // `Database(at:)` opens no handle, so this still runs before any I/O — which is what
        // WCDB requires of a cipher. Note `setCipher(key: nil)` means *no* encryption, so the
        // key is passed as `Data` all the way down rather than being encoded here.
        if let secretCode, !secretCode.isEmpty {
            db.setCipher(key: secretCode)
        }

        do {
            try configCustomDatabase(db)
        } catch {
            lError("Failed to config custom database:", error)
        }

        guard let failure = openFailure(of: db) else { return db }
        // Nothing here can go on: every transaction through this handle would fail, which for
        // `clip.db` means an app that can neither save a copy nor paste one. So ask, and if the
        // answer is no, hand back the broken handle rather than deleting the user's history
        // behind their back — a keychain that is merely unreadable today may read fine tomorrow.
        guard recovery?.shouldReset(databaseNamed: name, failure: failure) == true else {
            return db
        }
        reset(db)
        return db
    }

    /// Whether this file is beyond reading, in a way that deleting it would fix.
    ///
    /// Has to be a real read. Nothing up to this point has touched the disk — `Database(at:)` is
    /// lazy and `setCipher` only records the key — so a key that does not match the file is
    /// discovered either here or not until the first transaction, long after anyone is in a
    /// position to do something about it. `isTableExists` is the cheapest read there is; its
    /// answer is thrown away, only the error matters, and `sqlite_master` is the one table
    /// `DataStore` can name without knowing its subclass's schema.
    private func openFailure(of db: Database) -> DatabaseOpenFailure? {
        do {
            _ = try db.isTableExists("sqlite_master")
            return nil
        } catch let error as WCDBError {
            switch error.code {
            case .NotADatabase:
                lError("Cannot decrypt \(name):", error)
                return .keyMismatch
            case .Corrupt:
                lError("\(name) is corrupt:", error)
                return .corrupted
            default:
                // A busy file, an I/O error, a directory that could not be created: none of them
                // are things deleting the database would fix, so they are left to surface at the
                // statement that hits them.
                lError("Failed to open \(name):", error)
                return nil
            }
        } catch {
            lError("Failed to open \(name):", error)
            return nil
        }
    }

    /// Deletes the database and every file WCDB keeps beside it, leaving `db` usable: the next
    /// access opens a fresh, empty file under the current key, and the migrations that run right
    /// after this rebuild the schema into it.
    ///
    /// A clip's payload files and thumbnails are not touched here — they were written under the
    /// same key, so they are just as unreadable, and `DataCleanService.cleanDatas()` sweeps
    /// whatever no row points at any more. Which, after this, is all of them.
    private func reset(_ db: Database) {
        db.close()
        do {
            try db.removeFiles()
        } catch {
            lError("Failed to delete \(name):", error)
            return
        }
        // The schema version lives in MMKV, not in the file that was just deleted. Left behind it
        // would skip every migration, and the rebuilt database would have no tables in it at all.
        store.removeValue(forKey: versionKey)
        lInfo("Deleted \(name) at the user's request; it will be rebuilt empty")
    }

    /// Subclass hook, called once right after the handle is created and before migrations run.
    func configCustomDatabase(_ db: Database) throws {
    }

    func migrationList() -> [Migration] {
        []
    }
}

// MARK: - Transaction
extension DataStore {
    func begin() throws {
        try database.begin()
    }

    func commit() throws {
        try database.commit()
    }

    func rollback() throws {
        try database.rollback()
    }

    func vacuum() throws {
        _ = db.canOpen
        try db.vacuum(with: nil)
    }
}

// MARK: - Trace
extension DataStore {
    private func trace(_ db: Database) {
        #if DEBUG
        db.trace { [weak self] _, _, _, sql, info in
            guard let self = self else { return }
            let millisecond = UInt64(info.costInNanoseconds) / NSEC_PER_MSEC
            if millisecond > self.traceThreshold || self.enableSQL {
                lWarning("\(self.name): \(millisecond)ms sql: '\(sql)'")
            }
        }
        #endif
        db.traceError { [weak self] error in
            lWarning("\(self?.name ?? "db") code:", error.code, "sql:", error.sql, "error:", error)
        }
    }
}

// MARK: - Migrator
extension DataStore {
    struct Migration {
        let version: Int32
        let migrate: (Database) throws -> Void
    }

    private var versionKey: String {
        "com.clipy.database.\(name).version"
    }

    private func migratorIfNeed(_ db: Database) {
        let before = store.int32(forKey: versionKey)
        let migrations = migrationList()
            .filter { $0.version > before }
            .sorted { $0.version < $1.version }

        guard !migrations.isEmpty else {
            lDebug("Current \(name) version:", before)
            return
        }

        var current: Int32 = before
        do {
            try migrations.forEach { migration in
                current = migration.version
                try begin()
                try migration.migrate(db)
                try commit()
                // Record per step, so a failure halfway does not replay the steps that succeeded.
                store.set(migration.version, forKey: versionKey)
                lDebug("migrator \(name)-\(migration.version) success")
            }
        } catch {
            try? rollback()
            lError("migrator \(name)-\(current) error:", error)
        }
        lDebug("Current \(name) version:", store.int32(forKey: versionKey))
    }
}

// MARK: - Hashable
extension DataStore: Hashable {
    static func == (lhs: DataStore, rhs: DataStore) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(databasePath)
    }
}
