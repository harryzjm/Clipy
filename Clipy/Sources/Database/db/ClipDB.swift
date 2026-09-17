//
//  ClipDB.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation
import WCDBSwift

/// Records what a transaction changed, so `beforeCommit` can turn it into a change signal.
///
/// `clip_fts` is deliberately absent: it is an index over `clip`, not observable data, so a
/// change to it is never a change anyone subscribes to.
final class ClipStatus {

    enum DeleteTarget {
        case hashes(Set<String>)
        case olderThan(Int)
        case all
    }

    var inserted: [CPYClipTable] = []
    var deleted: [DeleteTarget] = []

    var isEmpty: Bool {
        inserted.isEmpty && deleted.isEmpty
    }

    func clean() {
        inserted.removeAll()
        deleted.removeAll()
    }
}

/// One filtered read off the storage layer. `matchedTerms` is keyed by `data_hash` and only
/// `.fts` fills it — see `ClipSearchResult`, the caller-facing counterpart.
typealias ClipTableSearchResult = (clips: [CPYClipTable], matchedTerms: [String: [String]])

/// Clipboard history store (`clip.db`).
final class ClipDB: DataStore {

    let status = ClipStatus()

    /// STX / ETX wrap each span fts5 reports, so `highlight()`'s output can be cut back apart
    /// into the strings that were hit. Control characters: they do not occur in clipboard text,
    /// so they cannot be mistaken for content.
    fileprivate static let markOpen = "\u{2}"
    fileprivate static let markClose = "\u{3}"

    /// The tokenizer is registered globally inside WCDB, but still has to be attached to this
    /// database's handle — without it both creating and querying `clip_fts` fail with an unknown
    /// tokenizer. Runs before `migrationList()`, which is what migration 1 needs.
    override func configCustomDatabase(_ db: Database) throws {
        db.add(tokenizer: BuiltinTokenizer.Verbatim)
        db.setAutoMergeFTS5Index(enable: true)
    }

    override func migrationList() -> [Migration] {
        [
            .init(version: 1) { db in
                try db.create(table: CPYClipTable.tableName, of: CPYClipTable.self)
                try db.create(virtualTable: CPYClipFtsTable.tableName, of: CPYClipFtsTable.self)
                try ClipDB.createFtsTriggers(on: db)
            }
        ]
    }
}

// MARK: - FTS index
/// `clip_fts` is kept in step with `clip` by SQL triggers rather than by Swift.
///
/// The deciding case is expiry: `DataCleanService.cleanDatas()` deletes by predicate
/// (`deleteClips(olderThan:)`), so the Swift side never sees the keys of the rows it dropped.
/// Enforcing the mirror in the database instead means no delete path can bypass it.
///
/// Every statement below keys on rowid, holding `clip_fts.rowid == clip.rowid`. That is the
/// whole point: rowid equality is the one constraint fts5 can plan for — a seek into its
/// `%_content` table — while equality on any other column, `UNINDEXED` or not, degrades to a
/// full scan of the shadow table and turns a bulk insert or expiry sweep into O(n²).
private extension ClipDB {

    /// A `new.`/`old.` column reference. `Column.in(table:)` emits exactly `row.name` — no
    /// schema, no quoting — which is the form a trigger body needs.
    static func clipColumn(_ name: String, of row: String) -> Column {
        Column(named: name).in(table: row)
    }

    /// `DELETE FROM clip_fts WHERE rowid = <row>.rowid`
    static func purgeFts(rowOf row: String) -> StatementDelete {
        StatementDelete()
            .delete(from: CPYClipFtsTable.tableName)
            .where(Column.rowid() == clipColumn("rowid", of: row))
    }

