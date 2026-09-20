//
//  CPYSnippet.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2015/06/21.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa

final class CPYSnippet: NSObject {

    // MARK: - Properties
    @objc dynamic var index = 0
    @objc dynamic var enable = true
    @objc dynamic var title = ""
    @objc dynamic var content = ""
    @objc dynamic var identifier = UUID().uuidString
    /// A `TreeSitterLanguage` raw value, the syntax the editor highlights `content` as.
    ///
    /// Deliberately a plain `String`: the raw values are persisted identifiers, and keeping the
    /// model free of a `CodeEditLanguages` import means the database layer never links the editor.
    @objc dynamic var language = CPYSnippet.plainTextLanguage

    var folderIdentifier = ""

    override init() {
        super.init()
    }

    init(copying other: CPYSnippet) {
        super.init()
        index = other.index
        enable = other.enable
        title = other.title
        content = other.content
        identifier = other.identifier
        folderIdentifier = other.folderIdentifier
        language = other.language
    }

    /// The fallback for a snippet that has never had a language picked, and for one decoded from a
    /// snippets file written before the field existed.
    static let plainTextLanguage = "plainText"
}

extension CPYSnippet {
    var displayTitle: String {
        guard title.isEmpty else { return title }
        let derived = content.firstLine
        return derived.isEmpty ? L10n.Snippets.Sidebar.untitled : derived
    }
}

extension CPYSnippet: Codable {

    enum CodingKeys: String, CodingKey {
        case index
        case enable
        case title
        case content
        case identifier
        case language
    }

    convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try container.decode(Int.self, forKey: .index)
        enable = try container.decode(Bool.self, forKey: .enable)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        identifier = try container.decode(String.self, forKey: .identifier)
        // Optional on the way in: every snippets file exported before this field existed — and
        // everything `script/translate.py` writes — is missing it.
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? CPYSnippet.plainTextLanguage
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(enable, forKey: .enable)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(language, forKey: .language)
    }
}
