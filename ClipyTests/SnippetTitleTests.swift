//
//  SnippetTitleTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import XCTest
@testable import Clipy

/// Covers the title a snippet shows when it has none of its own.
///
/// `CPYSnippet.displayTitle` is a pure function of `(title, content)`, so unlike most of the
/// snippets editor it can be tested without a database or an `AppEnvironment`.
final class SnippetTitleTests: XCTestCase {

    // MARK: - String.firstLine

    func testFirstLineTakesOnlyTheFirstLine() {
        XCTAssertEqual("first\nsecond\nthird".firstLine, "first")
    }

    /// CRLF is one break, not two — `getLineStart` rather than splitting on `\n`.
    func testFirstLineHandlesCRLFAndUnicodeSeparators() {
        XCTAssertEqual("first\r\nsecond".firstLine, "first")
        XCTAssertEqual("first\u{2028}second".firstLine, "first")
    }

    /// Trimmed at both ends before the split, so leading blank lines do not win.
    func testFirstLineTrimsSurroundingWhitespace() {
        XCTAssertEqual("  \n\n  first line  \nsecond".firstLine, "first line")
    }

    func testFirstLineOfSingleLineAndEmptyStrings() {
        XCTAssertEqual("only line".firstLine, "only line")
        XCTAssertEqual("".firstLine, "")
        XCTAssertEqual("   \n\t ".firstLine, "")
    }

    // MARK: - CPYSnippet.displayTitle

    func testTitleWinsWhenPresent() {
        XCTAssertEqual(snippet(title: "named", content: "body first line").displayTitle, "named")
    }

    func testEmptyTitleDerivesFromTheFirstLineOfTheBody() {
        XCTAssertEqual(snippet(title: "", content: "  first line\nsecond line").displayTitle, "first line")
    }

    /// Nothing to derive from leaves a placeholder rather than a blank, invisible row.
    func testEmptyTitleAndEmptyBodyFallBackToThePlaceholder() {
        XCTAssertEqual(snippet(title: "", content: "").displayTitle, L10n.Snippets.Sidebar.untitled)
        XCTAssertEqual(snippet(title: "", content: "  \n ").displayTitle, L10n.Snippets.Sidebar.untitled)
    }

    /// Snippets stored before the fallback existed carry this literal; it is a real title as far
    /// as `displayTitle` is concerned and is deliberately left alone.
    func testLegacyUntitledLiteralIsNotTreatedAsUnnamed() {
        XCTAssertEqual(snippet(title: "untitled snippet", content: "body").displayTitle, "untitled snippet")
    }

    /// The premise of the whole fallback: the editor no longer names what it creates.
    func testCreateSnippetLeavesTheTitleEmpty() {
        let folder = CPYFolder()

        XCTAssertEqual(folder.createSnippet().title, "")
    }
}

// MARK: - Fixtures
private extension SnippetTitleTests {

    func snippet(title: String, content: String) -> CPYSnippet {
        let snippet = CPYSnippet()
        snippet.title = title
        snippet.content = content
        return snippet
    }
}
