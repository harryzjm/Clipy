//
//  ClipComponentService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation
import RxSwift

/// Owns `clip.db` and the serial queue every clipboard-history access runs on.
///
/// Kept separate from `SnippetComponentService` because clip writes are driven by the 750ms
/// pasteboard poll, while snippet writes are user-driven from the editor; neither should block
/// the other.
final class ClipComponentService: ComponentService {

    let name = "Clip"
    weak var box: ClipyBox!

    lazy fileprivate(set) var clipDb: ClipDB = {
        .init(rootPath: box.path, name: "clip.db", store: box.store)
    }()

    let inter = ComponentServiceInternal()
    let queue = LQueue(label: "com.clipy.box.clip")
    let observeScheduler: ImmediateSchedulerType = SerialDispatchQueueScheduler(qos: .default,
                                                                               internalSerialQueueName: "com.clipy.box.clip.observe")

    let viewTracker = ClipViewTracker()
}

struct ClipServiceTransaction: Transaction {

    weak var service: ClipComponentService!

    init(service: ClipComponentService!) {
        self.service = service
    }

    var clipDb: ClipDB {
        service.clipDb
    }

    func begin() throws {
        try clipDb.begin()
    }

    func commit() throws {
        try clipDb.commit()
    }

    func rollback() throws {
        try clipDb.rollback()
    }

    /// `VACUUM`, then realign the FTS mirror.
    ///
    /// The two belong together: `clip_fts` is keyed by `clip.rowid`, and VACUUM renumbers those
    /// rowids (`clip`'s primary key is TEXT, so there is no INTEGER PRIMARY KEY for it to
    /// preserve). Left unrepaired, every later FTS delete would target the wrong row.
    ///
    /// Call this with `ignoreTransaction: true` — SQLite refuses to VACUUM inside a transaction:
    ///
    ///     box.clipTransaction(ignoreTransaction: true) { try $0.vacuum() }
    ///
    /// The rebuild takes its own transaction so a failure partway cannot leave the index empty.
    func vacuum() throws {
        try clipDb.vacuum()

        try clipDb.begin()
        do {
            try clipDb.rebuildFtsIndex()
            try clipDb.commit()
        } catch {
            try clipDb.rollback()
            throw error
        }
    }

    /// Publishes the transaction's deltas to the live views before the commit lands.
    func beforeCommit() throws {
        let change = ClipChangeSet(status: clipDb.status)
        if !change.isEmpty {
            service.viewTracker.updateViews(currentTransaction: self, change: change)
        }
        clipDb.status.clean()
    }
}
