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
