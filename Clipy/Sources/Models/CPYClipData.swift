//
//  CPYClipData.swift
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
import SwiftHEXColors

final class CPYClipData: NSObject, Codable {

    // MARK: - Properties
    //    fileprivate let kTypesKey       = "types"
    //    fileprivate let kStringValueKey = "stringValue"
    //    fileprivate let kRTFDataKey     = "RTFData"
    //    fileprivate let kPDFKey         = "PDF"
    //    fileprivate let kFileNamesKey   = "filenames"
    //    fileprivate let kURLsKey        = "URL"
    //    fileprivate let kImageKey       = "image"

    //    var types          = [NSPasteboard.PasteboardType]()
    var content = [TypeContent]()

    //    var fileNames      = [String]()
    //    var URLs           = [String]()
    var stringValue: String? {
        return content.lazy.compactMap { type in
            switch type {
                case .string(let value):
                    return value
                case .fileURL(let value):
                    return value
                case .URL(let value):
                    return value
                default:
                    return nil
            }
        }.first
    }

    //    init(from decoder: Decoder) throws {
    //        let container = try decoder.singleValueContainer()
    //        try super.init(string: container.decode(String.self))
    //    }

    //    override var hash: Int {
    //        var hash = types.map { $0.rawValue }.joined().hash
    //        if let image = self.image, let imageData = image.tiffRepresentation {
    //            hash ^= imageData.count
    //        } else if let image = self.image {
    //            hash ^= image.hash
    //        }
    //        if !fileNames.isEmpty {
    //            fileNames.forEach { hash ^= $0.hash }
    //        } else if !self.URLs.isEmpty {
    //            URLs.forEach { hash ^= $0.hash }
    //        } else if let pdf = PDF {
    //            hash ^= pdf.count
    //        } else if !stringValue.isEmpty {
    //            hash ^= stringValue.hash
    //        }
    ////        if let data = RTFData {
    ////            hash ^= data.count
    ////        }
    //        return hash
    //    }
    var primaryType: NSPasteboard.PasteboardType? {
        return content.first?.toPasteboardType
    }
    var isOnlyStringType: Bool {
        return false
        //        return types == [.string]
    }
    var thumbnailImage: NSImage? {
        return nil
        //        let defaults = UserDefaults.standard
        //        let width = defaults.integer(forKey: Preferences.Menu.thumbnailWidth)
        //        let height = defaults.integer(forKey: Preferences.Menu.thumbnailHeight)
        //
        //        if let image = image, fileNames.isEmpty {
        //            // Image only data
        //            return image.resizeImage(CGFloat(width), CGFloat(height))
        //        } else if let fileName = fileNames.first, let path = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let url = URL(string: path) {
        //            //  In the case of the local file correct data is not included in the image variable
        //            //  Judge the image from the path and create a thumbnail
        //            switch url.pathExtension.lowercased() {
        //                case "jpg", "jpeg", "png", "bmp", "tiff":
        //                    return NSImage(contentsOfFile: fileName)?.resizeImage(CGFloat(width), CGFloat(height))
        //                default: break
        //            }
        //        }
        //        return nil
    }
    var colorCodeImage: NSImage? {
        return nil
        //        guard let color = NSColor(hexString: stringValue) else { return nil }
        //        return NSImage.create(with: color, size: NSSize(width: 20, height: 20))
    }

    static var availableTypes: [NSPasteboard.PasteboardType] {
        return [.string,
                .rtf,
                .rtfd,
                .pdf,
                .png,
                .fileURL,
                .URL,
                .tiff]
    }
    static var availableTypesString: [String] {
        return ["String",
                "RTF",
                "RTFD",
                "PDF",
                "PNG",
                "Filenames",
                "URL",
                "TIFF"]
    }
    static var availableTypesDictionary: [NSPasteboard.PasteboardType: String] {
        var availableTypes = [NSPasteboard.PasteboardType: String]()
        zip(CPYClipData.availableTypes, CPYClipData.availableTypesString).forEach { availableTypes[$0] = $1 }
        return availableTypes
    }

    // MARK: - Init
    init(pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) {
        super.init()
        self.content = types.compactMap { type in
            return .init(pasteboard: pasteboard, type: type)
        }
    }

    init(image: NSImage) {
        //        self.types = [.tiff]
        //        self.image = image
    }
}

extension CPYClipData {
    enum TypeContent: Codable {
        case rtf(Data)
        case rtfd(Data)
        case pdf(Data)
        case string(String)
        case fileURL(String)
        case URL(String)
        case png(Image)
        case tiff(Image)

        init?(pasteboard: NSPasteboard, type: NSPasteboard.PasteboardType) {
            switch type {
                case .string:
                    guard let str = pasteboard.string(forType: .string) else { return nil }
                    self = .string(str)
                case .fileURL:
                    guard let str = pasteboard.string(forType: .fileURL) else { return nil }
                    self = .fileURL(str)
                case .URL:
                    guard let str = pasteboard.string(forType: .URL) else { return nil }
                    self = .URL(str)
                case .rtf:
                    guard let data = pasteboard.data(forType: .rtf) else { return nil }
                    self = .rtf(data)
                case .rtfd:
                    guard let data = pasteboard.data(forType: .rtf) else { return nil }
                    self = .rtfd(data)
                case .tiff:
                    guard let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else { return nil }
                    self = .tiff(.init(image: image))
                case .png:
                    guard let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else { return nil }
                    self = .tiff(.init(image: image))
                default:
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
