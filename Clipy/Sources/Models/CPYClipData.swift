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
import CommonCrypto

final class CPYClipData: NSObject, Codable {
    var content = [TypeContent]()

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

    var identifier: String {
        content.reduce("") { $0 + $1.identifier }.md5
    }

    var primaryType: NSPasteboard.PasteboardType? {
        return content.first?.toPasteboardType
    }

    var isValid: Bool {
        return content.count > 0
    }

    var thumbnailImage: NSImage? {
        let defaults = UserDefaults.standard
        let length = defaults.integer(forKey: Preferences.Menu.thumbnailLength)

        let image: NSImage? = content.compactMap { value -> NSImage? in
            switch value {
            case .png(let image):
                return image.image
            case .tiff(let image):
                return image.image
            case .fileURL(let url):
                guard url.firstMatch(pattern: "\\.(jpg|jpeg|png|bmp|tiff)$").isNotEmpty else {
                    let ext = (url as NSString).pathExtension
                    return CPYClipData.FileType(ext).image
                }
                var imagePath = url.replace(pattern: "^file://", withTemplate: "")
                imagePath = imagePath.removingPercentEncoding ?? imagePath
                return NSImage(contentsOfFile: imagePath) ?? FileType.image.image
            default: return nil
            }
        }.first
        return image?.cropToSquare(with: CGFloat(length), and: .center)
    }
    var colorCodeImage: NSImage? {
        guard
            let hex = stringValue?.firstMatch(pattern: "^(?:0x|#)?([0-9a-fA-F]{6,8})$"),
            let color = NSColor(hexString: hex) else { return nil }
        return NSImage.create(with: color, size: NSSize(width: 20, height: 20))
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

    init(title: String, image: NSImage) {
        super.init()
        self.content = [.string(title), .tiff(.init(image: image))]
    }

    init(title: String) {
        super.init()
        self.content = [.string(title)]
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
                    guard let data = pasteboard.data(forType: .rtf) else { return nil }
                    self = .rtfd(data)
                case .tiff:
                    guard let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else { return nil }
                    self = .tiff(.init(image: image))
                case .png:
                    guard let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else { return nil }
                    self = .tiff(.init(image: image))
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

        var identifier: String {
            switch self {
            case .string(let value):
                return "string" + value.md5
            case .fileURL(let value):
                return "fileURL" + value
            case .URL(let value):
                return "URL" + value
            case .rtf(let value):
                return "rtf" + value.md5
            case .rtfd(let value):
                return "rtfd" + value.md5
            case .tiff(let value):
                return "tiff" + (value.content?.md5 ?? "")
            case .png(let value):
                return "png" + (value.content?.md5 ?? "")
            case .pdf(let value):
                return "png" + value.md5
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

extension Data {
    var md5: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            return CC_MD5(bytes.baseAddress, CC_LONG(count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension String {
    var md5: String {
        let count = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: count)
        guard let data = data(using: .utf8) else { return "" }
        CC_MD5((data as NSData).bytes, CC_LONG(data.count), &digest)
        return string(from: digest, length: count)
    }

    private func string(from bytes: [UInt8], length: Int) -> String {
        var digestHex = ""
        for index in 0 ..< length {
            digestHex += String(format: "%02x", bytes[index])
        }
        return digestHex.lowercased()
    }
}
