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

/// Covers switching `clip_fts` between tokenizers, and pinyin search end to end against a real
/// database: the bundled dictionary, WCDB's tokenizer, and the query `PinyinQuery` builds.
final class PinyinSearchTests: ClipDBTestCase {

    // MARK: - Switching

    func testFreshDatabaseIsVerbatim() throws {
        XCTAssertEqual(try perform("tokenizer") { try $0.ftsTokenizer() }, .verbatim)
    }

    /// The switch takes the whole history with it, payload rows included, and leaves an index the
    /// triggers still feed.
    func testSwitchClearsHistoryAndRebuildsIndex() throws {
        try insertClip(hash: "a", title: "alpha", updateTime: 1, content: Data("alpha".utf8))
        try insertClip(hash: "b", title: "中国", updateTime: 2)

        try switchTokenizer(to: .pinyin)

        XCTAssertEqual(try perform("tokenizer") { try $0.ftsTokenizer() }, .pinyin)
        try assertCountsAgree(expecting: 0)
        XCTAssertEqual(try perform("content") { try $0.clipDb.contentCount() }, 0)

        try insertClip(hash: "c", title: "中国", updateTime: 3)
        try assertCountsAgree(expecting: 1)
        XCTAssertEqual(try search("zhongguo"), ["c"])
    }

    func testSwitchingBackRestoresWordSearch() throws {
        try switchTokenizer(to: .pinyin)
        try switchTokenizer(to: .verbatim)

        XCTAssertEqual(try perform("tokenizer") { try $0.ftsTokenizer() }, .verbatim)
        try insertClip(hash: "a", title: "hello world", updateTime: 1)
        XCTAssertEqual(try search("hel", tokenizer: .verbatim), ["a"])
    }

    /// VACUUM's repair refills the existing table, so it must keep the tokenizer — and a delete
    /// afterwards must still hit the right row.
    func testVacuumKeepsPinyinIndex() throws {
        try switchTokenizer(to: .pinyin)
        try insertClip(hash: "a", title: "北京", updateTime: 1)
        try insertClip(hash: "b", title: "上海", updateTime: 2)

        try perform("vacuum", ignoreTransaction: true) { try $0.vacuum() }

        XCTAssertEqual(try perform("tokenizer") { try $0.ftsTokenizer() }, .pinyin)
        XCTAssertEqual(try search("beijing"), ["a"])

        try perform("delete") { try $0.deleteClip(dataHash: "a") }
        XCTAssertEqual(try search("beijing"), [])
        XCTAssertEqual(try search("shanghai"), ["b"])
    }

    /// The tokenizer is read off the schema, so a reopened database still knows it is Pinyin.
    func testReopenedDatabaseKeepsPinyin() throws {
        try switchTokenizer(to: .pinyin)
        try insertClip(hash: "a", title: "中国", updateTime: 1)

        let reopened = ClipyBox(path: rootPath, secretCode: secretCode)
        XCTAssertEqual(try perform("tokenizer", on: reopened) { try $0.ftsTokenizer() }, .pinyin)
        let filter = ClipFilter(query: "zg", mode: .fts, tokenizer: .pinyin)
        let hits = try perform("search", on: reopened) { try $0.fetchClips(filter: filter, limit: 10) }
        XCTAssertEqual(hits.clips.map { $0.dataHash }, ["a"])
    }

    // MARK: - Matching

    func testFullInitialsMixedAndPrefix() throws {
        try switchTokenizer(to: .pinyin)
        try insertClip(hash: "bank", title: "中国银行 2024", updateTime: 1)

        for query in ["zhongguoyinhang", "zgyh", "zhongg", "zguo", "zhong guo", "yinh", "ZhongGuo"] {
            XCTAssertEqual(try search(query), ["bank"], query)
        }
    }

    /// The point of keeping every reading: a polyphone matches under each of them.
    func testPolyphonesMatchEveryReading() throws {
        try switchTokenizer(to: .pinyin)
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
        try switchTokenizer(to: .pinyin)
        try insertClip(hash: "a", title: "銀行", updateTime: 1)

        XCTAssertEqual(try search("yinhang"), ["a"])
    }

    /// Syllables of one phrase must land on consecutive characters.
    func testPhraseRequiresAdjacentCharacters() throws {
        try switchTokenizer(to: .pinyin)
        try insertClip(hash: "a", title: "中华人民共和国", updateTime: 1)

        XCTAssertEqual(try search("zhonghua"), ["a"])
        XCTAssertEqual(try search("zhongguo"), [])
    }

    /// The Pinyin index holds Chinese characters only.
    func testNonPinyinQueriesMatchNothing() throws {
        try switchTokenizer(to: .pinyin)
        try insertClip(hash: "a", title: "hello 中国 2024", updateTime: 1)

        XCTAssertEqual(try search("hello"), [])
        XCTAssertEqual(try search("2024"), [])
        XCTAssertEqual(try search("中国"), [])
    }

    /// `highlight()` reports the source characters, which is what the menu marks.
    func testMatchedTermsAreTheChineseSpan() throws {
        try switchTokenizer(to: .pinyin)
        try insertClip(hash: "a", title: "去重庆吃火锅", updateTime: 1)

        let filter = ClipFilter(query: "chongqing", mode: .fts, tokenizer: .pinyin)
        let result = try perform("search") { try $0.fetchClips(filter: filter, limit: 10) }
        let terms = try XCTUnwrap(result.matchedTerms["a"])
        XCTAssertEqual(terms.joined(), "重庆")

        let title = "去重庆吃火锅"
        let ranges = filter.marking(terms).highlightRanges(in: title)
        XCTAssertEqual(ranges.map { String(title[$0]) }, ["重庆"])
    }
}

// MARK: - Helpers
private extension PinyinSearchTests {

    func switchTokenizer(to tokenizer: ClipFtsTokenizer) throws {
        try perform("switch to \(tokenizer)") { try $0.switchFtsTokenizer(to: tokenizer) }
    }

    func insertClip(hash: String, title: String, updateTime: Int, content: Data? = nil) throws {
        let clip = CPYClip()
        clip.dataHash = hash
        clip.title = title
        clip.primaryType = "public.utf8-plain-text"
        clip.updateTime = updateTime
        clip.clipType = .text
        clip.content = content

        try perform("insert \(hash)") { try $0.insertClip(clip) }
    }

    func search(_ query: String, tokenizer: ClipFtsTokenizer = .pinyin) throws -> [String] {
        let filter = ClipFilter(query: query, mode: .fts, tokenizer: tokenizer)
        let result = try perform("search \(query)") {
            try $0.fetchClips(filter: filter, limit: 200)
        }
        return result.clips.map { $0.dataHash }
    }

    func assertCountsAgree(expecting expected: Int,
                           file: StaticString = #filePath,
                           line: UInt = #line) throws {
        let counts = try perform("counts") {
            (clip: try $0.clipCount(), fts: try $0.clipDb.ftsCount())
        }
        XCTAssertEqual(counts.clip, expected, "clip row count", file: file, line: line)
        XCTAssertEqual(counts.fts, expected, "clip_fts row count", file: file, line: line)
    }
}
