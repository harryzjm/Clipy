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

    func searchRange(of filter: String) -> Range<String.Index>? {
        var pattern: String?
        if filter.contains("?") {
            pattern = filter
                .components(separatedBy: "?")
                .joined(separator: ".")
        }

        if filter.contains("*") {
            pattern = (pattern ?? filter)
                .components(separatedBy: "*")
                .joined(separator: ".*?")
        }

        guard let reg = pattern else {
            return range(of: filter, options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive])
        }

        do {
            let regex = try NSRegularExpression(pattern: reg, options: [.caseInsensitive])
            let range = regex.firstMatch(in: self,
                                         options: [],
                                         range: .init(location: 0, length: count))?.range
            return range.flatMap { Range($0, in: self) }
        } catch {
            lError(error)
            return nil
        }
    }

    func replace(pattern: String, options: NSRegularExpression.Options = [], withTemplate templ: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            return regex.stringByReplacingMatches(in: self, range: NSRange(location: 0, length: count), withTemplate: templ)
        } catch {
            lError(error)
            return self
        }
    }

    func firstSubstring(pattern: String,
                        options: NSRegularExpression.Options = [],
                        matchingOptions: NSRegularExpression.MatchingOptions = []) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let range = regex.firstMatch(in: self,
                                         options: matchingOptions,
                                         range: .init(location: 0, length: count))?.range
            return range.flatMap { rg in
                return (self as NSString).substring(with: rg)
            }
        } catch {
            lError(error)
            return nil
        }
    }

}
