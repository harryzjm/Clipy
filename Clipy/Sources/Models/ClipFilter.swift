//
//  ClipFilter.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Foundation

/// How the filter field's text is matched against a clip title.
///
/// The raw values are persisted in `UserDefaults` under `Preferences.Menu.filterMatchMode`,
/// so an existing case must keep its number.
///
/// Adding a mode means adding a case here; the compiler then forces both halves to be
/// filled in — `ClipDB.fetchClips(filter:limit:)` (how to query) and
/// `ClipFilter.highlightRanges(in:)` (how to mark the match). Nothing else needs to change.
enum FilterMatchMode: Int, CaseIterable, Identifiable {
    case like = 0
    case glob = 1
    case fts = 2

    /// The regex for "any run of characters", shared so the highlight can recognise — and trim —
    /// the fragments it generated itself.
    static let anyFragment = ".*?"

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .like: return "LIKE (% _)"
        case .glob: return "GLOB (* ?)"
        case .fts: return "FTS (word*)"
        }
    }

    /// Mirrors SQLite: `LIKE` folds ASCII case, `GLOB` does not, and fts5's tokenizer folds case
    /// as well. Highlighting follows suit so it never marks a span the query did not actually
    /// match on.
    var isCaseInsensitive: Bool {
        switch self {
        case .like, .fts: return true
        case .glob: return false
        }
    }

    /// The regex equivalent of `character`, or `nil` when this mode treats it as a literal.
    ///
    /// `GLOB`'s `[...]` sets are deliberately absent: SQLite still matches them, the highlight
    /// just won't find a span to mark. `.fts` has no wildcards at all — its hits come back from
    /// fts5 itself rather than from re-matching the query.
    func regexFragment(forWildcard character: Character) -> String? {
        switch (self, character) {
        case (.like, "%"), (.glob, "*"): return Self.anyFragment
        case (.like, "_"), (.glob, "?"): return "."
        default: return nil
        }
    }
}

/// One filter query. Everything about *how* a query matches lives here — the SQL side reads
/// `pattern`, the menu side reads `highlightRanges(in:)`, and nobody else parses the raw text.
struct ClipFilter {
    let query: String
    let mode: FilterMatchMode
    /// The text fts5 reported as actually hit in one particular title. Always empty for
    /// `.like` / `.glob`, whose spans are derived from the query instead.
    let matchedTerms: [String]

    init(query: String, mode: FilterMatchMode, matchedTerms: [String] = []) {
        self.query = query
        self.mode = mode
        self.matchedTerms = matchedTerms
    }

    /// The query padded with this mode's "anything" wildcard on both sides, so it matches in the
    /// middle of a title. **SQL only** — highlighting uses the unpadded `query`, otherwise the
    /// padding would match the whole title and mark every character.
    var pattern: String {
        switch mode {
        case .like: return "%\(query)%"
        case .glob: return "*\(query)*"
        case .fts: return ftsMatchExpression
        }
    }

    /// Attaches one row's hits. A no-op outside `.fts`, which is the only mode that has any.
    func marking(_ terms: [String]) -> ClipFilter {
        guard mode == .fts else { return self }
        return ClipFilter(query: query, mode: mode, matchedTerms: terms)
    }

    /// Every span to mark in `text`, ordered by start and non-overlapping. Empty means mark
    /// nothing.
    func highlightRanges(in text: String) -> [Range<String.Index>] {
        switch mode {
        case .like, .glob: return wildcardRange(in: text).map { [$0] } ?? []
        case .fts: return termRanges(in: text)
        }
    }
}

// MARK: - LIKE / GLOB
private extension ClipFilter {
    /// Locates the span to mark in `text`, using the raw query without the padding.
    func wildcardRange(in text: String) -> Range<String.Index>? {
        guard !query.isEmpty else { return nil }

        guard let pattern = regexPattern else {
            return text.range(of: query, options: mode.isCaseInsensitive ? [.caseInsensitive] : [])
        }
        // Nothing but wildcards: SQL matches every row, but there is no span worth marking.
        guard !pattern.isEmpty else { return nil }

        do {
            let regex = try NSRegularExpression(pattern: pattern,
                                                options: mode.isCaseInsensitive ? [.caseInsensitive] : [])
            let range = regex.firstMatch(in: text,
                                         options: [],
                                         range: NSRange(text.startIndex..., in: text))?.range
            return range.flatMap { Range($0, in: text) }
        } catch {
            lError(error)
            return nil
        }
    }

