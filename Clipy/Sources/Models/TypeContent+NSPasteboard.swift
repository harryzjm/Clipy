// 
//  TypeContent+NSPasteboard.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
// 
//  Created by hares on 2026/9/18.
// 
//  Copyright © 2015-2026 Clipy Project.
//

import Cocoa

extension TypeContent {
    init?(pasteboard: NSPasteboard, type: NSPasteboard.PasteboardType) {
        switch type {
        case .string:
            guard let str = pasteboard.string(forType: .string)?.trim, str.isNotEmpty else { return nil }
            self = .string(str)
        case .fileURL:
            guard let str = pasteboard.string(forType: .fileURL)?.trim, str.isNotEmpty else { return nil }
            self = .fileURL(str)
        case .URL:
            guard let str = pasteboard.string(forType: .URL)?.trim, str.isNotEmpty else { return nil }
            self = .URL(str)
        case .rtf:
            guard let data = pasteboard.data(forType: .rtf) else { return nil }
            self = .rtf(data)
        case .rtfd:
            guard let data = pasteboard.data(forType: .rtfd) else { return nil }
            self = .rtfd(data)
        case .pdf:
            guard let data = pasteboard.data(forType: .pdf) else { return nil }
            self = .pdf(data)
        case .tiff:
            guard let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else { return nil }
            self = .tiff(.init(image: image))
        case .png:
            // The raw bytes, not an `NSImage` round trip: `Image.init(image:)` re-encodes to TIFF,
            // which `recover(to:)` would then hand back under the PNG type.
            guard let data = pasteboard.data(forType: .png) else { return nil }
            self = .png(.init(data: data))
        default:
            lWarning("unkonwn type:", type)
            return nil
        }
    }

    func recover(to pasteboard: NSPasteboard) {
        switch self {
        case .string(let value):
            pasteboard.setString(value, forType: .string)
        case .fileURL(let value):
            pasteboard.setString(value, forType: .fileURL)
        case .URL(let value):
            pasteboard.setString(value, forType: .URL)
        case .rtf(let value):
            pasteboard.setData(value, forType: .rtf)
        case .rtfd(let value):
            pasteboard.setData(value, forType: .rtfd)
        case .tiff(let value):
            pasteboard.setData(value.content, forType: .tiff)
        case .png(let value):
            pasteboard.setData(value.content, forType: .png)
        case .pdf(let value):
            guard let pdf = NSPDFImageRep(data: value) else { return }
            pasteboard.setData(pdf.pdfRepresentation, forType: .pdf)
        }
    }

    var toPasteboardType: NSPasteboard.PasteboardType? {
        switch self {
        case .string: return .string
        case .fileURL: return .fileURL
        case .URL: return .URL
        case .rtf: return .rtf
        case .rtfd: return .rtfd
        case .pdf: return .pdf
        case .png: return .png
        case .tiff: return .tiff
        }
    }
}
