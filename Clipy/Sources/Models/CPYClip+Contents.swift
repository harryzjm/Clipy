//
//  CPYClip+Contents.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Cocoa

// The initializer lives in an extension on purpose: `CPYClip` relies on the implicit `init()`
// (`CPYClipTable.toClip` and the test factories all use it), and declaring any initializer in the
// class body would take that away.
extension CPYClip {

    /// Payloads at or below this size are stored inline in `clip_content`; anything larger is
    /// given a `file/<uuid>` path and written out by `ClipAssetStore`. Most clips are plain text
    /// and stay well under it, which is what keeps the common case off the filesystem entirely.
    static let inlineContentLimit = 10 * 1024

    /// Builds a clip from a freshly captured pasteboard payload.
    ///
    /// Everything here is derived — no disk, no image rendering. An oversized payload gets a
    /// `dataPath` but stays in `content`; handing the pair to `ClipAssetStore.store(_:contents:)`
    /// is what eventually puts it on disk. So a freshly captured clip is the one case where
    /// `content` and `dataPath` are both set; everything read back from the database keeps them
    /// exclusive, and `insertClip` is where that is enforced.
    ///
    /// Returns nil only when there is nothing worth storing.
    convenience init?(contents: [TypeContent]) {
        // Delegation first: a class initializer may only fail once it has taken place.
        self.init()

        guard !contents.isEmpty else { return nil }
        guard let payload = try? JSONEncoder().encode(contents) else {
            lError("Failed to encode clip contents")
            return nil
        }

        dataHash = contents.identifier
        title = contents.stringValue?[0...10000] ?? ""
        primaryType = contents.primaryType?.rawValue ?? ""
        updateTime = Int(Date().timeIntervalSince1970)

        if contents.hasThumbnail {
            clipType = .image
        } else if contents.isColorCode {
            clipType = .color
        } else {
            clipType = .text
        }
        if clipType != .text {
            thumbnailKey = dataHash
        }

        content = payload
        if payload.count > Self.inlineContentLimit {
            dataPath = ClipAssetStore.makeDataPath()
        }
    }

    /// Decodes the payload back into pasteboard pieces.
    ///
    /// Only the paste path calls this: `content` stays an opaque blob everywhere else, so a menu
    /// rebuild never pays for a JSON decode it has no use for. The file read for an overflowed
    /// payload happens here rather than in `fetchClip(dataHash:)` for the same reason — nothing
    /// but a paste should touch the disk.
    ///
    /// `assetStore` is passed in rather than reached for: the model layer has no business
    /// touching `AppEnvironment`, and a test can hand in one rooted in its own scratch directory
    /// without ever constructing the global `Environment` (and so without reaching the
    /// developer's keychain).
    func loadContents(assetStore: ClipAssetStore) -> [TypeContent]? {
        do {
            let data: Data
            if let content = content {
                data = content
            } else if dataPath.isNotEmpty {
                // Already logged by `loadPayload` — a failed write, or an unreadable file.
                guard let payload = assetStore.loadPayload(at: dataPath) else { return nil }
                data = payload
            } else {
                // Neither half is set, which means this clip came from a list query — those do
                // not read `clip_content`. Load it with `fetchClip(dataHash:)` instead of
                // silently pasting nothing.
                lError("Clip payload was never loaded, fetch it with fetchClip(dataHash:):", dataHash)
                return nil
            }
            return try JSONDecoder().decode([TypeContent].self, from: data)
        } catch {
            lError(error)
            return nil
        }
    }
}
