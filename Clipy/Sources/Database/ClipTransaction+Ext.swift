//
//  ClipTransaction+Ext.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation

// MARK: - Clip
extension ClipServiceTransaction {

    func insertClip(_ clip: CPYClip) throws {
        try clipDb.insertClip(clip.toTable)
        // The payload is not a column on `clip`; it rides in the side table, or in a file when it
        // was too big to inline. A freshly captured clip carries `content` either way — `dataPath`
        // is what decides between them — and passing nil here clears any stale inline row for the
        // same hash, which would otherwise be preferred over the file on read.
        try clipDb.setContent(clip.dataPath.isEmpty ? clip.content : nil, forDataHash: clip.dataHash)
    }

    /// The one read that carries the payload, because it is the one the paste path uses. The list
    /// reads below deliberately leave `content` nil.
    func fetchClip(dataHash: String) throws -> CPYClip? {
        guard let clip = try clipDb.fetchClip(dataHash: dataHash)?.toClip else { return nil }
        clip.content = try clipDb.fetchContent(dataHash: dataHash)
        return clip
    }

    func fetchClips(ascending: Bool, limit: Int? = nil) throws -> [CPYClip] {
        try clipDb.fetchClips(ascending: ascending, limit: limit).map { $0.toClip }
    }

    /// The newest `limit` clips matching `filter`, newest first, alongside the per-row hits the
    /// menu highlights with. Reversing for display is the caller's job — see
    /// `ClipDB.fetchClips(filter:limit:)`.
    func fetchClips(filter: ClipFilter?, limit: Int) throws -> ClipSearchResult {
        let result = try clipDb.fetchClips(filter: filter, limit: limit)
        return ClipSearchResult(clips: result.clips.map { $0.toClip },
                                matchedTerms: result.matchedTerms)
    }

    func clipCount() throws -> Int {
        try clipDb.clipCount()
    }

    /// Deletes one clip and hands back its thumbnail cache key so the caller can evict it.
    @discardableResult
    func deleteClip(dataHash: String) throws -> String? {
        let thumbnailPath = try clipDb.fetchClip(dataHash: dataHash)?.thumbnailKey
        try clipDb.deleteClip(dataHash: dataHash)
        return thumbnailPath.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Clears the whole history. Nothing is reported back: a wipe leaves no survivors, so the
    /// thumbnails and payload files go as a whole through `ClipAssetStore.removeAllAssets()`
    /// rather than being tracked row by row.
    func clearAllClips() throws {
        try clipDb.deleteAllClips()
        #if DEBUG
        let orphans = try clipDb.orphanedContentCount()
        assert(orphans == 0, "clip_content left behind after clearing history: \(orphans) rows")
        #endif
    }

    /// Drops everything older than `updateTime`, returning the thumbnail cache keys that are
    /// now orphaned. Retention is a time window, so this runs once at launch rather than on a
    /// timer.
    @discardableResult
    func deleteExpiredClips(olderThan updateTime: Int) throws -> [String] {
        let thumbnailPaths = try clipDb.fetchThumbnailPaths(olderThan: updateTime)
        try clipDb.deleteClips(olderThan: updateTime)
        #if DEBUG
        // The FTS index is mirrored by SQL triggers, and this is the path that cannot be checked
        // from Swift: the delete is by predicate, so the keys of the dropped rows are never seen
        // here. Assert the trigger did its half.
        let clips = try clipDb.clipCount()
        let indexed = try clipDb.ftsCount()
        assert(clips == indexed, "clip_fts out of step after expiry: clip=\(clips) clip_fts=\(indexed)")
        // Same story for the payload side table, whose trigger is the only thing keeping it in
        // step across a delete-by-predicate.
        let orphans = try clipDb.orphanedContentCount()
        assert(orphans == 0, "clip_content out of step after expiry: \(orphans) orphaned rows")
        #endif
        return thumbnailPaths
    }

    /// File names (not full paths) of every payload file still referenced by a row.
    ///
    /// Inline clips have an empty `data_path`, which the filter drops — feeding "" to the sweep
    /// would only widen the set it compares against.
    func referencedDataFileNames() throws -> [String] {
        try clipDb.fetchAllDataPaths()
            .compactMap { $0.components(separatedBy: "/").last }
            .filter { $0.isNotEmpty }
    }
}
