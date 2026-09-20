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

struct CPYSnippetTable: TableCodable, Equatable {

    static let tableName = "snippet"

    var identifier: String = ""
    var folderIdentifier: String = ""
    var index: Int = 0
    var enable: Bool = true
    var title: String = ""
    var content: String = ""
    var language: String = CPYSnippet.plainTextLanguage

    enum CodingKeys: String, CodingTableKey {
        typealias Root = CPYSnippetTable

        case identifier
        case folderIdentifier = "folder_identifier"
        case index = "snippet_index"
        case enable
        case title
        case content
        case language

        static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(.identifier, isPrimary: true, isNotNull: true)
            // The SQL default is what every row written before migration 2 gets: WCDB adds the
            // column with this `ALTER TABLE`, so an existing snippet reads back as plain text
            // rather than as NULL decoded into an empty string no language matches.
            BindColumnConstraint(.language,
                                 isNotNull: true,
                                 defaultTo: LiteralValue(CPYSnippet.plainTextLanguage))
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
        snippet.language = language
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
        table.language = language
        return table
    }
}
