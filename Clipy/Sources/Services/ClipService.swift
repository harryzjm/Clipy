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
import RealmSwift
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
        let realm = try! Realm()
        let clips = realm.objects(CPYClip.self)

        // Delete saved images
        clips
            .filter { !$0.thumbnailPath.isEmpty }
            .map { $0.thumbnailPath }
            .forEach { PINCache.shared.removeObject(forKey: $0) }
        // Delete Realm
        realm.transaction { realm.delete(clips) }
        // Delete writed datas
        AppEnvironment.current.dataCleanService.cleanDatas()
    }

    func delete(with clip: CPYClip) {
        let realm = try! Realm()
        // Delete saved images
        let path = clip.thumbnailPath
        if !path.isEmpty {
            PINCache.shared.removeObject(forKey: path)
        }
        // Delete Realm
        realm.transaction { realm.delete(clip) }
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

        DispatchQueue.global(qos: .userInteractive).async {
            // Saved time and path
            let unixTime = Int(Date().timeIntervalSince1970)
            let savedPath = CPYUtilities.applicationSupportFolder() + "/\(NSUUID().uuidString).data"
            // Create Realm object
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
            } else if let colorCodeImage = data.colorCodeImage {
                PINCache.shared.setObjectAsync(colorCodeImage, forKey: "\(unixTime)", completion: nil)
                clip.thumbnailPath = "\(unixTime)"
                clip.isColorCode = true
            }

            if CPYUtilities.prepareSaveToPath(CPYUtilities.applicationSupportFolder()) {
                try? JSONEncoder().encode(data).write(to: .init(fileURLWithPath: savedPath))

                DispatchQueue.main.async {
                    // Save Realm and .data file
                    let dispatchRealm = try! Realm()
                    dispatchRealm.transaction {
                        dispatchRealm.add(clip, update: .all)
                    }
                }
            }
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
