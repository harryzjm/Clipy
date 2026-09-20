//
//  SnippetFilterTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import XCTest
@testable import Clipy

/// Covers `SnippetFilter`, the snippet menu's matcher: a case-insensitive literal substring and
/// nothing else.
final class SnippetFilterTests: XCTestCase {

    func testMatchesFoldsCase() {
        let filter = SnippetFilter(query: "GIT")

        XCTAssertTrue(filter.matches("git push"))
        XCTAssertTrue(filter.matches("a Git commit"))
        XCTAssertFalse(filter.matches("svn"))
    }

    /// The query is taken literally. `ClipFilter`'s wildcards have no meaning here, and a user
    /// typing `%` is looking for a per-cent sign.
    func testWildcardCharactersAreLiteral() {
        XCTAssertTrue(SnippetFilter(query: "50%").matches("50% off"))
        XCTAssertFalse(SnippetFilter(query: "%off").matches("50% of"))
        XCTAssertFalse(SnippetFilter(query: "g*t").matches("git"))
        XCTAssertFalse(SnippetFilter(query: "g?t").matches("git"))
    }

    /// Every occurrence is marked, not just the first.
    func testHighlightRangesFindsEveryOccurrence() {
        let text = "git rebase, git push"
        let ranges = SnippetFilter(query: "git").highlightRanges(in: text)

        XCTAssertEqual(ranges.map { text[$0].description }, ["git", "git"])
        XCTAssertEqual(ranges.map { text.distance(from: text.startIndex, to: $0.lowerBound) }, [0, 12])
    }

    func testHighlightRangesFoldsCase() {
        let text = "Deploy the deployment"
        let ranges = SnippetFilter(query: "DEPLOY").highlightRanges(in: text)

        XCTAssertEqual(ranges.map { text[$0].description }, ["Deploy", "deploy"])
    }

    func testHighlightRangesWithoutAHitIsEmpty() {
        XCTAssertTrue(SnippetFilter(query: "zzz").highlightRanges(in: "git push").isEmpty)
    }
}
