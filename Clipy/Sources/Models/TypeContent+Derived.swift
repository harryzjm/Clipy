//
//  TypeContent+Derived.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Cocoa

extension TypeContent {
    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .fileURL(let value):
            return value
        case .URL(let value):
            return value
        default:
            return nil
        }
    }
}

extension Array where Element == TypeContent {
    var stringValue: String? {
        firstMap {
            if case let .string(value) = $0 {
                return value
            }
            return nil
        } ?? firstMap {
            $0.stringValue
        }
    }

    var identifier: String {
        reduce("") { $0 + $1.identifier }.md5
    }

    var primaryType: NSPasteboard.PasteboardType? {
        return first?.toPasteboardType
    }

    var hasThumbnail: Bool {
        contains { type in
            switch type {
            case .png, .tiff, .fileURL: return true
            default: return false
            }
        }
    }

    var isColorCode: Bool {
        guard let hex = stringValue?.firstMatch(pattern: "^(?:0x|#)?([0-9a-fA-F]{6,8})$"),
              hex.isNotEmpty else { return false }
        return NSColor(hexString: hex) != nil
    }

    var thumbnailImage: NSImage? {
        let image: NSImage? = firstMap {
            switch $0 {
            case .png(let image):
                return image.image
            case .tiff(let image):
                return image.image
            default:
                return nil
            }
        } ?? firstMap {
            switch $0 {
            case .fileURL(let url):
                guard url.firstMatch(pattern: "\\.(jpg|jpeg|png|bmp|tiff)$").isNotEmpty else {
                    let ext = (url as NSString).pathExtension
                    return TypeContent.FileType(ext).image
                }
                var imagePath = url.replace(pattern: "^file://", withTemplate: "")
                imagePath = imagePath.removingPercentEncoding ?? imagePath
                return NSImage(contentsOfFile: imagePath) ?? TypeContent.FileType.image.image
            default: return nil
            }
        }
        return image?.cropToSquare(with: 24, and: .center)
    }

    var colorCodeImage: NSImage? {
        guard
            let hex = stringValue?.firstMatch(pattern: "^(?:0x|#)?([0-9a-fA-F]{6,8})$"),
            let color = NSColor(hexString: hex) else { return nil }
        return NSImage.create(with: color, size: NSSize(width: 20, height: 20))
    }
}
