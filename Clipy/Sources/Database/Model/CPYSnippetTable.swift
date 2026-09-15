//
//  CPYSnippetTable.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation
import WCDBSwift

/// Storage representation of a snippet.
///
/// `folderIdentifier` replaces Realm's `List<CPYSnippet>` / `LinkingObjects` pair, and
/// `index` (column `snippet_index`) is the single source of truth for ordering within a folder.
struct CPYSnippetTable: TableCodable, Equatable {

    static let tableName = "snippet"

    var identifier: String = ""
    var folderIdentifier: String = ""
    var index: Int = 0
    var enable: Bool = true
    var title: String = ""
    var content: String = ""

    enum CodingKeys: String, CodingTableKey {
        typealias Root = CPYSnippetTable

        case identifier
        case folderIdentifier = "folder_identifier"
        case index = "snippet_index"
        case enable
        case title
        case content

        static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(.identifier, isPrimary: true, isNotNull: true)
            BindIndex(folderIdentifier, namedWith: "_folderIdentifierIndex")
        }
    }
}

// MARK: - Convert DB type
extension CPYSnippetTable {
    var toSnippet: CPYSnippet {
        let snippet = CPYSnippet()
        snippet.identifier = identifier
        snippet.folderIdentifier = folderIdentifier
        snippet.index = index
        snippet.enable = enable
        snippet.title = title
        snippet.content = content
        return snippet
    }
}

extension CPYSnippet {
    var toTable: CPYSnippetTable {
        var table = CPYSnippetTable()
        table.identifier = identifier
        table.folderIdentifier = folderIdentifier
        table.index = index
        table.enable = enable
        table.title = title
        table.content = content
        return table
    }
}
