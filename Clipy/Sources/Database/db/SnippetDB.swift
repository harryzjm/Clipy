//
//  SnippetDB.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation
import WCDBSwift

/// Records whether a transaction touched the snippet graph, so `beforeCommit` can fire the
/// change signal that rebuilds the snippet menu.
///
/// The menu always redraws from the full folder list, so a coarse dirty flag carries exactly as
/// much information as a per-row delta would.
final class SnippetStatus {

    private(set) var changed = false

    var isEmpty: Bool {
        !changed
    }

    func markChanged() {
        changed = true
    }

    func clean() {
        changed = false
    }
}

/// Snippet folder / snippet store (`snippet.db`).
final class SnippetDB: DataStore {

    let status = SnippetStatus()

    override func migrationList() -> [Migration] {
        [
            .init(version: 1) { db in
                try db.create(table: CPYFolderTable.tableName, of: CPYFolderTable.self)
                try db.create(table: CPYSnippetTable.tableName, of: CPYSnippetTable.self)
            }
        ]
    }
}

// MARK: - Read
extension SnippetDB {
    func fetchFolderTables() throws -> [CPYFolderTable] {
        try db.getObjects(fromTable: CPYFolderTable.tableName,
                          orderBy: [CPYFolderTable.Properties.index.order(.ascending)])
    }

    func fetchFolderTable(identifier: String) throws -> CPYFolderTable? {
        try db.getObject(fromTable: CPYFolderTable.tableName,
                         where: CPYFolderTable.Properties.identifier == identifier)
    }

    func fetchSnippetTables(folderIdentifier: String) throws -> [CPYSnippetTable] {
        try db.getObjects(fromTable: CPYSnippetTable.tableName,
                          where: CPYSnippetTable.Properties.folderIdentifier == folderIdentifier,
                          orderBy: [CPYSnippetTable.Properties.index.order(.ascending)])
    }

    func fetchAllSnippetTables() throws -> [CPYSnippetTable] {
        try db.getObjects(fromTable: CPYSnippetTable.tableName,
                          orderBy: [CPYSnippetTable.Properties.index.order(.ascending)])
    }

    func fetchSnippetTable(identifier: String) throws -> CPYSnippetTable? {
        try db.getObject(fromTable: CPYSnippetTable.tableName,
                         where: CPYSnippetTable.Properties.identifier == identifier)
    }

    func maxFolderIndex() throws -> Int? {
        let value = try db.getValue(on: CPYFolderTable.Properties.index.max(),
                                    fromTable: CPYFolderTable.tableName)
        return value.type == .null ? nil : value.intValue
    }
}

// MARK: - Write
extension SnippetDB {
    func upsertFolder(_ folder: CPYFolderTable) throws {
        try db.insertOrReplace(folder, intoTable: CPYFolderTable.tableName)
        status.markChanged()
    }

    func upsertFolders(_ folders: [CPYFolderTable]) throws {
        guard !folders.isEmpty else { return }
        try db.insertOrReplace(folders, intoTable: CPYFolderTable.tableName)
        status.markChanged()
    }

    func upsertSnippet(_ snippet: CPYSnippetTable) throws {
        try db.insertOrReplace(snippet, intoTable: CPYSnippetTable.tableName)
        status.markChanged()
    }

    func upsertSnippets(_ snippets: [CPYSnippetTable]) throws {
        guard !snippets.isEmpty else { return }
        try db.insertOrReplace(snippets, intoTable: CPYSnippetTable.tableName)
        status.markChanged()
    }

    func deleteFolder(identifier: String) throws {
        try db.delete(fromTable: CPYFolderTable.tableName,
                      where: CPYFolderTable.Properties.identifier == identifier)
        status.markChanged()
    }

    func deleteSnippet(identifier: String) throws {
        try db.delete(fromTable: CPYSnippetTable.tableName,
                      where: CPYSnippetTable.Properties.identifier == identifier)
        status.markChanged()
    }

    func deleteSnippets(folderIdentifier: String) throws {
        try db.delete(fromTable: CPYSnippetTable.tableName,
                      where: CPYSnippetTable.Properties.folderIdentifier == folderIdentifier)
        status.markChanged()
    }

    /// Rewrites just the ordering column for a batch of rows, inside the caller's transaction.
    func updateFolderIndexes(_ indexes: [(identifier: String, index: Int)]) throws {
        guard !indexes.isEmpty else { return }
        try indexes.forEach { entry in
            try db.update(table: CPYFolderTable.tableName,
                          on: CPYFolderTable.Properties.index,
                          with: entry.index,
                          where: CPYFolderTable.Properties.identifier == entry.identifier)
        }
        status.markChanged()
    }

    func updateSnippetIndexes(_ indexes: [(identifier: String, index: Int)]) throws {
        guard !indexes.isEmpty else { return }
        try indexes.forEach { entry in
            try db.update(table: CPYSnippetTable.tableName,
                          on: CPYSnippetTable.Properties.index,
                          with: entry.index,
                          where: CPYSnippetTable.Properties.identifier == entry.identifier)
        }
        status.markChanged()
    }
}
