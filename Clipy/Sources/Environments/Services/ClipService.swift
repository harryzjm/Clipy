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
import RxSwift
import RxCocoa
import RxOptional

final class ClipService {

    // MARK: - Properties
    private let box: ClipyBox
    private let assetStore: ClipAssetStore
    fileprivate var cachedChangeCount = BehaviorRelay<Int>(value: 0)
    fileprivate var storeTypes = [String: NSNumber]()
    fileprivate let scheduler = SerialDispatchQueueScheduler(qos: .userInteractive)
    fileprivate var disposeBag = DisposeBag()
    /// Long-lived, for one-shot writes that must outlive a `startMonitoring()` restart.
    fileprivate let writeBag = DisposeBag()

    // MARK: - Initialize
    init(box: ClipyBox, assetStore: ClipAssetStore) {
        self.box = box
        self.assetStore = assetStore
    }

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
        box.clipTransaction { try $0.clearAllClips() }
            .subscribe(onNext: { [assetStore = self.assetStore] in
                // Nothing survives the wipe, so there is nothing to mark and sweep: drop `file/`
                // and the thumbnail cache wholesale.
                assetStore.removeAllAssets()
            }, onError: { _ in })
            .disposed(by: writeBag)
    }

    /// Rebuilds `clip_fts` under `tokenizer`, clearing the whole history with it.
    ///
    /// The preference is written only once the transaction has committed, so it never names a
    /// tokenizer the index does not have. On failure it is left alone and `completion` gets
    /// `false`. `completion` runs on main.
    func switchFtsTokenizer(to tokenizer: ClipFtsTokenizer, completion: ((Bool) -> Void)? = nil) {
        box.clipTransaction { try $0.switchFtsTokenizer(to: tokenizer) }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [assetStore = self.assetStore] in
                // Same as `clearAll()`: nothing survives, so drop `file/` and the thumbnails whole.
                assetStore.removeAllAssets()
                AppEnvironment.current.defaults.set(tokenizer.rawValue, forKey: Preferences.Menu.ftsTokenizer)
                completion?(true)
            }, onError: { error in
                lError("switching the FTS tokenizer to \(tokenizer) failed:", error)
                completion?(false)
            })
            .disposed(by: writeBag)
    }

    /// Realigns `Preferences.Menu.ftsTokenizer` with what `clip_fts` was actually built with.
    ///
    /// The schema wins, and nothing is cleared: this only covers the preference having drifted —
    /// a crash between a switch's commit and its preference write, or a history database that was
    /// deleted or reset while the preference stayed behind. Run once at launch.
    func syncFtsTokenizerPreference() {
        box.clipTransaction { try $0.ftsTokenizer() }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { tokenizer in
                let defaults = AppEnvironment.current.defaults
                guard defaults.string(forKey: Preferences.Menu.ftsTokenizer) != tokenizer.rawValue else { return }
                lWarning("FTS tokenizer preference out of step with clip_fts; realigning to \(tokenizer)")
                defaults.set(tokenizer.rawValue, forKey: Preferences.Menu.ftsTokenizer)
            }, onError: { error in
                lError(error)
            })
            .disposed(by: writeBag)
    }

    func delete(with clip: CPYClip) {
        let dataHash = clip.dataHash
        box.clipTransaction { try $0.deleteClip(dataHash: dataHash) }
            .subscribe(onNext: { [assetStore = self.assetStore] thumbnailPath in
                // Delete saved image
                guard let thumbnailPath = thumbnailPath else { return }
                assetStore.removeThumbnails([thumbnailPath])
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
        save(with: types.compactMap { TypeContent(pasteboard: pasteboard, type: $0) })
    }

    func create(with title: String, image: NSImage) {
        // Create only image data
        save(with: [.string(title), .tiff(.init(image: image))])
    }

    fileprivate func save(with contents: [TypeContent]) {
        // Nothing worth storing.
        guard let clip = CPYClip(contents: contents) else { return }

        // Ahead of the insert, and deliberately so: this buffers an overflowed payload
        // synchronously, so anything that can see the row can already read it. The file write
        // itself, and the thumbnail, are handed to the asset queue — neither the poll scheduler
        // nor the main thread (`create(with:image:)`) waits on them.
        assetStore.store(clip, contents: contents)

        // Storing does not wait on the thumbnail either: `thumbnailKey` is derived from
        // `updateTime`, so it is already known, and the menu reads the image back out of the
        // cache asynchronously.
        box.clipTransaction { try $0.insertClip(clip) }.run()
    }

    private func types(with pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        let types = pasteboard.types?.filter { canSave(with: $0) } ?? []
        return NSOrderedSet(array: types).array as? [NSPasteboard.PasteboardType] ?? []
    }

    private func canSave(with type: NSPasteboard.PasteboardType) -> Bool {
        let dictionary = TypeContent.availableTypesDictionary
        guard let value = dictionary[type] else { return false }
        guard let number = storeTypes[value] else { return false }
        return number.boolValue
    }
}
