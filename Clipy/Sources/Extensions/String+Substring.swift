//
//  String+Substring.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/03/17.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation

extension String {
    subscript (range: CountableClosedRange<Int>) -> String {
        let startIndex = self.index(self.startIndex, offsetBy: range.lowerBound, limitedBy: self.endIndex) ?? self.startIndex
        let endIndex = self.index(self.startIndex, offsetBy: range.upperBound, limitedBy: self.endIndex) ?? self.endIndex

        return String(self[startIndex..<endIndex])
    }
    
    func replace(pattern: String, options: NSRegularExpression.Options = [], withTemplate templ: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            return regex.stringByReplacingMatches(in: self, range: NSRange(location: 0, length: count), withTemplate: templ)
        } catch {
            print(error)
            return self
        }
    }
    
    func truncateToSize(size: CGSize, ellipses: String, trailingText: String, attributes: [NSAttributedString.Key: Any], trailingAttributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        if !willFit(to: size, attributes: attributes) {
            let indexOfLastCharacterThatFits = indexThatFits(size: size, ellipses: ellipses, trailingText: trailingText, attributes: attributes, min: 0, max: self.count)
            let range = startIndex..<self.index(startIndex, offsetBy: indexOfLastCharacterThatFits)
            let substring = String(self[range])
            let attributedString = NSMutableAttributedString(string: substring + ellipses, attributes: attributes)
            let attributedTrailingString = NSAttributedString(string: trailingText, attributes: trailingAttributes)
            attributedString.append(attributedTrailingString)
            return attributedString
        } else {
            return NSAttributedString(string: self, attributes: attributes)
        }
    }
    
    func willFit(to size: CGSize, ellipses: String = "", trailingText: String = "", attributes: [NSAttributedString.Key: Any]) -> Bool {
        let text = (self + ellipses + trailingText) as NSString
        let boundedSize = CGSize(width: size.width, height: .greatestFiniteMagnitude)
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let boundedRect = text.boundingRect(with: boundedSize, options: options, attributes: attributes, context: nil)
        return boundedRect.height <= size.height
    }
    
    private func indexThatFits(size: CGSize, ellipses: String, trailingText: String, attributes: [NSAttributedString.Key: Any], min: Int, max: Int) -> Int {
        guard max - min != 1 else { return min }
        let midIndex = (min + max) / 2
        let range = startIndex..<self.index(startIndex, offsetBy: midIndex)
        let substring = String(self[range])
        if !substring.willFit(to: size, ellipses: ellipses, trailingText: trailingText, attributes: attributes) {
            return indexThatFits(size: size, ellipses: ellipses, trailingText: trailingText, attributes: attributes, min: min, max: midIndex)
        } else {
            return indexThatFits(size: size, ellipses: ellipses, trailingText: trailingText, attributes: attributes, min: midIndex, max: max)
        }
    }
}
