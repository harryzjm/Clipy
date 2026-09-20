//
//  SnippetFilter.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Foundation

/// How the snippet menu's search field matches: a case-insensitive literal substring.
///
/// Deliberately not `ClipFilter`. The snippet database has no fts index and no match-mode
/// preference, so there is nothing to choose between — `%`, `*` and `?` are ordinary characters
/// here, and the query is never turned into a pattern.
struct SnippetFilter {

    /// Already trimmed and non-empty; an empty query means "no filter" and never reaches here.
    let query: String

    func matches(_ text: String) -> Bool {
        text.range(of: query, options: .caseInsensitive) != nil
    }

    /// Every occurrence of the query in `text`, in order.
    ///
    /// No merging step, unlike `ClipFilter`: one term's occurrences cannot overlap each other.
    func highlightRanges(in text: String) -> [Range<String.Index>] {
        guard !query.isEmpty else { return [] }

        var found: [Range<String.Index>] = []
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let range = text.range(of: query,
                                     options: .caseInsensitive,
                                     range: searchStart ..< text.endIndex) {
            found.append(range)
            searchStart = range.isEmpty ? text.index(after: range.lowerBound) : range.upperBound
        }
        return found
    }
}
