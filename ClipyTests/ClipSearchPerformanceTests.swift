//
//  ClipSearchPerformanceTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import XCTest
@testable import Clipy

/// Seeds `clip.db` with 100,000 synthetic English clips and times
/// `ClipDB.fetchClips(filter:limit:)` once per `FilterMatchMode`, so a regression in the
/// unindexed `.like` / `.glob` scans or in the `clip_fts` index shows up as a slow test rather
/// than silently in the shipped history menu.
///
/// The seeding half is a regression test in its own right: while the FTS triggers cleared the
/// index by `data_hash` — a column fts5 cannot seek on — every insert rescanned the whole shadow
/// table and this could not finish inside its timeout.
final class ClipSearchPerformanceTests: ClipDBTestCase {

    private static let clipCount = 100_000
    /// Salted into a fraction of the generated titles (never part of the word bank itself), so
    /// every mode has a known, non-trivial number of hits to search for.
    private static let needle = "clipboard"

    func testSeedClips() throws {
        let seedElapsed = try seedClips(count: Self.clipCount)
        print("[ClipSearchPerformanceTests] inserted \(Self.clipCount) clips in \(Self.milliseconds(seedElapsed))")
    }

    func testSearchPerformanceAcrossModes() throws {
        let seedElapsed = try seedClips(count: Self.clipCount)
        print("[ClipSearchPerformanceTests] inserted \(Self.clipCount) clips in \(Self.milliseconds(seedElapsed))")

        for mode in FilterMatchMode.allCases {
            let filter = ClipFilter(query: Self.needle, mode: mode)
            let (elapsed, hitCount) = try timeSearch(filter: filter)

            print("[ClipSearchPerformanceTests] \(mode.title) search over \(Self.clipCount) clips: " +
                  "\(Self.milliseconds(elapsed)), \(hitCount) hits")

            XCTAssertGreaterThan(hitCount, 0, "\(mode.title) search found no hits to time against")
            // Generous on purpose: this catches a real regression (e.g. a dropped index or an
            // accidental O(n²) scan), not day-to-day machine noise.
            XCTAssertLessThan(elapsed, 5, "\(mode.title) search took longer than 5s over \(Self.clipCount) clips")
        }
    }

    /// Short prefixes against 100,000 short mixed clips — the shape `prefix='1 2'` is sized for.
    /// One- and two-letter queries read a prefix index and stop at the limit; three and four
    /// letters merge every matching term first. `com` and `htt` are the worst case for that
    /// merge: URL fragments put them in a large share of rows.
    ///
    /// The printed timings are what decides between `'1 2'` and `'1 2 3'`; the assertion only
    /// catches a gross regression.
    func testShortPrefixSearchOverMixedClips() throws {
        let clips = (0..<Self.clipCount).map { Self.mixedClip(index: $0) }
        try perform("seed mixed clips", timeout: 120) { transaction in
            for clip in clips {
                try transaction.insertClip(clip)
            }
        }
        print("[ClipSearchPerformanceTests] clip.db for \(Self.clipCount) mixed clips: \(databaseSize())")

        for query in ["c", "co", "com", "exam", "h", "ht", "htt", "http", "z", "zg", "zgy", "zgyh", "中", "2"] {
            let (elapsed, hitCount) = try timeSearch(filter: ClipFilter(query: query, mode: .fts))
            print("[ClipSearchPerformanceTests] fts \"\(query)\" over \(Self.clipCount) mixed clips: " +
                  "\(Self.milliseconds(elapsed)), \(hitCount) hits")
            XCTAssertGreaterThan(hitCount, 0, "\"\(query)\" found no hits to time against")
            XCTAssertLessThan(elapsed, 1, "\"\(query)\" took longer than 1s over \(Self.clipCount) clips")
        }
    }
}

// MARK: - Seeding
private extension ClipSearchPerformanceTests {
    /// Inserts `count` random clips in a single transaction and returns how long that took.
    func seedClips(count: Int) throws -> TimeInterval {
        let clips = (0..<count).map { Self.randomClip(index: $0) }
        var elapsed: TimeInterval = 0

        try perform("seed clips") { transaction in
            let start = CFAbsoluteTimeGetCurrent()
            for clip in clips {
                try transaction.insertClip(clip)
            }
            elapsed = CFAbsoluteTimeGetCurrent() - start
        }
        return elapsed
    }

