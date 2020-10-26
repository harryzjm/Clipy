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

    let isMarkWithNumber = AppEnvironment.current.defaults.bool(forKey: Preferences.Menu.menuItemsAreMarkedWithNumbers)
    let addNumbericKeyEquivalents = AppEnvironment.current.defaults.bool(forKey: Preferences.Menu.addNumericKeyEquivalents)

    let isShowToolTip = AppEnvironment.current.defaults.bool(forKey: Preferences.Menu.showToolTipOnMenuItem)
    let isShowImage = AppEnvironment.current.defaults.bool(forKey: Preferences.Menu.showImageInTheMenu)
    let isShowColorCode = AppEnvironment.current.defaults.bool(forKey: Preferences.Menu.showColorPreviewInTheMenu)
    let maxWidthOfMenuItem = CGFloat(AppEnvironment.current.defaults.float(forKey: Preferences.Menu.maxWidthOfMenuItem))

    let item: TextFieldMenuItem

    override init(title: String) {
        item = TextFieldMenuItem(title: title, action: nil)

        super.init(title: title)

        delegate = self

        addItem(item)

        clipResultsRelay
            .subscribeOn(SerialDispatchQueueScheduler(qos: .default))
            .flatMap { [weak self]res -> Observable<String> in
                guard let self = self, res != nil else { return .empty() }
                return self.filterRelay.asObservable()
            }
            .distinctUntilChanged()
            .flatMapLatest { filter -> Observable<NSPredicate?> in
                guard !filter.isEmpty else { return Observable.just(nil) }
                let predicate = NSPredicate(format: "title LIKE[c] %@", "*" + filter + "*")
                return Observable.just(predicate)
            }
            .withLatestFrom(clipResultsRelay) { [weak self]predicate, clipResults -> [NSMenuItem]? in
                var res = clipResults
                if let predicate = predicate {
                    res = res?.filter(predicate)
                }
                return res?.enumerated().compactMap { obj in
                    return self?.item(with: obj.element, index: obj.offset + 1)
                }
            }
            .filterNil()
            .catchErrorJustReturn([])
            .observeOn(ConcurrentMainScheduler.instance)
            .subscribe { [weak self]event in
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
        self.removeAllItems()
        items.forEach(self.addItem(_:))

        if let item = self.items.first(where: { !($0 is TextFieldMenuItem) }) {
            self.higlight(menuItem: item)
        }
    }
}

extension FilterMenu: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        let ascending = !AppEnvironment.current.defaults.bool(forKey: Preferences.General.reorderClipsAfterPasting)
        let res = realm
            .objects(CPYClip.self)
            .sorted(byKeyPath: #keyPath(CPYClip.updateTime), ascending: ascending)
            .lazy
        clipResultsRelay.accept(res)
    }

    func menuDidClose(_ menu: NSMenu) {
        cleanFilter()
    }
}

private let kMaxKeyEquivalent = 10
fileprivate extension FilterMenu {
    func item(with clip: CPYClip, index: Int) -> NSMenuItem {
        let keyEquivalent: String = {
            switch index {
            case 1 ..< kMaxKeyEquivalent: return "\(index)"
            case kMaxKeyEquivalent: return "0"
            default: return ""
            }
        }()

        let primaryPboardType = NSPasteboard.PasteboardType(rawValue: clip.primaryType)
        let originTitle = clip.title
        let prefix = isMarkWithNumber && keyEquivalent.isNotEmpty  ? keyEquivalent:""

        let title = prefix + {
            switch primaryPboardType {
            case .deprecatedTIFF: return "(Image)"
            case .deprecatedPDF: return "(PDF)"
            case .deprecatedFilenames: return "(Filenames)"
            default: return clip.title
            }
        }()
        let attributedTitle = title.trim(with: maxWidthOfMenuItem)
        let menuItem = NSMenuItem(title: attributedTitle.string, action: #selector(AppDelegate.selectClipMenuItem(_:)), keyEquivalent: keyEquivalent)
        menuItem.attributedTitle = attributedTitle
        menuItem.representedObject = clip.dataHash

        if isShowToolTip {
            let maxLengthOfToolTip = AppEnvironment.current.defaults.integer(forKey: Preferences.Menu.maxLengthOfToolTip)
            menuItem.toolTip = (originTitle as NSString).substring(to: min(originTitle.count, maxLengthOfToolTip))
        }

        let isImage = !clip.isColorCode && isShowImage
        let isColor = clip.isColorCode && isShowColorCode
        if clip.thumbnailPath.isNotEmpty && (isImage || isColor) {
            PINCache.shared.object(forKeyAsync: clip.thumbnailPath) { [weak menuItem] _, _, object in
                DispatchQueue.main.async {
                    menuItem?.image = object as? NSImage
                }
            }
        }

        return menuItem
    }
}

fileprivate extension String {
    func trim(with maxWidth: CGFloat) -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: 14)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: font
        ]

        return trimmingCharacters(in: .whitespacesAndNewlines)
            .replace(pattern: " *\n *", withTemplate: " ")
            .truncateToSize(size: .init(width: maxWidth, height: font.lineHeight * 1.2), ellipses: "...", trailingText: "", attributes: attributes, trailingAttributes: attributes)
    }
}
