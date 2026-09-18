//
//  DataCleanService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/11/20.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import RxSwift

final class DataCleanService {

    // MARK: - Properties
    private let box: ClipyBox
    private let assetStore: ClipAssetStore
    fileprivate let cleanBag = DisposeBag()

    // MARK: - Initialize
    init(box: ClipyBox, assetStore: ClipAssetStore) {
        self.box = box
        self.assetStore = assetStore
    }

    // MARK: - Delete Data
    /// Drops clips outside the retention window and sweeps the payload files nothing points at
    /// any more.
    ///
    /// Retention is a time window rather than a row count, so this runs once at launch instead of
    /// on a timer; `ClipService.clearAll()` calls it again to collect what the wipe orphaned.
    func cleanDatas() {
        let days = AppEnvironment.current.defaults.integer(forKey: Preferences.General.maxHistoryDays)
        // A missing or nonsensical retention must not be read as "keep nothing". Falling back to
        // a threshold of 0 matches no row, so nothing is deleted while the file sweep below still
        // runs — `clearAll()` calls this purely for that sweep.
        let threshold = days > 0 ? Int(Date().timeIntervalSince1970) - days * 86_400 : 0

        box
            .clipTransaction { transaction -> ([String], [String]) in
                // Drop what expired, then report what is still referenced on disk.
                let orphanedThumbnails = try transaction.deleteExpiredClips(olderThan: threshold)
                let referencedFiles = try transaction.referencedDataFileNames()
                return (orphanedThumbnails, referencedFiles)
            }
            .subscribe(onNext: { [assetStore = self.assetStore] orphanedThumbnails, referencedFiles in
                // Both of these are the asset queue's work now — the sweep used to delete files
                // on the main thread.
                assetStore.removeThumbnails(orphanedThumbnails)
                assetStore.sweepFiles(referencing: referencedFiles)
            }, onError: { _ in })
            .disposed(by: cleanBag)
    }
}
