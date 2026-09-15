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
/// Ported from `ServiceBox/db/DataStore.swift`, minus the per-account cipher — Clipy's
/// database is not encrypted (the clipboard payloads live next to it as plain `.data` files,
/// so encrypting only the index would buy nothing).
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

    var db: Database { database }

    init(rootPath: String, name: String, store: MMKV) {
        self.name = name
        self.basePath = rootPath
        self.databasePath = (rootPath as NSString).appendingPathComponent(name)
        self.store = store

        self.database = openDatabase()

        migratorIfNeed(database)
        trace(database)
    }

    deinit {
        database.close()
    }

    private func openDatabase() -> Database {
        let manager = FileManager.default
        if !manager.fileExists(atPath: databasePath) {
            do {
                try manager.createDirectory(atPath: basePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                lError("Failed to create database directory:", error)
            }
        }

        let db = Database(at: databasePath)
        do {
            try configCustomDatabase(db)
        } catch {
            lError("Failed to config custom database:", error)
        }
        return db
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
