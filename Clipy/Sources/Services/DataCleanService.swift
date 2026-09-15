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
    fileprivate var disposeBag = DisposeBag()
    fileprivate let scheduler = SerialDispatchQueueScheduler(qos: .utility)
    fileprivate let cleanBag = DisposeBag()

    // MARK: - Monitoring
    func startMonitoring() {
        disposeBag = DisposeBag()
        // Clean datas every 30 minutes
        Observable<Int>
            .interval(.seconds(60 * 30), scheduler: scheduler)
            .subscribe(onNext: { [weak self] _ in
                self?.cleanDatas()
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Delete Data
    func cleanDatas() {
        let maxHistorySize = AppEnvironment.current.defaults.integer(forKey: Preferences.General.maxHistorySize)

        AppEnvironment.current.box
            .clipTransaction { transaction -> ([String], [String]) in
                // Trim the overflow, then report what is still referenced on disk.
                let orphanedThumbnails = try transaction.deleteOverflowingClips(maxHistorySize: maxHistorySize)
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

        // Delete diff datas
        DispatchQueue.main.async {
            referenced.symmetricDifference(payloadFiles)
                .map { CPYUtilities.applicationSupportFolder() + "/" + "\($0)" }
                .forEach { CPYUtilities.deleteData(at: $0) }
        }
    }
}
