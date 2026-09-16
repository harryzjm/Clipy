//
//  ClipService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/11/17.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import Cocoa
import PINCache
import RxSwift
import RxCocoa
import RxOptional

final class ClipService {

    // MARK: - Properties
    fileprivate var cachedChangeCount = BehaviorRelay<Int>(value: 0)
    fileprivate var storeTypes = [String: NSNumber]()
    fileprivate let scheduler = SerialDispatchQueueScheduler(qos: .userInteractive)
    fileprivate var disposeBag = DisposeBag()
    /// Long-lived, for one-shot writes that must outlive a `startMonitoring()` restart.
    fileprivate let writeBag = DisposeBag()

    // MARK: - Clips
    func startMonitoring() {
        disposeBag = DisposeBag()
        // Pasteboard observe timer
        Observable<Int>
            .interval(.milliseconds(750), scheduler: scheduler)
            .map { _ in NSPasteboard.general.changeCount }
            .withLatestFrom(cachedChangeCount.asObservable()) { ($0, $1) }
            .filter { $0 != $1 }
            .subscribe(onNext: { [weak self] changeCount, _ in
                self?.cachedChangeCount.accept(changeCount)
                self?.create()
            })
            .disposed(by: disposeBag)
        // Store types
        AppEnvironment.current.defaults.rx
            .observe([String: NSNumber].self, Constants.UserDefaults.storeTypes)
            .filterNil()
            .asDriver(onErrorDriveWith: .empty())
            .drive(onNext: { [weak self] in
                self?.storeTypes = $0
            })
            .disposed(by: disposeBag)
    }

    func clearAll() {
        AppEnvironment.current.box
            .clipTransaction { try $0.clearAllClips() }
            .subscribe(onNext: { thumbnailPaths in
                // Delete saved images
                thumbnailPaths.forEach { PINCache.shared.removeObject(forKey: $0) }
                // Delete writed datas
                AppEnvironment.current.dataCleanService.cleanDatas()
            }, onError: { _ in })
            .disposed(by: writeBag)
    }

    func delete(with clip: CPYClip) {
        let dataHash = clip.dataHash
        AppEnvironment.current.box
            .clipTransaction { try $0.deleteClip(dataHash: dataHash) }
            .subscribe(onNext: { thumbnailPath in
                // Delete saved image
                guard let thumbnailPath = thumbnailPath else { return }
                PINCache.shared.removeObject(forKey: thumbnailPath)
            }, onError: { _ in })
            .disposed(by: writeBag)
    }

    func incrementChangeCount() {
        cachedChangeCount.accept(cachedChangeCount.value + 1)
    }

}

// MARK: - Create Clip
extension ClipService {
    fileprivate func create() {
        // Store types
        if !storeTypes.values.contains(NSNumber(value: true)) { return }
        // Pasteboard types
        let pasteboard = NSPasteboard.general
        let types = self.types(with: pasteboard)
        if types.isEmpty { return }

        // Excluded application
        guard !AppEnvironment.current.excludeAppService.frontProcessIsExcludedApplication() else { return }
        // Special applications
        guard !AppEnvironment.current.excludeAppService.copiedProcessIsExcludedApplications(pasteboard: pasteboard) else { return }

        // Create data
        let data = CPYClipData(pasteboard: pasteboard, types: types)
        save(with: data)
    }

    func create(with title: String, image: NSImage) {
        // Create only image data
        let data = CPYClipData(title: title, image: image)
        save(with: data)
    }

    fileprivate func save(with data: CPYClipData) {
        // Don't save empty string history
        if !data.isValid { return }

        let unixTime = Int(Date().timeIntervalSince1970)
        let savedPath = CPYUtilities.applicationSupportFolder() + "/\(NSUUID().uuidString).data"
        // Create clip
        let clip = CPYClip()
        clip.dataHash = data.identifier
        clip.dataPath = savedPath
        clip.title = data.stringValue?[0...10000] ?? ""
        clip.updateTime = unixTime
        clip.primaryType = data.primaryType?.rawValue ?? ""

        // Save thumbnail image
        if let thumbnailImage = data.thumbnailImage {
            PINCache.shared.setObjectAsync(thumbnailImage, forKey: "\(unixTime)", completion: nil)
            clip.thumbnailPath = "\(unixTime)"
            clip.clipType = .image
        } else if let colorCodeImage = data.colorCodeImage {
            PINCache.shared.setObjectAsync(colorCodeImage, forKey: "\(unixTime)", completion: nil)
            clip.thumbnailPath = "\(unixTime)"
            clip.clipType = .color
        }

        if CPYUtilities.prepareSaveToPath(CPYUtilities.applicationSupportFolder()) {
            try? JSONEncoder().encode(data).write(to: .init(fileURLWithPath: savedPath))
            // The store runs on its own serial queue, so no main-thread hop is needed.
            AppEnvironment.current.box.clipTransaction { try $0.insertClip(clip) }.run()
        }
    }

    private func types(with pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        let types = pasteboard.types?.filter { canSave(with: $0) } ?? []
        return NSOrderedSet(array: types).array as? [NSPasteboard.PasteboardType] ?? []
    }

    private func canSave(with type: NSPasteboard.PasteboardType) -> Bool {
        let dictionary = CPYClipData.availableTypesDictionary
        guard let value = dictionary[type] else { return false }
        guard let number = storeTypes[value] else { return false }
        return number.boolValue
    }
}
