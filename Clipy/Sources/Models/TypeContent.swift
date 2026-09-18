//
//  TypeContent.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2015/06/21.
//
//  Copyright © 2015-2026 Clipy Project.
//

import Cocoa
import CryptoKit

enum TypeContent: Codable {
    case rtf(Data)
    case rtfd(Data)
    case pdf(Data)
    case string(String)
    case fileURL(String)
    case URL(String)
    case png(Image)
    case tiff(Image)

    var identifier: String {
        switch self {
        case .string(let value):
            return "string:" + value.md5
        case .fileURL(let value):
            return "fileURL:" + value
        case .URL(let value):
            return "URL:" + value
        case .rtf(let value):
            return "rtf:" + value.md5
        case .rtfd(let value):
            return "rtfd:" + value.md5
        case .tiff(let value):
            return "tiff:" + (value.content?.md5 ?? "")
        case .png(let value):
            return "png:" + (value.content?.md5 ?? "")
        case .pdf(let value):
            return "pdf:" + value.md5
        }
    }
}

// MARK: - Available types
extension TypeContent {
    static var availableTypes: [NSPasteboard.PasteboardType] {
        return [.string, .rtf, .rtfd, .pdf, .png, .fileURL, .URL, .tiff]
    }

    static var availableTypesString: [String] {
        return ["String", "RTF", "RTFD", "PDF", "PNG", "Filenames", "URL", "TIFF"]
    }

    static var availableTypesDictionary: [NSPasteboard.PasteboardType: String] {
        var availableTypes = [NSPasteboard.PasteboardType: String]()
        zip(TypeContent.availableTypes, TypeContent.availableTypesString).forEach { availableTypes[$0] = $1 }
        return availableTypes
    }
}

struct Image: Codable {
    private(set) var content: Data?

    init(image: NSImage?) {
        self.image = image
    }

    init(data: Data?) {
        self.content = data
    }

    var image: NSImage? {
        get { return content.flatMap(NSImage.init(data:)) }
        set { content = newValue?.tiffRepresentation(using: .jpeg, factor: 7) }
    }
}

extension Data {
    var md5: String {
        let hashedData = Insecure.MD5.hash(data: self)
        return hashedData.map { String(format: "%02hhx", $0) }.joined()
    }
}

extension String {
    var md5: String {
        let inputData = Data(utf8)
        let hashedData = Insecure.MD5.hash(data: inputData)
        return hashedData.map { String(format: "%02hhx", $0) }.joined()
    }
}
