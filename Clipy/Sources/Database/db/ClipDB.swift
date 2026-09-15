//
//  ClipDB.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation
import WCDBSwift

/// Records what a transaction changed, so `beforeCommit` can turn it into a change signal.
final class ClipStatus {

    enum DeleteTarget {
        case hashes(Set<String>)
        case olderThan(Int)
        case all
    }

    var inserted: [CPYClipTable] = []
    var deleted: [DeleteTarget] = []

    var isEmpty: Bool {
        inserted.isEmpty && deleted.isEmpty
    }

    func clean() {
        inserted.removeAll()
        deleted.removeAll()
    }
}

/// Clipboard history store (`clip.db`).
final class ClipDB: DataStore {

    let status = ClipStatus()

    override func migrationList() -> [Migration] {
        [
            .init(version: 1) { db in
                try db.create(table: CPYClipTable.tableName, of: CPYClipTable.self)
            }
        ]
    }
}

// MARK: - Write
extension ClipDB {
    /// Upsert. A repeated copy hits the same `data_hash` primary key and refreshes `update_time`,
    /// which is what moves the clip back to the top of the history menu.
    func insertClip(_ clip: CPYClipTable) throws {
        try db.insertOrReplace(clip, intoTable: CPYClipTable.tableName)
        status.inserted.append(clip)
    }

    func deleteClip(dataHash: String) throws {
        try db.delete(fromTable: CPYClipTable.tableName,
                      where: CPYClipTable.Properties.dataHash == dataHash)
        status.deleted.append(.hashes([dataHash]))
    }

    func deleteClips(olderThan updateTime: Int) throws {
        try db.delete(fromTable: CPYClipTable.tableName,
                      where: CPYClipTable.Properties.updateTime < updateTime)
        status.deleted.append(.olderThan(updateTime))
    }

    func deleteAllClips() throws {
        try db.delete(fromTable: CPYClipTable.tableName)
        status.deleted.append(.all)
    }
}

// MARK: - Read
extension ClipDB {
    func fetchClip(dataHash: String) throws -> CPYClipTable? {
        try db.getObject(fromTable: CPYClipTable.tableName,
                         where: CPYClipTable.Properties.dataHash == dataHash)
    }

    func fetchClips(ascending: Bool, limit: Int?) throws -> [CPYClipTable] {
        let order = [CPYClipTable.Properties.updateTime.order(ascending ? .ascending : .descending)]
        if let limit = limit {
            return try db.getObjects(fromTable: CPYClipTable.tableName, orderBy: order, limit: limit)
        }
        return try db.getObjects(fromTable: CPYClipTable.tableName, orderBy: order)
    }

    func clipCount() throws -> Int {
        try db.getValue(on: CPYClipTable.Properties.dataHash.count(),
                        fromTable: CPYClipTable.tableName).intValue
    }

    /// Non-empty thumbnail cache keys, optionally restricted to clips older than `updateTime`.
    func fetchThumbnailPaths(olderThan updateTime: Int? = nil) throws -> [String] {
        var condition = CPYClipTable.Properties.thumbnailPath != ""
        if let updateTime = updateTime {
            condition = condition && CPYClipTable.Properties.updateTime < updateTime
        }
        return try db.getColumn(on: CPYClipTable.Properties.thumbnailPath,
                                fromTable: CPYClipTable.tableName,
                                where: condition).map { $0.stringValue }
    }

    func fetchAllDataPaths() throws -> [String] {
        try db.getColumn(on: CPYClipTable.Properties.dataPath,
                         fromTable: CPYClipTable.tableName).map { $0.stringValue }
    }

    /// `update_time` of the `maxHistorySize`-th most recent clip, or `nil` when the history is
    /// not over the limit. Everything strictly older than it is surplus.
    ///
    /// Mirrors the previous Realm `overflowingClips` logic exactly.
    func overflowThreshold(maxHistorySize: Int) throws -> Int? {
        guard maxHistorySize > 0 else { return nil }
        let rows = try db.getColumn(on: CPYClipTable.Properties.updateTime,
                                    fromTable: CPYClipTable.tableName,
                                    orderBy: [CPYClipTable.Properties.updateTime.order(.descending)],
                                    limit: 1,
                                    offset: maxHistorySize - 1)
        guard let last = rows.first else { return nil }
        return last.intValue
    }
}
