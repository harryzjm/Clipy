//
//  SnippetTransaction+Ext.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation

// MARK: - Read
extension SnippetServiceTransaction {

    /// Every folder, ordered by `index`, each with its snippets ordered by `index`.
    func fetchFolders() throws -> [CPYFolder] {
        let folderTables = try snippetDb.fetchFolderTables()
        guard !folderTables.isEmpty else { return [] }

        let snippetsByFolder = Dictionary(grouping: try snippetDb.fetchAllSnippetTables(),
                                          by: { $0.folderIdentifier })
        return folderTables.map { table in
            let snippets = (snippetsByFolder[table.identifier] ?? [])
                .sorted { $0.index < $1.index }
                .map { $0.toSnippet }
            return table.toFolder(snippets: snippets)
        }
    }

    func fetchFolder(identifier: String) throws -> CPYFolder? {
        guard let table = try snippetDb.fetchFolderTable(identifier: identifier) else { return nil }
        let snippets = try snippetDb.fetchSnippetTables(folderIdentifier: identifier).map { $0.toSnippet }
        return table.toFolder(snippets: snippets)
    }

    func fetchSnippet(identifier: String) throws -> CPYSnippet? {
        try snippetDb.fetchSnippetTable(identifier: identifier)?.toSnippet
    }

    /// Index to give a newly created folder so it lands at the end of the list.
    func nextFolderIndex() throws -> Int {
        (try snippetDb.maxFolderIndex() ?? -1) + 1
    }
}

// MARK: - Folder
extension SnippetServiceTransaction {

    /// Upsert of the folder row only. Snippets are owned by their own rows via
    /// `folder_identifier`, so this can never clobber them — which is what the old
    /// hand-rolled partial `CPYFolder.merge()` was working around.
    func upsertFolder(_ folder: CPYFolder) throws {
        try snippetDb.upsertFolder(folder.toTable)
    }

    /// Deletes the folder and its snippets in a single transaction.
    func removeFolder(identifier: String) throws {
        try snippetDb.deleteSnippets(folderIdentifier: identifier)
        try snippetDb.deleteFolder(identifier: identifier)
    }

    /// Rewrites `folder.index` from the array order, in one transaction.
    func rearrangeFolders(_ folders: [CPYFolder]) throws {
        let indexes = folders.enumerated().map { (identifier: $0.element.identifier, index: $0.offset) }
        try snippetDb.updateFolderIndexes(indexes)
    }

    /// Bulk import: folders plus all of their snippets.
    func importFolders(_ folders: [CPYFolder]) throws {
        try snippetDb.upsertFolders(folders.map { $0.toTable })
        let snippets = folders.flatMap { folder in
            folder.snippets.map { snippet -> CPYSnippetTable in
                var table = snippet.toTable
                table.folderIdentifier = folder.identifier
                return table
            }
        }
        try snippetDb.upsertSnippets(snippets)
    }
}

// MARK: - Snippet
extension SnippetServiceTransaction {

    func upsertSnippet(_ snippet: CPYSnippet) throws {
        try snippetDb.upsertSnippet(snippet.toTable)
    }

    /// Adds a snippet to a folder, appending it at the end.
    func appendSnippet(_ snippet: CPYSnippet, folderIdentifier: String) throws {
        var table = snippet.toTable
        table.folderIdentifier = folderIdentifier
        table.index = try snippetDb.fetchSnippetTables(folderIdentifier: folderIdentifier).count
        try snippetDb.upsertSnippet(table)
    }

    /// Moves a snippet into a folder at a given position, then renumbers that folder.
    func insertSnippet(_ snippet: CPYSnippet, folderIdentifier: String, index: Int) throws {
        var siblings = try snippetDb.fetchSnippetTables(folderIdentifier: folderIdentifier)
            .filter { $0.identifier != snippet.identifier }

        var table = snippet.toTable
        table.folderIdentifier = folderIdentifier
        siblings.insert(table, at: max(0, min(index, siblings.count)))

        try snippetDb.upsertSnippet(table)
        try snippetDb.updateSnippetIndexes(siblings.enumerated().map {
            (identifier: $0.element.identifier, index: $0.offset)
        })
    }

    func removeSnippet(identifier: String) throws {
        try snippetDb.deleteSnippet(identifier: identifier)
    }

    /// Removes a snippet *from a particular folder*, and only if it still belongs to it.
    ///
    /// The editor moves a snippet across folders by inserting into the destination and then
    /// removing from the source. Realm's `List` made that a pair of link edits; with a
    /// `folder_identifier` column the insert has already re-parented the row, so an unguarded
    /// delete here would destroy the snippet that was just moved.
    func removeSnippet(identifier: String, fromFolder folderIdentifier: String) throws {
        guard let table = try snippetDb.fetchSnippetTable(identifier: identifier),
              table.folderIdentifier == folderIdentifier else { return }
        try snippetDb.deleteSnippet(identifier: identifier)
    }

    /// Rewrites `snippet.index` from the array order, in one transaction.
    ///
    /// The Realm version opened a fresh Realm and committed one write per row, and bailed out of
    /// the whole loop on the first missing row.
    func rearrangeSnippets(_ snippets: [CPYSnippet]) throws {
        let indexes = snippets.enumerated().map { (identifier: $0.element.identifier, index: $0.offset) }
        try snippetDb.updateSnippetIndexes(indexes)
    }
}
