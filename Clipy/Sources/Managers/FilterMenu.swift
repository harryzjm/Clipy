// 
//  FilterMenu.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
// 
//  Created by Aphro Hares on 2020/10/23.
// 
//  Copyright © 2015-2020 Clipy Project.
//

import Foundation
import Cocoa
import RealmSwift
import RxSwift
import RxCocoa
import RxOptional
import PINCache

class FilterMenu: NSMenu {
    fileprivate let bag = DisposeBag()
    fileprivate let realm = try! Realm()
    
    fileprivate let filterRelay = BehaviorRelay<String>(value: "")
    fileprivate let clipResultsRelay = BehaviorRelay<Results<CPYClip>?>(value: nil)
    
    let item: TextFieldMenuItem
    override init(title: String) {
        item = TextFieldMenuItem(title: title, action: nil)
        
        super.init(title: title)
        
        delegate = self
        
        addItem(item)
        
        clipResultsRelay
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .default))
            .flatMap { [weak self](res) -> Observable<String> in
                guard let self = self, res != nil else { return .empty() }
                return self.filterRelay.asObservable() }
            .distinctUntilChanged()
            .flatMapLatest { (filter)  -> Observable<NSPredicate?> in
                guard !filter.isEmpty else { return Observable.just(nil) }
                let predicate = NSPredicate(format: "title LIKE[c] %@", "*" + filter + "*")
                return Observable.just(predicate) }
            .withLatestFrom(clipResultsRelay) { (predicate, clipResults) -> [NSMenuItem]? in
                var res = clipResults
                if let predicate = predicate {
                    res = res?.filter(predicate)
                }
                return res?.enumerated().map { (obj) in
                    return NSMenuItem.item(with: obj.element)
                } }
            .filterNil()
            .catchErrorJustReturn([])
            .observeOn(ConcurrentMainScheduler.instance)
            .subscribe { [weak self](event) in
                guard let self = self, case .next(var new) = event else { return }
                self.higlight(menuItem: nil)
                new.insert(self.item, at: 0)
                self.reload(with: new)
            }.disposed(by: bag)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func cleanFilter() {
        filterRelay.accept("")
        item.content.queryTF.stringValue = ""
        item.content.updateVisibility()
    }
    
    func update(filter: String) {
        filterRelay.accept(filter)
    }
    
    func higlight(menuItem: NSMenuItem?) {
        let highlightItem = NSSelectorFromString("highlightItem:")
        if responds(to: highlightItem) {
            perform(highlightItem, with: menuItem)
        }
    }
    
    func reload(with items: [NSMenuItem]) {
        Array(items[..<min(items.count, 20)])
            .difference(from: Array(self.items)) { $0.title == $1.title }
            .forEach { (change) in
                switch change {
                case let .insert(offset, element, _):
                    self.insertItem(element, at: offset)
                case let .remove(_, element, _):
                    self.removeItem(element)
                }
            }
        
        if let item = self.items.first(where: { !($0 is TextFieldMenuItem) }) {
            self.higlight(menuItem: item)
        }
    }
}

extension FilterMenu: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        let ascending = !AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.reorderClipsAfterPasting)
        let res =  realm
            .objects(CPYClip.self)
            .sorted(byKeyPath: #keyPath(CPYClip.updateTime), ascending: ascending)
            .lazy
        clipResultsRelay.accept(res)
    }
    
    func menuDidClose(_ menu: NSMenu) {
        cleanFilter()
    }
}

fileprivate extension NSMenuItem {
    static func item(with clip: CPYClip) -> NSMenuItem {
        let isShowToolTip = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showToolTipOnMenuItem)
        let isShowImage = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showImageInTheMenu)
        let isShowColorCode = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showColorPreviewInTheMenu)
        
        let primaryPboardType = NSPasteboard.PasteboardType(rawValue: clip.primaryType)
        let clipString = clip.title
        
        let font = NSFont.systemFont(ofSize: 14)
        let attributes: [NSAttributedString.Key : Any] = [
            .foregroundColor:NSColor.labelColor,
            .font:font
        ]
        
        let title = clip.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replace(pattern: " *\n *", withTemplate: " ")
            .truncateToSize(size: .init(width: 300, height: font.lineHeight * 1.2), ellipses: "...", trailingText: "", attributes: attributes, trailingAttributes: attributes)
        
        let menuItem = NSMenuItem(title: title.string, action: #selector(AppDelegate.selectClipMenuItem(_:)))
        menuItem.attributedTitle = title
        menuItem.representedObject = clip.dataHash
        
        if isShowToolTip {
            let maxLengthOfToolTip = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.maxLengthOfToolTip)
            let toIndex = (clipString.count < maxLengthOfToolTip) ? clipString.count : maxLengthOfToolTip
            menuItem.toolTip = (clipString as NSString).substring(to: toIndex)
        }
        
        if primaryPboardType == .deprecatedTIFF {
            menuItem.title = "(Image)"
        } else if primaryPboardType == .deprecatedPDF {
            menuItem.title = "(PDF)"
        } else if primaryPboardType == .deprecatedFilenames && title.string.isEmpty {
            menuItem.title = "(Filenames)"
        }
        
        if !clip.thumbnailPath.isEmpty && !clip.isColorCode && isShowImage {
            PINCache.shared.object(forKeyAsync: clip.thumbnailPath) { [weak menuItem] _, _, object in
                DispatchQueue.main.async {
                    menuItem?.image = object as? NSImage
                }
            }
        }
        if !clip.thumbnailPath.isEmpty && clip.isColorCode && isShowColorCode {
            PINCache.shared.object(forKeyAsync: clip.thumbnailPath) { [weak menuItem] _, _, object in
                DispatchQueue.main.async {
                    menuItem?.image = object as? NSImage
                }
            }
        }
        
        return menuItem
    }
}
