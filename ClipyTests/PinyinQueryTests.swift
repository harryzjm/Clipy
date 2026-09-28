//
//  PinyinQueryTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import XCTest
@testable import Clipy

/// Covers how typed pinyin is split into per-character tokens before it reaches fts5.
final class PinyinQueryTests: XCTestCase {

    func testFullPinyinSplitsIntoSyllables() {
        XCTAssertEqual(PinyinQuery.phrases(for: "zhongguo").first, ["zhong", "guo"])
    }

    /// `xian` is one character (先) or two (西安); both readings have to be searched.
    func testAmbiguousSplitKeepsEveryReading() {
        let phrases = PinyinQuery.phrases(for: "xian")
        XCTAssertEqual(phrases.first, ["xian"])
        XCTAssertTrue(phrases.contains(["xi", "an"]))
    }

    func testApostropheForcesBoundary() {
        let phrases = PinyinQuery.phrases(for: "xi'an")
        XCTAssertEqual(phrases.first, ["xi", "an"])
        XCTAssertFalse(phrases.contains(["xian"]))
    }

    func testEquallyShortSplitsAreBothKept() {
        let phrases = PinyinQuery.phrases(for: "fangan")
        XCTAssertTrue(phrases.contains(["fang", "an"]))
        XCTAssertTrue(phrases.contains(["fan", "gan"]))
    }

    func testInitialsOnly() {
        XCTAssertEqual(PinyinQuery.phrases(for: "zg").first, ["z", "g"])
    }

    /// The index knows 中 by `z`, not `zh`, so a typed retroflex initial maps to its first letter.
    func testRetroflexInitialMapsToFirstLetter() {
        XCTAssertTrue(PinyinQuery.phrases(for: "zhg").contains(["z", "g"]))
    }

    /// Only the last unit may be incomplete — it is what is still being typed.
    func testTrailingPartialSyllable() {
        XCTAssertEqual(PinyinQuery.phrases(for: "zhongg").first, ["zhong", "g"])
        XCTAssertEqual(PinyinQuery.phrases(for: "zhon").first, ["zhon"])
    }

    func testMixedInitialAndSyllable() {
        XCTAssertEqual(PinyinQuery.phrases(for: "zguo").first, ["z", "guo"])
    }

    /// A clean full-pinyin reading must not be diluted by letter-by-letter initials.
    func testNoDegenerateLetterByLetterReading() {
        XCTAssertFalse(PinyinQuery.phrases(for: "zhongguo").contains { $0.count > 3 })
    }

    func testCaseIsFolded() {
        XCTAssertEqual(PinyinQuery.phrases(for: "ZhongGuo").first, ["zhong", "guo"])
    }

    func testNonPinyinYieldsNothing() {
        XCTAssertEqual(PinyinQuery.phrases(for: "2024"), [])
        XCTAssertEqual(PinyinQuery.phrases(for: "中国"), [])
        XCTAssertEqual(PinyinQuery.phrases(for: "zhong-guo"), [])
        XCTAssertEqual(PinyinQuery.phrases(for: ""), [])
        XCTAssertEqual(PinyinQuery.phrases(for: String(repeating: "a", count: PinyinQuery.maxLetters + 1)), [])
    }

    func testAlternativesAreCapped() {
        XCTAssertLessThanOrEqual(PinyinQuery.phrases(for: "xianxianxianxian").count, PinyinQuery.maxPhrases)
    }

    func testMatchExpressionOrsReadingsAndAndsPieces() {
        let filter = ClipFilter(query: "xian zg", mode: .fts, tokenizer: .pinyin)
        XCTAssertEqual(filter.pattern, "(\"xian\"* OR \"xi an\"* OR \"xia n\"*) AND \"z g\"*")
    }

    func testMatchExpressionIsEmptyWhenAnyPieceIsNotPinyin() {
        XCTAssertEqual(ClipFilter(query: "zhong 2024", mode: .fts, tokenizer: .pinyin).pattern, "")
    }

    func testVerbatimExpressionUnchanged() {
        XCTAssertEqual(ClipFilter(query: "hel wor", mode: .fts).pattern, "\"hel\"* \"wor\"*")
    }
}
