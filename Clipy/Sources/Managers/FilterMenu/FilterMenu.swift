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

    let config: FilterMenuConfig
    let item: TextFieldMenuItem

    override init(title: String) {
        config = FilterMenuConfig.current()
        item = TextFieldMenuItem(title: title, action: nil)

        super.init(title: title)

        delegate = self

        addItem(item)

        clipResultsRelay
            .subscribeOn(SerialDispatchQueueScheduler(qos: .default))
            .flatMapLatest { [weak self]res -> Observable<String> in
                guard let self = self, res != nil else { return .empty() }
                return self.filterRelay.asObservable()
            }
            .distinctUntilChanged()
            .withLatestFrom(clipResultsRelay) { [weak self]filter, clipResults -> [NSMenuItem]? in
                guard var clipResults = clipResults, let self = self else { return nil }
                if filter.isNotEmpty {
                    let predicate = NSPredicate(format: "title LIKE[c] %@", "*" + filter + "*")
                    clipResults = clipResults.filter(predicate)
                }

                var items: [NSMenuItem] = []
                let totalCount = min(clipResults.count, self.config.maxHistory)
                let remain = max(totalCount - self.config.placeInLine, 0)
                items += clipResults[0..<totalCount - remain]
                    .enumerated()
                    .map { obj in
                    return self.item(with: obj.element, index: obj.offset + 1)
                    }

                let res = remain.quotientAndRemainder(dividingBy: self.config.placeInsideFolder)
                items += (0 ..< res.quotient).map { i -> NSMenuItem in
                    let begin = self.config.placeInLine + self.config.placeInsideFolder * i
                    let end = begin + self.config.placeInsideFolder
                    return self.item(begin: begin, end: end) { clipResults[$0] }
                }

                if res.remainder > 0 {
                    let begin = self.config.placeInLine + self.config.placeInsideFolder * res.quotient
                    let end = begin + res.remainder

                    items.append(self.item(begin: begin, end: end) { clipResults[$0] })
                }
                return items
            }
            .filterNil()
            .catchErrorJustReturn([])
            .observeOn(ConcurrentMainScheduler.instance)
            .subscribe { [weak self]event in
                guard let self = self, case .next(var new) = event else { return }
                self.highlight(menuItem: nil)
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

    func highlight(menuItem: NSMenuItem?) {
        let highlightItem = NSSelectorFromString("highlightItem:")
        if responds(to: highlightItem) {
            perform(highlightItem, with: menuItem)
        }
    }

    func reload(with items: [NSMenuItem]) {
        self.removeAllItems()
        items.forEach(self.addItem(_:))

        if let item = self.items.first(where: { !($0 is TextFieldMenuItem) }) {
            self.highlight(menuItem: item)
        }
    }
}

extension FilterMenu: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        let ascending = !AppEnvironment.current.defaults.bool(forKey: Preferences.General.reorderClipsAfterPasting)
        let res = realm
            .objects(CPYClip.self)
            .sorted(byKeyPath: #keyPath(CPYClip.updateTime), ascending: ascending)

        clipResultsRelay.accept(res)
    }

    func menuDidClose(_ menu: NSMenu) {
        cleanFilter()
    }
}

private let kMaxKeyEquivalent = 10

fileprivate extension FilterMenu {

    func item(begin: Int, end: Int, clipHandle: (Int) -> CPYClip?) -> NSMenuItem {
        let subMenu = NSMenu(title: "")
        let menuItem = NSMenuItem(title: "\(begin)-\(end)", action: nil)
        menuItem.submenu = subMenu
        menuItem.image = self.config.showIconInTheMenu ? Asset.Common.iconFolder.image : nil

        (begin ..< end).forEach { i in
            guard let clip = clipHandle(i) else { return }
            subMenu.addItem(self.item(with: clip, index: i))
        }
        return menuItem
    }

    func item(with clip: CPYClip, index: Int) -> NSMenuItem {
        let keyEquivalent: String = {
            guard config.addNumericKeyEquivalents else { return "" }
            switch index {
            case 1 ..< kMaxKeyEquivalent: return "\(index). "
            case kMaxKeyEquivalent: return "0. "
            default: return ""
            }
        }()

        let primaryPboardType = NSPasteboard.PasteboardType(rawValue: clip.primaryType)
        let originTitle = clip.title
        let prefix = config.isMarkWithNumber && keyEquivalent.isNotEmpty  ? keyEquivalent:""

        let title = { () -> String in
            switch primaryPboardType {
            case .deprecatedTIFF: return "(Image)"
            case .deprecatedPDF: return "(PDF)"
            case .deprecatedFilenames: return "(Filenames)"
            default: return clip.title
            }
        }()
        let attributedTitle = title.trim(with: prefix, maxWidth: config.maxWidthOfMenuItem)
        let menuItem = NSMenuItem(title: attributedTitle.string, action: #selector(AppDelegate.selectClipMenuItem(_:)), keyEquivalent: keyEquivalent)
        menuItem.attributedTitle = attributedTitle
        menuItem.representedObject = clip.dataHash

        if config.isShowToolTip {
            let maxLengthOfToolTip = AppEnvironment.current.defaults.integer(forKey: Preferences.Menu.maxLengthOfToolTip)
            menuItem.toolTip = (originTitle as NSString).substring(to: min(originTitle.count, maxLengthOfToolTip))
        }

        let isImage = !clip.isColorCode && config.isShowImage
        let isColor = clip.isColorCode && config.isShowColorCode
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
    func trim(with prefix: String, maxWidth: CGFloat) -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: 14)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: font
        ]

        var trim = trimmingCharacters(in: .whitespacesAndNewlines)
            .replace(pattern: " *\n *", withTemplate: " ")

        trim = prefix + trim

        return trim.truncateToSize(size: .init(width: maxWidth, height: font.lineHeight * 1.2),
                                   ellipses: "...",
                                   trailingText: "",
                                   attributes: attributes,
                                   trailingAttributes: attributes)
    }
}