    /// `DELETE FROM clip_fts WHERE rowid = (SELECT rowid FROM clip WHERE data_hash = new.data_hash)`
    ///
    /// The subquery resolves through `clip`'s `data_hash` primary key, translating the hash the
    /// caller has into the rowid fts5 can seek on. It has to run BEFORE the insert, while the row
    /// `INSERT OR REPLACE` is about to drop still exists — and it cannot shortcut through
    /// `new.rowid`, which SQLite hardcodes to -1 inside a BEFORE trigger on an implicit-rowid
    /// table.
    static func purgeFtsConflicting() -> StatementDelete {
        let conflicting = StatementSelect()
            .select(Column.rowid())
            .from(CPYClipTable.tableName)
            .where(CPYClipTable.Properties.dataHash == clipColumn("data_hash", of: "new"))
        return StatementDelete()
            .delete(from: CPYClipFtsTable.tableName)
            .where(Column.rowid() == WCDBSwift.Expression(with: conflicting))
    }

    /// `INSERT INTO clip_fts(rowid, title, data_hash) VALUES(new.rowid, new.title, new.data_hash)`
    static func indexFts() -> StatementInsert {
        StatementInsert()
            .insert(intoTable: CPYClipFtsTable.tableName)
            .columns(Column.rowid(),
                     CPYClipFtsTable.Properties.title,
                     CPYClipFtsTable.Properties.dataHash)
            .values(clipColumn("rowid", of: "new"),
                    clipColumn("title", of: "new"),
                    clipColumn("data_hash", of: "new"))
    }

    static func createFtsTriggers(on db: Database) throws {
        // `INSERT OR REPLACE` drops the conflicting row without firing AFTER DELETE — SQLite only
        // does that with `recursive_triggers` on, and it is off. So re-copying the same content
        // would strand the old FTS row. Clearing it here, ahead of the replace, is what keeps the
        // mirror exact.
        try db.exec(StatementCreateTrigger()
            .create(trigger: "clip_fts_bi").ifNotExists()
            .before().insert().on(table: CPYClipTable.tableName).forEachRow()
            .execute(purgeFtsConflicting()))

        try db.exec(StatementCreateTrigger()
            .create(trigger: "clip_fts_ai").ifNotExists()
            .after().insert().on(table: CPYClipTable.tableName).forEachRow()
            .execute(indexFts()))

        // Every delete goes through here: one clip, the whole history, and the expiry sweep.
        try db.exec(StatementCreateTrigger()
            .create(trigger: "clip_fts_ad").ifNotExists()
            .after().delete().on(table: CPYClipTable.tableName).forEachRow()
            .execute(purgeFts(rowOf: "old")))

        // Nothing updates `clip` today — inserts are upserts. This is here so the index stays
        // honest if anything ever does.
        try db.exec(StatementCreateTrigger()
            .create(trigger: "clip_fts_au").ifNotExists()
            .after().update().on(table: CPYClipTable.tableName).forEachRow()
            .execute(purgeFts(rowOf: "old"))
            .execute(indexFts()))
    }
}

// MARK: - FTS repair
extension ClipDB {
    /// Realigns the whole FTS mirror with `clip.rowid`.
    ///
    /// Anything that renumbers `clip`'s rowids has to be followed by this, or every later FTS
    /// delete silently targets the wrong row. `VACUUM` is the one such operation that exists
    /// today: `clip`'s primary key is TEXT, so the table has no INTEGER PRIMARY KEY for VACUUM to
    /// preserve and it renumbers freely. `ClipServiceTransaction.vacuum()` pairs the two.
    ///
    /// Deliberately not fts5's own `'rebuild'` command — that re-tokenizes from `%_content` and
    /// leaves the rowids exactly as they were, which is the thing being repaired.
    ///
    /// The caller owns the transaction: a failure partway through leaves the index empty.
    func rebuildFtsIndex() throws {
        try db.delete(fromTable: CPYClipFtsTable.tableName)
        try db.exec(StatementInsert()
            .insert(intoTable: CPYClipFtsTable.tableName)
            .columns(Column.rowid(),
                     CPYClipFtsTable.Properties.title,
                     CPYClipFtsTable.Properties.dataHash)
            .values(StatementSelect()
                .select(Column.rowid(),
                        CPYClipTable.Properties.title,
                        CPYClipTable.Properties.dataHash)
                .from(CPYClipTable.tableName)))
    }
}