    /// `nil` when the query holds no wildcard for this mode, in which case a plain substring
    /// search is both cheaper and exactly equivalent. `""` when the query was *only* wildcards,
    /// which is a match but not a highlight — the two cases are distinct and the caller
    /// separates them.
    var regexPattern: String? {
        guard query.contains(where: { mode.regexFragment(forWildcard: $0) != nil }) else { return nil }

        var fragments: [String] = []
        var literal = ""

        func flushLiteral() {
            guard !literal.isEmpty else { return }
            fragments.append(NSRegularExpression.escapedPattern(for: literal))
            literal = ""
        }

        for character in query {
            if let fragment = mode.regexFragment(forWildcard: character) {
                flushLiteral()
                fragments.append(fragment)
            } else {
                literal.append(character)
            }
        }
        flushLiteral()

        // A leading or trailing "match anything" adds nothing visible, but being lazy at the
        // start it would still stretch the span out to the beginning of the line — `%abc` marked
        // the whole line up to `abc`. Trim it off both ends, repeatedly, since `%%abc` produces
        // two. The `.` from `_` / `?` stays: it consumes a real character that is part of the hit.
        while fragments.first == FilterMatchMode.anyFragment { fragments.removeFirst() }
        while fragments.last == FilterMatchMode.anyFragment { fragments.removeLast() }

        return fragments.joined()
    }
}

// MARK: - FTS
private extension ClipFilter {
    /// Turns the raw field text into an FTS5 MATCH expression: split on whitespace, each piece
    /// escaped into a prefix phrase, which FTS5 then ANDs together.
    ///
    /// The quoting is the safety-critical part — a bare `"`, `(`, `-` or `OR` reads as query
    /// syntax, and typing one character at a time would walk through a series of syntax errors.
    /// The trailing `*` is what makes search-as-you-type useful: `hel` matches `hello`.
    var ftsMatchExpression: String {
        query.split(whereSeparator: \.isWhitespace)
            .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"*" }
            .joined(separator: " ")
    }

    /// Every occurrence of every hit fts5 reported, merged where they overlap.
    ///
    /// The spans have to be re-found rather than read off fts5's byte offsets: the displayed
    /// string is not the stored `title` — whitespace is collapsed and a `[Image] ` / `[File] `
    /// prefix may have been added — so the offsets would not line up.
    func termRanges(in text: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []

        for term in matchedTerms where !term.isEmpty {
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text.range(of: term,
                                         options: .caseInsensitive,
                                         range: searchStart ..< text.endIndex) {
                found.append(range)
                searchStart = range.isEmpty ? text.index(after: range.lowerBound) : range.upperBound
            }
        }

        return Self.merged(found)
    }

    static func merged(_ ranges: [Range<String.Index>]) -> [Range<String.Index>] {
        ranges
            .sorted { $0.lowerBound < $1.lowerBound }
            .reduce(into: []) { result, range in
                guard let last = result.last, range.lowerBound <= last.upperBound else {
                    result.append(range)
                    return
                }
                result[result.count - 1] = last.lowerBound ..< Swift.max(last.upperBound, range.upperBound)
            }
    }
}

/// The result of one filtered history read.
///
/// `matchedTerms` is keyed by `dataHash` and only `.fts` fills it — fts5 is the only matcher
/// that knows which tokens actually hit. `.like` / `.glob` leave it empty and derive their
/// highlight from the query itself.
struct ClipSearchResult {
    let clips: [CPYClip]
    let matchedTerms: [String: [String]]

    static let empty = ClipSearchResult(clips: [], matchedTerms: [:])
}
