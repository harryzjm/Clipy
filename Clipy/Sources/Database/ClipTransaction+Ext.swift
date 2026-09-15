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
    }

    func fetchClip(dataHash: String) throws -> CPYClip? {
        try clipDb.fetchClip(dataHash: dataHash)?.toClip
    }

    func fetchClips(ascending: Bool, limit: Int? = nil) throws -> [CPYClip] {
        try clipDb.fetchClips(ascending: ascending, limit: limit).map { $0.toClip }
    }

    func clipCount() throws -> Int {
        try clipDb.clipCount()
    }

    /// Deletes one clip and hands back its thumbnail cache key so the caller can evict it.
    @discardableResult
    func deleteClip(dataHash: String) throws -> String? {
        let thumbnailPath = try clipDb.fetchClip(dataHash: dataHash)?.thumbnailPath
        try clipDb.deleteClip(dataHash: dataHash)
        return thumbnailPath.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Clears the whole history, returning the thumbnail cache keys that are now orphaned.
    @discardableResult
    func clearAllClips() throws -> [String] {
        let thumbnailPaths = try clipDb.fetchThumbnailPaths()
        try clipDb.deleteAllClips()
        return thumbnailPaths
    }

    /// Trims the history down to `maxHistorySize`, returning the thumbnail cache keys that are
    /// now orphaned.
    ///
    /// Mirrors the previous Realm behaviour: find the `update_time` of the last clip that fits,
    /// then delete everything strictly older than it.
    @discardableResult
    func deleteOverflowingClips(maxHistorySize: Int) throws -> [String] {
        guard let threshold = try clipDb.overflowThreshold(maxHistorySize: maxHistorySize) else { return [] }
        let thumbnailPaths = try clipDb.fetchThumbnailPaths(olderThan: threshold)
        try clipDb.deleteClips(olderThan: threshold)
        return thumbnailPaths
    }

    /// File names (not full paths) of every payload file still referenced by a row.
    func referencedDataFileNames() throws -> [String] {
        try clipDb.fetchAllDataPaths().compactMap { $0.components(separatedBy: "/").last }
    }
}
