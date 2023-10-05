//
//  CPYSnippetsEditorCell.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/07/02.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import Cocoa

final class CPYSnippetsEditorCell: NSTextFieldCell {

    // MARK: - Properties
    var iconType = IconType.folder
    var isItemEnabled = false
    override var cellSize: NSSize {
        var size = super.cellSize
        size.width += 3.0 + 16.0
        return size
    }

    // MARK: - Enums
    enum IconType {
        case folder, none
    }

    // MARK: - Initialize
    required init(coder: NSCoder) {
        super.init(coder: coder)
        font = NSFont.systemFont(ofSize: 14)
    }

    override func copy(with zone: NSZone?) -> Any {
        guard let cell = super.copy(with: zone) as? CPYSnippetsEditorCell else { return super.copy(with: zone) }
        cell.iconType = iconType
        return cell
    }

    // MARK: - Draw
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        var newFrame: NSRect
        switch iconType {
        case .folder:
            var imageFrame = NSRect.zero
            var newCellFrame = NSRect.zero
            NSDivideRect(cellFrame, &imageFrame, &newCellFrame, 15, .minX)
            imageFrame.origin.y += 5
            imageFrame.size = NSSize(width: 16, height: 13)

            newFrame = newCellFrame
            newFrame.origin.y += 2
            newFrame.size.height -= 2
            textColor = isHighlighted ? .labelColor : Asset.Color.clipy.color
        case .none:
            newFrame = cellFrame
            newFrame.origin.y += 2
            newFrame.size.height -= 2
            textColor = .labelColor
        }

        textColor = isItemEnabled ? textColor : .disabledControlTextColor

        super.draw(withFrame: newFrame, in: controlView)
    }

    // MARK: - Frame
    override func select(withFrame aRect: NSRect, in controlView: NSView, editor textObj: NSText, delegate anObject: Any?, start selStart: Int, length selLength: Int) {
        let textFrame = titleRect(forBounds: aRect)
        super.select(withFrame: textFrame, in: controlView, editor: textObj, delegate: anObject, start: selStart, length: selLength)
    }

    override func edit(withFrame aRect: NSRect, in controlView: NSView, editor textObj: NSText, delegate anObject: Any?, event theEvent: NSEvent?) {
        let textFrame = titleRect(forBounds: aRect)
        super.edit(withFrame: textFrame, in: controlView, editor: textObj, delegate: anObject, event: theEvent)
    }

    override func titleRect(forBounds theRect: NSRect) -> NSRect {
        switch iconType {
        case .folder:

            var imageFrame = NSRect.zero
            var cellRect = NSRect.zero

            NSDivideRect(theRect, &imageFrame, &cellRect, 15, .minX)

            imageFrame.origin.y += 4
            imageFrame.size = CGSize(width: 16, height: 15)
            imageFrame.origin.y += ceil((cellRect.size.height - imageFrame.size.height) / 2)

            var newFrame = cellRect
            newFrame.origin.y += 2
            newFrame.size.height -= 2

            return newFrame

        case .none:
            var newFrame = theRect
            newFrame.origin.y += 2
            newFrame.size.height -= 2
            return newFrame
        }
    }
}
