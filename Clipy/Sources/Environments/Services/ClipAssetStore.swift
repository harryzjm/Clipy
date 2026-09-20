//
//  ClipAssetStore.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Cocoa
import PINCache

final class ClipAssetStore {
    let queue = LQueue(label: "com.clipy.clip.asset", qos: .utility)

    static let directoryName = "file"

    private let secretService: SecretService

    private let root: String
    private var pending = Atomic<[String: Data]>(value: [:])

    init(secretService: SecretService, root: String) {
        self.secretService = secretService
        self.root = root
    }

    static func makeDataPath() -> String {
        "\(directoryName)/\(UUID().uuidString)"
    }
}

// MARK: - Capture
extension ClipAssetStore {
    func store(_ clip: CPYClip, contents: [TypeContent]) {
        storePayloadIfNeed(clip)
        storethumbnailIfNeed(clip.thumbnailKey, contents: contents)
    }

    private func storePayloadIfNeed(_ clip: CPYClip) {
        let dataPath = clip.dataPath
        guard dataPath.isNotEmpty, let payload = clip.content else { return }
        pending.adapt { $0[dataPath] = payload }

        queue.dispatchAsync {
            do {
                try self.writePayload(payload, to: dataPath)
            } catch {
                lError("Failed to write clip payload:", dataPath, error)
            }
            self.pending.adapt { $0[dataPath] = nil }
        }
    }

    private func storethumbnailIfNeed(_ key: String, contents: [TypeContent]) {
        guard key.isNotEmpty else { return }
        queue.dispatchAsync {
            guard let image = contents.thumbnailImage ?? contents.colorCodeImage else { return }
            let cache: PINCaching = PINCache.shared
            cache.setObject(image, forKey: key)
        }
    }
}

// MARK: - Payload files
extension ClipAssetStore {

    /// The payload behind `dataPath`, whether or not it has reached the disk yet.
    ///
    /// Nil means it is gone for good: either the write failed, or the file is unreadable. Both
    /// are logged here rather than at the call site.
    func loadPayload(at dataPath: String) -> Data? {
        if let buffered = pending.with { $0[dataPath] } { return buffered }

        do {
            return try readPayload(at: dataPath)
        } catch {
            lError("Failed to read clip payload:", dataPath, error)
            return nil
        }
    }

    /// Encrypts and writes a payload, creating `file/` on the way.
    ///
    /// Synchronous: `store(_:contents:)` calls it from the asset queue, tests call it directly.
    func writePayload(_ payload: Data, to dataPath: String) throws {
        let directory = (root as NSString).appendingPathComponent(Self.directoryName)
        guard CPYUtilities.prepareSaveToPath(directory) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try secretService.seal(payload, context: dataPath).write(to: URL(fileURLWithPath: absolutePath(of: dataPath)))
    }

    /// Reads and decrypts a payload. Throws when the file is missing, truncated, or was written
    /// under a different key or a different `dataPath`.
    func readPayload(at dataPath: String) throws -> Data {
        let stored = try Data(contentsOf: URL(fileURLWithPath: absolutePath(of: dataPath)))
        return try secretService.unseal(stored, context: dataPath)
    }

    func absolutePath(of dataPath: String) -> String {
        (root as NSString).appendingPathComponent(dataPath)
    }
}

// MARK: - Reclaiming
extension ClipAssetStore {

    /// Evicts thumbnails whose clips are gone.
    func removeThumbnails(_ keys: [String]) {
        guard !keys.isEmpty else { return }
        queue.dispatchAsync {
            keys.forEach { PINCache.shared.removeObject(forKey: $0) }
        }
    }

    /// Drops every asset any clip could own: the whole `file/` directory and the entire
    /// thumbnail cache.
    ///
    /// `sweepFiles(referencing:)`'s mark-and-sweep exists because expiry deletes by predicate and
    /// Swift never learns which rows went — a wipe has no survivors to protect, so it does not
    /// need it. The directory goes as a whole; `writePayload` recreates it on the next capture.
    func removeAllAssets() {
        queue.dispatchAsync { [root = self.root] in
            CPYUtilities.deleteData(at: (root as NSString).appendingPathComponent(Self.directoryName))
            PINCache.shared.removeAllObjects()
        }
    }

    /// Deletes every payload file in `file/` that no row points at any more.
    ///
    /// Mark-and-sweep rather than deleting alongside the row, because expiry deletes by predicate
    /// (`deleteClips(olderThan:)`) and the Swift side never learns which rows went.
    func sweepFiles(referencing referencedFiles: [String]) {
        queue.dispatchAsync { [root = self.root] in
            let directory = (root as NSString).appendingPathComponent(Self.directoryName)
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return }

            // `subtracting`, not a symmetric difference: the referenced set can name files that
            // are not on disk (a write that failed), and those are not ours to "delete".
            let referenced = Set(referencedFiles)
            Set(names).subtracting(referenced)
                .map { (directory as NSString).appendingPathComponent($0) }
                .forEach { CPYUtilities.deleteData(at: $0) }
        }
    }
}