// MARK: - Write
extension ClipDB {
    /// Upsert. A repeated copy hits the same `data_hash` primary key and refreshes `update_time`,
    /// which is what moves the clip back to the top of the history menu.
    ///
    /// Must stay `INSERT OR REPLACE`. `insertOrIgnore` would break the FTS mirror: the BEFORE
    /// INSERT trigger runs ahead of the conflict check and `OR IGNORE` does not roll its effect
    /// back, so the index row would be dropped while the clip row lived on.
    func insertClip(_ clip: CPYClipTable) throws {
        try db.insertOrReplace(clip, intoTable: CPYClipTable.tableName)
        status.inserted.append(clip)
    }

    func deleteClip(dataHash: String) throws {
        try db.delete(fromTable: CPYClipTable.tableName,
                      where: CPYClipTable.Properties.dataHash == dataHash)
        status.deleted.append(.hashes([dataHash]))
    }

    func deleteClips(olderThan updateTime: Int) throws {
        try db.delete(fromTable: CPYClipTable.tableName,
                      where: CPYClipTable.Properties.updateTime < updateTime)
        status.deleted.append(.olderThan(updateTime))
    }

    func deleteAllClips() throws {
        try db.delete(fromTable: CPYClipTable.tableName)
        status.deleted.append(.all)
    }
}

// MARK: - Read
extension ClipDB {
    func fetchClip(dataHash: String) throws -> CPYClipTable? {
        try db.getObject(fromTable: CPYClipTable.tableName,
                         where: CPYClipTable.Properties.dataHash == dataHash)
    }

    func fetchClips(ascending: Bool, limit: Int?) throws -> [CPYClipTable] {
        let order = [CPYClipTable.Properties.updateTime.order(ascending ? .ascending : .descending)]
        if let limit = limit {
            return try db.getObjects(fromTable: CPYClipTable.tableName, orderBy: order, limit: limit)
        }
        return try db.getObjects(fromTable: CPYClipTable.tableName, orderBy: order)
    }

    /// The only entry point for filtered history reads.
    ///
    /// Always takes the newest `limit` rows. `.like`/`.glob` order by `update_time`; `.fts`
    /// orders by rowid, which tracks the same recency — see `fetchFtsClips`. Either way the
    /// point of the `ORDER BY` is to decide *which* rows survive the `LIMIT`, not how they are
    /// displayed: ordering by anything else would make `LIMIT` pick the oldest N rows.
    ///
    /// Case sensitivity is SQLite's own: `LIKE` folds ASCII case, `GLOB` does not, and fts5
    /// folds it in the tokenizer.
    func fetchClips(filter: ClipFilter?, limit: Int) throws -> ClipTableSearchResult {
        guard let filter else {
            return (clips: try fetchClips(ascending: false, limit: limit), matchedTerms: [:])
        }

        let title = CPYClipTable.Properties.title
        switch filter.mode {
        case .like:
            return (clips: try fetchClips(matching: title.like(filter.pattern), limit: limit),
                    matchedTerms: [:])
        case .glob:
            return (clips: try fetchClips(matching: title.glob(filter.pattern), limit: limit),
                    matchedTerms: [:])
        case .fts:
            return try fetchFtsClips(matching: filter.pattern, limit: limit)
        }
    }

    func clipCount() throws -> Int {
        try db.getValue(on: CPYClipTable.Properties.dataHash.count(),
                        fromTable: CPYClipTable.tableName).intValue
    }

    /// Non-empty thumbnail cache keys, optionally restricted to clips older than `updateTime`.
    func fetchThumbnailPaths(olderThan updateTime: Int? = nil) throws -> [String] {
        var condition = CPYClipTable.Properties.thumbnailPath != ""
        if let updateTime = updateTime {
            condition = condition && CPYClipTable.Properties.updateTime < updateTime
        }
        return try db.getColumn(on: CPYClipTable.Properties.thumbnailPath,
                                fromTable: CPYClipTable.tableName,
                                where: condition).map { $0.stringValue }
    }

