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
import PINCache

final class DataCleanService {

    // MARK: - Properties
    fileprivate let cleanBag = DisposeBag()

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

        AppEnvironment.current.box
            .clipTransaction { transaction -> ([String], [String]) in
                // Drop what expired, then report what is still referenced on disk.
                let orphanedThumbnails = try transaction.deleteExpiredClips(olderThan: threshold)
                let referencedFiles = try transaction.referencedDataFileNames()
                return (orphanedThumbnails, referencedFiles)
            }
            .subscribe(onNext: { orphanedThumbnails, referencedFiles in
                orphanedThumbnails.forEach { PINCache.shared.removeObject(forKey: $0) }
                DataCleanService.cleanFiles(referencing: referencedFiles)
            }, onError: { _ in })
            .disposed(by: cleanBag)
    }

    private static func cleanFiles(referencing referencedFiles: [String]) {
        let fileManager = FileManager.default
        guard let paths = try? fileManager.contentsOfDirectory(atPath: CPYUtilities.applicationSupportFolder()) else { return }

        // Only the payload files are ours to sweep. The databases live in a `db` subdirectory of
        // this same folder, and a blind symmetric difference would delete them.
        let payloadFiles = paths.filter { ($0 as NSString).pathExtension == "data" }
        let referenced = Set(referencedFiles.filter { ($0 as NSString).pathExtension == "data" })

        LQueue.main.dispatch {
            referenced.symmetricDifference(payloadFiles)
                .map { CPYUtilities.applicationSupportFolder() + "/" + "\($0)" }
                .forEach { CPYUtilities.deleteData(at: $0) }
        }
    }
}
