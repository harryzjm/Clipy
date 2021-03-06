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

final class CPYClipData: NSObject, NSCoding {

    // MARK: - Properties
    fileprivate let kTypesKey       = "types"
    fileprivate let kStringValueKey = "stringValue"
    fileprivate let kRTFDataKey     = "RTFData"
    fileprivate let kPDFKey         = "PDF"
    fileprivate let kFileNamesKey   = "filenames"
    fileprivate let kURLsKey        = "URL"
    fileprivate let kImageKey       = "image"

    var types          = [NSPasteboard.PasteboardType]()
    var fileNames      = [String]()
    var URLs           = [String]()
    var stringValue    = ""
    var RTFData: Data?
    var PDF: Data?
    var image: NSImage?

    override var hash: Int {
        var hash = types.map { $0.rawValue }.joined().hash
        if let image = self.image, let imageData = image.tiffRepresentation {
            hash ^= imageData.count
        } else if let image = self.image {
            hash ^= image.hash
        }
        if !fileNames.isEmpty {
            fileNames.forEach { hash ^= $0.hash }
        } else if !self.URLs.isEmpty {
            URLs.forEach { hash ^= $0.hash }
        } else if let pdf = PDF {
            hash ^= pdf.count
        } else if !stringValue.isEmpty {
            hash ^= stringValue.hash
        }
        if let data = RTFData {
            hash ^= data.count
        }
        return hash
    }
    var primaryType: NSPasteboard.PasteboardType? {
        return types.first
    }
    var isOnlyStringType: Bool {
        return types == [.deprecatedString]
    }
    var thumbnailImage: NSImage? {
        let defaults = UserDefaults.standard
        let width = defaults.integer(forKey: Preferences.Menu.thumbnailWidth)
        let height = defaults.integer(forKey: Preferences.Menu.thumbnailHeight)

        if let image = image, fileNames.isEmpty {
            // Image only data
            return image.resizeImage(CGFloat(width), CGFloat(height))
        } else if let fileName = fileNames.first, let path = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let url = URL(string: path) {
             //  In the case of the local file correct data is not included in the image variable
             //  Judge the image from the path and create a thumbnail
            switch url.pathExtension.lowercased() {
            case "jpg", "jpeg", "png", "bmp", "tiff":
                return NSImage(contentsOfFile: fileName)?.resizeImage(CGFloat(width), CGFloat(height))
            default: break
            }
        }
        return nil
    }
    var colorCodeImage: NSImage? {
        guard let color = NSColor(hexString: stringValue) else { return nil }
        return NSImage.create(with: color, size: NSSize(width: 20, height: 20))
    }

    static var availableTypes: [NSPasteboard.PasteboardType] {
        return [.deprecatedString,
                .deprecatedRTF,
                .deprecatedRTFD,
                .deprecatedPDF,
                .deprecatedFilenames,
                .deprecatedURL,
                .deprecatedTIFF]
    }
    static var availableTypesString: [String] {
        return ["String",
                "RTF",
                "RTFD",
                "PDF",
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
        self.types = types
        types.forEach { type in
            switch type {
            case .deprecatedString:
                guard let string = pasteboard.string(forType: .deprecatedString) else { return }
                stringValue = string
            case .deprecatedRTFD:
                RTFData = pasteboard.data(forType: .deprecatedRTFD)
            case .deprecatedRTF where RTFData == nil:
                RTFData = pasteboard.data(forType: .deprecatedRTF)
            case .deprecatedPDF:
                PDF = pasteboard.data(forType: .deprecatedPDF)
            case .deprecatedFilenames:
                guard let filenames = pasteboard.propertyList(forType: .deprecatedFilenames) as? [String] else { return }
                self.fileNames = filenames
            case .deprecatedURL:
                guard let urls = pasteboard.propertyList(forType: .deprecatedURL) as? [String] else { return }
                URLs = urls
            case .deprecatedTIFF:
                image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage
            default: break
            }
        }
    }

    init(image: NSImage) {
        self.types = [.deprecatedTIFF]
        self.image = image
    }

    deinit {
        self.RTFData = nil
        self.PDF = nil
        self.image = nil
    }

    // MARK: - NSCoding
    @objc func encode(with coder: NSCoder) {
        coder.encode(types.map { $0.rawValue }, forKey: kTypesKey)
        coder.encode(stringValue, forKey: kStringValueKey)
        coder.encode(RTFData, forKey: kRTFDataKey)
        coder.encode(PDF, forKey: kPDFKey)
        coder.encode(fileNames, forKey: kFileNamesKey)
        coder.encode(URLs, forKey: kURLsKey)
        coder.encode(image, forKey: kImageKey)
    }

    @objc required init?(coder: NSCoder) {
        types = (coder.decodeObject(forKey: kTypesKey) as? [String])?.compactMap { NSPasteboard.PasteboardType(rawValue: $0) } ?? []
        fileNames = coder.decodeObject(forKey: kFileNamesKey) as? [String] ?? [String]()
        URLs = coder.decodeObject(forKey: kURLsKey) as? [String] ?? [String]()
        stringValue = coder.decodeObject(forKey: kStringValueKey) as? String ?? ""
        RTFData = coder.decodeObject(forKey: kRTFDataKey) as? Data
        PDF = coder.decodeObject(forKey: kPDFKey) as? Data
        image = coder.decodeObject(forKey: kImageKey) as? NSImage
        super.init()
    }
}
