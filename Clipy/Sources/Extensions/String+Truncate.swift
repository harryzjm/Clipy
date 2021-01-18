// 
//  String+Truncate.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
// 
//  Created by Aphro Hares on 2020/10/27.
// 
//  Copyright © 2015-2020 Clipy Project.
//

import Foundation

extension String {
    func sizeOf(attributes: [NSAttributedString.Key: Any]) -> CGSize {
        guard isNotEmpty else { return .zero }
        let boundedSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        return self.boundingRect(with: boundedSize,
                                 options: options,
                                 attributes: attributes,
                                 context: nil).size
    }

    func truncateToSize(size: CGSize, ellipsis: String, keyWord: String, attributes: [NSAttributedString.Key: Any], keyWordAttributes: [NSAttributedString.Key: Any]? = nil) -> NSAttributedString {
        guard keyWord.isNotEmpty, let keyWordRange = searchRange(of: keyWord) else {
            return truncateToSize(size: size, ellipsis: ellipsis, attributes: attributes)
        }

        let test = ellipsis + String(self[keyWordRange]) + ellipsis
        guard test.willFit(to: size, attributes: keyWordAttributes ?? attributes) else {
            if keyWordRange.lowerBound == startIndex {
                return String(self[keyWordRange]).truncateToSize(size: size, ellipsis: ellipsis, attributes: keyWordAttributes ?? attributes)
            } else {
                return (ellipsis + String(self[keyWordRange])).truncateToSize(size: size, ellipsis: ellipsis, attributes: keyWordAttributes ?? attributes)
            }
        }

        let range = indexThatFits(size: size, ellipsis: ellipsis, range: keyWordRange, isPositive: false, attributes: attributes)
        let substring = String(self[range])
        let mAtt = NSMutableAttributedString()
        if range.lowerBound != self.startIndex {
            mAtt.append(.init(string: ellipsis, attributes: attributes))
        }
        mAtt.append(.init(string: substring, attributes: attributes))
        if range.upperBound != self.endIndex {
            mAtt.append(.init(string: ellipsis, attributes: attributes))
        }
        if let keyWordAttributes = keyWordAttributes, let range = mAtt.string.searchRange(of: keyWord) {
            mAtt.addAttributes(keyWordAttributes, range: .init(range, in: mAtt.string))
        }
        return mAtt
    }

    private func indexThatFits(size: CGSize, ellipsis: String = "", range: Range<String.Index>, isPositive: Bool, attributes: [NSAttributedString.Key: Any]) -> Range<String.Index> {
        if range.lowerBound == startIndex && range.upperBound == endIndex { return range }
        let isPositive: Bool = {
            if isPositive && range.lowerBound == startIndex { return false }
            if !isPositive && range.upperBound == endIndex { return true }
            return isPositive
        }()

        let nextRange: Range<String.Index> = {
            if isPositive {
                return .init(uncheckedBounds: (index(before: range.lowerBound), range.upperBound))
            } else {
                return .init(uncheckedBounds: (range.lowerBound, index(after: range.upperBound)))
            }
        }()

        let substring = String(self[nextRange])
        if substring.willFit(to: size, ellipsis: ellipsis, range: nextRange, attributes: attributes) {
            return indexThatFits(size: size, ellipsis: ellipsis, range: nextRange, isPositive: !isPositive, attributes: attributes)
        } else {
            return range
        }
    }

    private func willFit(to size: CGSize, ellipsis: String = "", range: Range<String.Index>? = nil, attributes: [NSAttributedString.Key: Any]) -> Bool {
        let text: String = {
            guard let range = range else { return self }
            switch (range.lowerBound, range.upperBound) {
            case (startIndex, endIndex): return self
            case (startIndex, _): return self + ellipsis
            case (_, endIndex): return ellipsis + self
            default: return ellipsis + self + ellipsis
            }
        }()
        let boundedSize = CGSize(width: size.width, height: .greatestFiniteMagnitude)
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let boundedRect = text.boundingRect(with: boundedSize, options: options, attributes: attributes, context: nil)
        return boundedRect.height <= size.height
    }

    private func truncateToSize(size: CGSize, ellipsis: String, attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        if willFit(to: size, attributes: attributes) {
            return NSAttributedString(string: self, attributes: attributes)
        }

        let indexOfLastCharacterThatFits = indexThatFits(size: size, ellipsis: ellipsis, attributes: attributes, min: 0, max: count)
        let substring = string(at: indexOfLastCharacterThatFits)
        return NSAttributedString(string: substring + ellipsis, attributes: attributes)
    }

    private func string(at offset: Int) -> String {
        let range = startIndex ..< index(startIndex, offsetBy: offset)
        return String(self[range])

    }

    private func indexThatFits(size: CGSize, ellipsis: String, attributes: [NSAttributedString.Key: Any], min: Int, max: Int) -> Int {
        guard max - min != 1 else { return min }
        let midIndex = (min + max) / 2
        let substring = string(at: midIndex)
        let isFit = substring.willFit(to: size, ellipsis: ellipsis, attributes: attributes)

        if isFit {
            return indexThatFits(size: size, ellipsis: ellipsis, attributes: attributes, min: midIndex, max: max)
        } else {
            return indexThatFits(size: size, ellipsis: ellipsis, attributes: attributes, min: min, max: midIndex)
        }
    }

    private func willFit(to size: CGSize, ellipsis: String = "", attributes: [NSAttributedString.Key: Any]) -> Bool {
        let text: String = self + ellipsis

        let boundedSize = CGSize(width: size.width, height: .greatestFiniteMagnitude)
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let boundedRect = text.boundingRect(with: boundedSize, options: options, attributes: attributes, context: nil)
        return boundedRect.height <= size.height
    }
}