    static func randomClip(index: Int) -> CPYClip {
        let clip = CPYClip()
        clip.dataHash = UUID().uuidString
        clip.dataPath = "\(index).data"
        clip.title = randomTitle()
        clip.primaryType = "public.utf8-plain-text"
        clip.updateTime = index
        clip.clipType = .text
        return clip
    }

    /// A short run of random English words, long enough to look like real clipboard text.
    /// About 15% of titles get `needle` inserted at a random position, which is enough hits to
    /// time a search against without making every row match.
    static func randomTitle() -> String {
        let wordCount = Int.random(in: 4...12)
        var words = (0..<wordCount).map { _ in wordBank.randomElement()! }
        if Double.random(in: 0..<1) < 0.15 {
            words.insert(needle, at: Int.random(in: 0...words.count))
        }
        return words.joined(separator: " ")
    }

    static let wordBank = [
        "the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog", "history", "search",
        "filter", "menu", "status", "item", "paste", "copy", "text", "snippet", "folder", "window",
        "keyboard", "shortcut", "preference", "setting", "storage", "database", "index", "query",
        "result", "match", "highlight", "token", "phrase", "sentence", "document", "report",
        "project", "feature", "release", "version", "update", "commit", "branch", "review", "code",
        "swift", "macos", "application", "service", "manager", "signal", "observer", "stream",
        "queue", "thread", "cache", "file", "path", "table", "column", "value", "field", "record"
    ]
}

// MARK: - Mixed seeding
private extension ClipSearchPerformanceTests {

    static func mixedClip(index: Int) -> CPYClip {
        let clip = randomClip(index: index)
        clip.title = mixedTitle()
        return clip
    }

    /// Fragments drawn until the next would pass 15 characters: English words, Chinese words,
    /// URL pieces and numbers, roughly in the proportions a clipboard sees them.
    static func mixedTitle() -> String {
        var title = ""
        while true {
            let fragment: String
            switch Int.random(in: 0..<10) {
            case 0...3: fragment = chineseBank.randomElement()!
            case 4...6: fragment = wordBank.randomElement()!
            case 7...8: fragment = urlBank.randomElement()!
            default: fragment = String(Int.random(in: 0...99_999))
            }
            let next = title.isEmpty ? fragment : "\(title) \(fragment)"
            guard next.count <= 15 else { return title.isEmpty ? String(fragment.prefix(15)) : title }
            title = next
        }
    }

    static let chineseBank = [
        "中国", "银行", "北京", "上海", "重庆", "剪贴板", "历史", "搜索", "设置", "文件", "项目",
        "会议", "时间", "地址", "电话", "密码", "报告", "今天", "明天", "工作", "发布", "版本",
        "代码", "测试", "数据", "网络", "服务", "用户", "消息", "图片"
    ]

    static let urlBank = [
        "https://github.com", "http://example.com", "www.apple.com", "google.com", "api.test.com",
        "https://t.co", "localhost:8080", "cdn.net/a.js"
    ]

    /// `clip.db` plus its WAL and shared-memory files.
    func databaseSize() -> String {
        let manager = FileManager.default
        let bytes = ["clip.db", "clip.db-wal", "clip.db-shm"]
            .compactMap { try? manager.attributesOfItem(atPath: (rootPath as NSString).appendingPathComponent($0)) }
            .compactMap { $0[.size] as? Int }
            .reduce(0, +)
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

// MARK: - Timing
private extension ClipSearchPerformanceTests {
    /// Runs one filtered fetch and returns how long the query itself took (excluding the
    /// dispatch hop onto the clip queue) alongside how many rows it found.
    func timeSearch(filter: ClipFilter) throws -> (elapsed: TimeInterval, hitCount: Int) {
        var elapsed: TimeInterval = 0
        var hitCount = 0

        try perform("\(filter.mode.title) search") { transaction in
            let start = CFAbsoluteTimeGetCurrent()
            let result = try transaction.fetchClips(filter: filter, limit: 200)
            elapsed = CFAbsoluteTimeGetCurrent() - start
            hitCount = result.clips.count
        }
        return (elapsed, hitCount)
    }

    static func milliseconds(_ interval: TimeInterval) -> String {
        String(format: "%.2fms", interval * 1000)
    }
}
