//
//  CPYFolder.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2015/06/21.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation

/// Domain projection of `CPYFolderTable` plus its snippets.
///
/// The `NSObject` inheritance is vestigial: it existed so the old `NSOutlineView`-based snippets
/// editor could use instances directly as items, which needed stable `isEqual:` identity. The
/// SwiftUI editor projects these into value types instead, so the base class and the
/// `@objc dynamic` property attributes could be dropped in a follow-up.
///
/// `snippets` is always kept sorted by `CPYSnippet.index`; that column is the single source of
/// truth for ordering, and `rearrangesSnippetIndex()` rewrites it from the array order.
final class CPYFolder: NSObject {

    // MARK: - Properties
    @objc dynamic var index = 0
    @objc dynamic var enable = true
    @objc dynamic var title = ""
    @objc dynamic var identifier = UUID().uuidString
    var snippets = [CPYSnippet]()

    override init() {
        super.init()
    }
}

// MARK: - Codable
// Hand-written rather than synthesized: the key set is the snippets import/export file format
// (see `script/translate.py`), so it must not drift.
extension CPYFolder: Codable {

    enum CodingKeys: String, CodingKey {
        case index
        case enable
        case title
        case identifier
        case snippets
    }

    convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try container.decode(Int.self, forKey: .index)
        enable = try container.decode(Bool.self, forKey: .enable)
        title = try container.decode(String.self, forKey: .title)
        identifier = try container.decode(String.self, forKey: .identifier)
        snippets = try container.decodeIfPresent([CPYSnippet].self, forKey: .snippets) ?? []
        // Imported snippets carry no owner; wire them to this folder.
        snippets.forEach { $0.folderIdentifier = identifier }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(enable, forKey: .enable)
        try container.encode(title, forKey: .title)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(snippets, forKey: .snippets)
    }
}

// MARK: - Create Snippet
extension CPYFolder {
    func createSnippet() -> CPYSnippet {
        let snippet = CPYSnippet()
        snippet.title = "untitled snippet"
        snippet.index = snippets.count
        snippet.folderIdentifier = identifier
        return snippet
    }
}
