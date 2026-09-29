//
//  PinyinSearchTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import XCTest
@testable import Clipy

/// Search end to end against a real database: the bundled dictionary, `ClipyTokenizer`, and the
/// query `ClipFilter` builds from `PinyinQuery`.
final class PinyinSearchTests: ClipDBTestCase {

    // MARK: - Index

    /// VACUUM's repair refills the existing table, so it must keep the tokenizer — and a delete
    /// afterwards must still hit the right row.
    func testVacuumKeepsIndex() throws {
        try insertClip(hash: "a", title: "北京", updateTime: 1)
        try insertClip(hash: "b", title: "上海", updateTime: 2)

        try perform("vacuum", ignoreTransaction: true) { try $0.vacuum() }

        XCTAssertEqual(try search("beijing"), ["a"])

        try perform("delete") { try $0.deleteClip(dataHash: "a") }
        XCTAssertEqual(try search("beijing"), [])
        XCTAssertEqual(try search("shanghai"), ["b"])
    }

    /// The tokenizer is named in the table's schema, so a reopened database still finds it.
    func testReopenedDatabaseStillSearches() throws {
        try insertClip(hash: "a", title: "中国 Complete", updateTime: 1)

        let reopened = ClipyBox(path: rootPath, secretCode: secretCode)
        for query in ["zg", "com"] {
            let filter = ClipFilter(query: query, mode: .fts)
            let hits = try perform("search \(query)", on: reopened) { try $0.fetchClips(filter: filter, limit: 10) }
            XCTAssertEqual(hits.clips.map { $0.dataHash }, ["a"], query)
        }
    }

    // MARK: - Dictionary

    /// Each reading is followed by its initial, repeats dropped; comment lines and lines without
    /// a reading are skipped.
    func testDictionaryParsesReadingsAndInitials() {
        let parsed = PinyinDictionary.parse("# header\n重 zhong chong\n中\n")
        XCTAssertEqual(parsed, ["重": ["zhong", "chong"]])

        let tokens = PinyinDictionary.tokens(for: ["xing", "hang", "heng"])
        XCTAssertEqual(tokens.map { String(decoding: $0, as: UTF8.self) }, ["xing", "x", "hang", "h", "heng"])
    }

    func testBundledDictionaryLoads() {
        XCTAssertGreaterThan(PinyinDictionary.readings.count, 20_000)
    }

    // MARK: - Pinyin

    func testFullInitialsMixedAndPrefix() throws {
        try insertClip(hash: "bank", title: "中国银行 2024", updateTime: 1)

        for query in ["zhongguoyinhang", "zgyh", "zhongg", "zguo", "zhong guo", "yinh", "ZhongGuo", "ZGYH"] {
            XCTAssertEqual(try search(query), ["bank"], query)
        }
    }

    /// The point of keeping every reading: a polyphone matches under each of them.
    func testPolyphonesMatchEveryReading() throws {
        try insertClip(hash: "cq", title: "重庆", updateTime: 1)
        try insertClip(hash: "zy", title: "重要", updateTime: 2)
        try insertClip(hash: "yh", title: "银行", updateTime: 3)

        XCTAssertEqual(try search("chongqing"), ["cq"])
        XCTAssertEqual(try search("zhongyao"), ["zy"])
        XCTAssertEqual(try search("yinhang"), ["yh"])
        XCTAssertEqual(try search("yinxing"), ["yh"])
        XCTAssertEqual(Set(try search("zhong")), ["cq", "zy"])
    }

    func testTraditionalCharacters() throws {
        try insertClip(hash: "a", title: "銀行", updateTime: 1)

        XCTAssertEqual(try search("yinhang"), ["a"])
    }

    /// Syllables of one phrase must land on consecutive characters.
    func testPhraseRequiresAdjacentCharacters() throws {
        try insertClip(hash: "a", title: "中华人民共和国", updateTime: 1)

        XCTAssertEqual(try search("zhonghua"), ["a"])
        XCTAssertEqual(try search("zhongguo"), [])
    }

    /// `highlight()` reports the source characters, which is what the menu marks.
    func testMatchedTermsAreTheChineseSpan() throws {
        try insertClip(hash: "a", title: "去重庆吃火锅", updateTime: 1)

        let filter = ClipFilter(query: "chongqing", mode: .fts)
        let result = try perform("search") { try $0.fetchClips(filter: filter, limit: 10) }
        let terms = try XCTUnwrap(result.matchedTerms["a"])
        XCTAssertEqual(terms.joined(), "重庆")

        let title = "去重庆吃火锅"
        let ranges = filter.marking(terms).highlightRanges(in: title)
        XCTAssertEqual(ranges.map { String(title[$0]) }, ["重庆"])
    }

    // MARK: - As written

    /// Words, digits and the characters themselves are indexed alongside the readings.
    func testLiteralTextMatches() throws {
        try insertClip(hash: "a", title: "hello 中国 2024", updateTime: 1)

        XCTAssertEqual(try search("hello"), ["a"])
        XCTAssertEqual(try search("2024"), ["a"])
        XCTAssertEqual(try search("中国"), ["a"])
        XCTAssertEqual(try search("中"), ["a"])
    }

    /// Words match by prefix, in any case, and only by prefix.
    func testWordsMatchByPrefixIgnoringCase() throws {
        try insertClip(hash: "a", title: "Complete", updateTime: 1)
        try insertClip(hash: "b", title: "word", updateTime: 2)

        XCTAssertEqual(try search("com"), ["a"])
        XCTAssertEqual(try search("COM"), ["a"])
        XCTAssertEqual(try search("complete"), ["a"])
        XCTAssertEqual(try search("wo"), ["b"])
        XCTAssertEqual(try search("o"), [])
    }

    /// A word and pinyin in separate pieces are ANDed; run together they are one piece that
    /// reads neither way.
    func testWordAndPinyinNeedSeparatePieces() throws {
        try insertClip(hash: "a", title: "Complete中国", updateTime: 1)

        XCTAssertEqual(try search("com zg"), ["a"])
        XCTAssertEqual(try search("Complete中"), ["a"])
        XCTAssertEqual(try search("Completez"), [])
    }

    /// A word hit is marked on the whole word, found again case-insensitively in the title.
    func testMatchedTermsAreTheWord() throws {
        try insertClip(hash: "a", title: "Complete 中国", updateTime: 1)

        let filter = ClipFilter(query: "com", mode: .fts)
        let result = try perform("search") { try $0.fetchClips(filter: filter, limit: 10) }
        let terms = try XCTUnwrap(result.matchedTerms["a"])
        XCTAssertEqual(terms, ["Complete"])

        let title = "Complete 中国"
        let ranges = filter.marking(terms).highlightRanges(in: title)
        XCTAssertEqual(ranges.map { String(title[$0]) }, ["Complete"])
    }
}

// MARK: - Helpers
private extension PinyinSearchTests {

    func insertClip(hash: String, title: String, updateTime: Int) throws {
        let clip = CPYClip()
        clip.dataHash = hash
        clip.title = title
        clip.primaryType = "public.utf8-plain-text"
        clip.updateTime = updateTime
        clip.clipType = .text

        try perform("insert \(hash)") { try $0.insertClip(clip) }
    }

    func search(_ query: String) throws -> [String] {
        let filter = ClipFilter(query: query, mode: .fts)
        let result = try perform("search \(query)") {
            try $0.fetchClips(filter: filter, limit: 200)
        }
        return result.clips.map { $0.dataHash }
    }
}
