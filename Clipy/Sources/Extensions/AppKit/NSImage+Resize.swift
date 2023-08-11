//
//  NSImage+Resize.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2015/07/26.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import Cocoa
import WebKit

extension NSImage {
    enum CropType {
        case head
        case center
        case tail
    }

    func cropToSquare(with length: CGFloat, and type: CropType) -> NSImage? {
        if size.width < length + .ulpOfOne {
            return self
        }
        return crop(type: type).resize(withSize: .init(width: length, height: length))
    }
}

fileprivate extension NSImage {
    func crop(type: CropType) -> NSImage {
        let handle = { (size: CGSize) -> CGRect in
            let length = min(size.width, size.height)
            switch type {
            case .head: return .init(x: 0, y: 0, width: length, height: length)
            case .center: return .init(x: (size.width - length) / 2, y: (size.height - length) / 2, width: length, height: length)
            case .tail: return .init(x: size.width - length, y: size.height - length, width: length, height: length)
            }
        }

        var imageRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        guard let imageRef = cgImage(forProposedRect: &imageRect, context: nil, hints: nil) else {
            return NSImage(size: handle(size).size)
        }
        let rect = handle(.init(width: imageRef.width, height: imageRef.height))
        guard let crop = imageRef.cropping(to: rect) else {
            return NSImage(size: handle(size).size)
        }
        return NSImage(cgImage: crop, size: NSSize.zero)
    }

    func resize(withSize targetSize: NSSize) -> NSImage? {
        let frame = NSRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
        guard let representation = bestRepresentation(for: frame, context: nil, hints: nil) else {
            return nil
        }
        let image = NSImage(size: targetSize, flipped: false, drawingHandler: { _ -> Bool in
            return representation.draw(in: frame)
        })

        return image
    }
}