    func fetchAllDataPaths() throws -> [String] {
        try db.getColumn(on: CPYClipTable.Properties.dataPath,
                         fromTable: CPYClipTable.tableName).map { $0.stringValue }
    }

    #if DEBUG
    /// Rows in the FTS shadow table. Only exists so the triggers' work can be asserted against
    /// `clipCount()` while developing.
    func ftsCount() throws -> Int {
        try db.getValue(on: CPYClipFtsTable.Properties.dataHash.count(),
                        fromTable: CPYClipFtsTable.tableName).intValue
    }
    #endif
}

// MARK: - Filtered read
private extension ClipDB {
    /// `WCDBSwift.Expression` spelled out: unqualified, it collides with Foundation's.
    func fetchClips(matching condition: WCDBSwift.Expression, limit: Int) throws -> [CPYClipTable] {
        try db.getObjects(fromTable: CPYClipTable.tableName,
                          where: condition,
                          orderBy: [CPYClipTable.Properties.updateTime.order(.descending)],
                          limit: limit)
    }

    /// Two queries, because `highlight()` is an fts5 auxiliary function and only works inside a
    /// query against the FTS table itself.
    ///
    /// The first query orders by rowid, which fts5 plans itself (it reports the ordering as
    /// consumed), so `LIMIT` stops the scan early instead of materialising and sorting every hit.
    /// That stands on rowid tracking recency: `insertClip` uses `INSERT OR REPLACE`, so every
    /// write — including a repeated copy moving back to the top — takes `max(rowid) + 1`.
    /// Ordering by `update_time` instead would sort the whole match set, because an fts5 table
    /// cannot index that column. The second query then orders by `update_time` off `clip`'s own
    /// index, which agrees with the rowid ordering the hits were limited by.
    ///
    /// The second query carries no `LIMIT` and needs none: `matchedTerms` is built from the
    /// first query's rows, so it holds at most `limit` entries.
    func fetchFtsClips(matching matchExpression: String, limit: Int) throws -> ClipTableSearchResult {
        // fts5 rejects `MATCH ''` as a syntax error, and a query of nothing but whitespace
        // reduces to exactly that.
        guard !matchExpression.isEmpty else { return (clips: [], matchedTerms: [:]) }

        let highlighted = Column(named: CPYClipFtsTable.tableName)
            .highlight()
            .arguments(CPYClipFtsTable.titleColumnIndex, Self.markOpen, Self.markClose)

        let hits = try db.getRows(on: [CPYClipFtsTable.Properties.dataHash, highlighted],
                                  fromTable: CPYClipFtsTable.tableName,
                                  where: CPYClipFtsTable.Properties.title.match(matchExpression),
                                  orderBy: [Column.rowid().order(.descending)],
                                  limit: limit)

        var matchedTerms: [String: [String]] = [:]
        for row in hits where row.count >= 2 {
            let hash = row[0].stringValue
            guard !hash.isEmpty else { continue }
            matchedTerms[hash] = Self.markedTerms(in: row[1].stringValue)
        }
        // `IN ()` is a syntax error, so an empty hit set has to stop here.
        guard !matchedTerms.isEmpty else { return (clips: [], matchedTerms: [:]) }

        let clips: [CPYClipTable] = try db.getObjects(
            fromTable: CPYClipTable.tableName,
            where: CPYClipTable.Properties.dataHash.in(matchedTerms.keys.map { WCDBSwift.Expression(with: $0) }),
            orderBy: [CPYClipTable.Properties.updateTime.order(.descending)])
        return (clips: clips, matchedTerms: matchedTerms)
    }

    /// The spans `highlight()` wrapped in the sentinels, de-duplicated and in the order they
    /// appear.
    static func markedTerms(in highlighted: String) -> [String] {
        var terms: [String] = []
        var rest = Substring(highlighted)

        while let open = rest.range(of: markOpen),
              let close = rest[open.upperBound...].range(of: markClose) {
            let term = String(rest[open.upperBound ..< close.lowerBound])
            if !term.isEmpty && !terms.contains(term) {
                terms.append(term)
            }
            rest = rest[close.upperBound...]
        }
        return terms
    }
}
