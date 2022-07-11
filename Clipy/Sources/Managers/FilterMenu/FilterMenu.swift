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
    
    let homePath = FileManager.default.homeDirectoryForCurrentUser.absoluteString.replace(pattern: "^file://", withTemplate: "")

    override init(title: String) {
        config = FilterMenuConfig.current()
        item = TextFieldMenuItem(title: title, action: nil)

        super.init(title: title)

        addItem(item)

        let ascending = !AppEnvironment.current.defaults.bool(forKey: Preferences.General.reorderClipsAfterPasting)
        let clipResults = realm
            .objects(CPYClip.self)
            .sorted(byKeyPath: #keyPath(CPYClip.updateTime), ascending: ascending)

        filterRelay
            .distinctUntilChanged()
            .map { [weak self]filter -> [NSMenuItem]? in
                guard let self = self else { return nil }
                var filterRes = clipResults
                if filter.isNotEmpty {
                    lError(filter)
                    let predicate = NSPredicate(format: "title LIKE[c] %@", "*" + filter + "*")
                    filterRes = filterRes.filter(predicate)
                }
                return self.manageItems(filterRes, with: filter)
            }
            .filterNil()
            .catchAndReturn([])
            .observe(on: ConcurrentMainScheduler.instance)
            .subscribe { [weak self]event in
                guard let self = self, case .next(var new) = event else { return }
                self.highlight(menuItem: nil)
                new.insert(self.item, at: 0)
                self.items = new
                if new.count > 1 {
                    self.highlight(menuItem: new[1])
                }
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
}

// MARK: - NSMenuItem
fileprivate extension FilterMenu {
    func manageItems(_ clipResults: Results<CPYClip>, with filter: String) -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        let totalCount = min(clipResults.count, config.maxHistory)
        let remain = max(totalCount - config.placeInLine, 0)
        items += clipResults[0..<totalCount - remain]
            .enumerated()
            .map { obj in
                return self.item(with: obj.element, index: obj.offset + 1, filter: filter, inline: true)
            }

        let res = remain.quotientAndRemainder(dividingBy: config.placeInsideFolder)
        items += (0 ..< res.quotient).map { i -> NSMenuItem in
            let begin = config.placeInLine + config.placeInsideFolder * i
            let end = begin + self.config.placeInsideFolder
            return item(begin: begin, end: end, filter: filter) { clipResults[$0] }
        }

        if res.remainder > 0 {
            let begin = config.placeInLine + config.placeInsideFolder * res.quotient
            let end = begin + res.remainder

            items.append(item(begin: begin, end: end, filter: filter) { clipResults[$0] })
        }
        return items
    }

    func item(begin: Int, end: Int, filter: String, clipHandle: (Int) -> CPYClip?) -> NSMenuItem {
        let font = NSFont.boldSystemFont(ofSize: config.menuFontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: font
        ]

        let subMenu = NSMenu(title: "")
        let menuItem = NSMenuItem(title: "\(begin + 1) - \(end)", action: nil)
        menuItem.attributedTitle = .init(string: menuItem.title, attributes: attributes)
        menuItem.submenu = subMenu
        menuItem.image = self.config.showIconInTheMenu ? Asset.Common.iconFolder.image : nil

        (begin ..< end).forEach { i in
            guard let clip = clipHandle(i) else { return }
            subMenu.addItem(item(with: clip, index: i + 1, filter: filter, inline: false))
        }
        return menuItem
    }

    func item(with clip: CPYClip, index: Int, filter: String, inline: Bool) -> NSMenuItem {
        let maxKeyEquivalent = 10

        let keyEquivalent: String = {
            guard inline && config.addNumericKeyEquivalents else { return "" }
            switch index {
            case 1 ..< maxKeyEquivalent: return "\(index). "
            case maxKeyEquivalent: return "0. "
            default: return ""
            }
        }()

        let primaryPboardType = NSPasteboard.PasteboardType(rawValue: clip.primaryType)
        let prefix = inline && config.isMarkWithNumber && keyEquivalent.isNotEmpty ? keyEquivalent:""
        var originTitle = clip.title

        let title = { () -> String in
            switch primaryPboardType {
            case .png: return "[Image] " + clip.title
            case .tiff: return "[Image] " + clip.title
            case .pdf: return "[PDF] " + clip.title
            case .fileURL:
                originTitle = originTitle.removingPercentEncoding ?? originTitle
                let str = clip.title
                    .replace(pattern: "^file://", withTemplate: "")
                    .replace(pattern: "^\(homePath)", withTemplate: "~/")
                    .removingPercentEncoding ?? ""
                return "[File] " +  str
            default: return clip.title
            }
        }()
        let attributedTitle = title.trim(with: prefix, keyWord: filter, maxWidth: config.maxWidthOfMenuItem, fontSize: config.menuFontSize)
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
                menuItem?.image = object as? NSImage
            }
        }

        return menuItem
    }
}

// MARK: - Extension
fileprivate extension String {
    func trim(with prefix: String, keyWord: String, maxWidth: CGFloat, fontSize: CGFloat) -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: font
        ]

        let keyAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.red,
            .font: font
        ]

        let trim = replace(pattern: " *\n *", withTemplate: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let prefixWidth = prefix.sizeOf(attributes: attributes).width
        let att = NSMutableAttributedString(string: prefix, attributes: attributes)
        let content = trim.truncateToSize(size: .init(width: maxWidth - prefixWidth, height: ceil(font.lineHeight * 1.2)), ellipsis: "...", keyWord: keyWord, attributes: attributes, keyWordAttributes: keyAttributes)
        att.append(content)
        return att
    }
}
