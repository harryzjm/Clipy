//
//  MenuManager.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/03/08.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import PINCache
import RealmSwift
import RxCocoa
import RxSwift
import RxOptional

final class MenuManager: NSObject {
    fileprivate var snippetMenu: NSMenu?
    fileprivate lazy var configMenu: NSMenu = {
        let v = NSMenu(title: Constants.Menu.config)
        v.addItem(.init(title: L10n.clearHistory, action: #selector(AppDelegate.clearAllHistory)))
        v.addItem(.init(title: L10n.preferences, action: #selector(AppDelegate.showPreferenceWindow)))
        v.addItem(.separator())
        v.addItem(.init(title: L10n.restartClipy, action: #selector(AppDelegate.restart)))
        v.addItem(.init(title: L10n.quitClipy, action: #selector(AppDelegate.terminate)))
        return v
    }()

    // StatusMenu
    fileprivate var statusItem: NSStatusItem?
    // Icon Cache
    fileprivate let folderIcon = Asset.Common.iconFolder.image
    fileprivate let snippetIcon = Asset.Common.iconText.image
    // Other
    fileprivate let disposeBag = DisposeBag()
    fileprivate let notificationCenter = NotificationCenter.default
    fileprivate let kMaxKeyEquivalents = 10
    fileprivate let shortenSymbol = "..."
    // Realm
    fileprivate let realm = try! Realm()
    fileprivate var clipToken: NotificationToken?
    fileprivate var snippetToken: NotificationToken?

    // MARK: - Enum Values
    enum StatusType: Int {
        case black, white
    }

    // MARK: - Initialize
    override init() {
        super.init()
        folderIcon.isTemplate = true
        folderIcon.size = NSSize(width: 15, height: 13)
        snippetIcon.isTemplate = true
        snippetIcon.size = NSSize(width: 12, height: 13)
    }

    func setup() {
        bind()
    }

}

// MARK: - Popup Menu
extension MenuManager {
    func popUpMenu(_ type: MenuType) {
        switch type {
        case .history:
            let current = statusItem?.button?.window?.frame.origin
            let pt = current.flatMap { pt -> CGPoint in
                let mouse = NSEvent.mouseLocation
                return NSPoint(x: mouse.x - pt.x, y: pt.y - mouse.y)
            }
            FilterMenu(title: L10n.history).popUp(positioning: nil, at: pt ?? .zero, in: statusItem?.button)
        case .snippet:
            snippetMenu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }

    func popUpSnippetFolder(_ folder: CPYFolder) {
        let folderMenu = NSMenu(title: folder.title)
        // Folder title
        let labelItem = NSMenuItem(title: folder.title, action: nil)
        labelItem.isEnabled = false
        folderMenu.addItem(labelItem)
        // Snippets
        var index = firstIndexOfMenuItems()
        folder.snippets
            .sorted(byKeyPath: #keyPath(CPYSnippet.index), ascending: true)
            .filter { $0.enable }
            .forEach { snippet in
                let subMenuItem = makeSnippetMenuItem(snippet, listNumber: index)
                folderMenu.addItem(subMenuItem)
                index += 1
            }
        folderMenu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}

// MARK: - Binding
private extension MenuManager {
    func bind() {
        // Realm Notification
        clipToken = realm.objects(CPYClip.self)
                        .observe { [weak self] _ in
                            DispatchQueue.main.async { [weak self] in
                                self?.createClipMenu()
                            }
                        }
        snippetToken = realm.objects(CPYFolder.self)
                        .observe { [weak self] _ in
                            DispatchQueue.main.async { [weak self] in
                                self?.createClipMenu()
                            }
                        }
        // Menu icon
        AppEnvironment.current.defaults.rx.observe(Int.self, Preferences.General.statusTypeItem, retainSelf: false)
            .filterNil()
            .asDriver(onErrorDriveWith: .empty())
            .drive(onNext: { [weak self] key in
                self?.changeStatusItem(StatusType(rawValue: key) ?? .black)
            })
            .disposed(by: disposeBag)

        // Edit snippets
        notificationCenter.rx.notification(Notification.Name(rawValue: Constants.Notification.closeSnippetEditor))
            .asDriver(onErrorDriveWith: .empty())
            .drive(onNext: { [weak self] _ in
                self?.createClipMenu()
            })
            .disposed(by: disposeBag)
        // Observe change preference settings
        let defaults = AppEnvironment.current.defaults
        Observable.merge(
            defaults.rx.observe(Int.self, Preferences.General.reorderClipsAfterPasting, options: [.new], retainSelf: false).filterNil().mapVoidDistinctUntilChanged(),
            defaults.rx.observe(Int.self, Preferences.General.maxShowHistorySize, options: [.new], retainSelf: false).filterNil().mapVoidDistinctUntilChanged(),
            defaults.rx.observe(Int.self, Preferences.General.maxHistorySize, options: [.new], retainSelf: false).filterNil().mapVoidDistinctUntilChanged(),
            defaults.rx.observe(Int.self, Preferences.General.maxWidthOfMenuItem, options: [.new], retainSelf: false).filterNil().mapVoidDistinctUntilChanged(),
            defaults.rx.observe(Bool.self, Preferences.Menu.showIconInTheMenu, options: [.new], retainSelf: false).filterNil().mapVoidDistinctUntilChanged(),
            defaults.rx.observe(Int.self, Preferences.Menu.numberOfItemsPlaceInline, options: [.new], retainSelf: false).filterNil().mapVoidDistinctUntilChanged(),
            defaults.rx.observe(Int.self, Preferences.Menu.numberOfItemsPlaceInsideFolder, options: [.new], retainSelf: false).filterNil().mapVoidDistinctUntilChanged(),
            defaults.rx.observe(Bool.self, Preferences.Menu.menuItemsAreMarkedWithNumbers, options: [.new], retainSelf: false).filterNil().mapVoidDistinctUntilChanged(),
            defaults.rx.observe(Bool.self, Preferences.Menu.showToolTipOnMenuItem, options: [.new], retainSelf: false).filterNil().mapVoidDistinctUntilChanged(),
            defaults.rx.observe(Bool.self, Preferences.Menu.showImageInTheMenu, options: [.new], retainSelf: false).filterNil().mapVoidDistinctUntilChanged(),
            defaults.rx.observe(Bool.self, Preferences.Menu.addNumericKeyEquivalents, options: [.new], retainSelf: false).filterNil().mapVoidDistinctUntilChanged(),
            defaults.rx.observe(Int.self, Preferences.Menu.maxLengthOfToolTip, options: [.new], retainSelf: false).filterNil().mapVoidDistinctUntilChanged(),
            defaults.rx.observe(Bool.self, Preferences.Menu.showColorPreviewInTheMenu, options: [.new], retainSelf: false).filterNil().mapVoidDistinctUntilChanged())
            .skip(1)
            .throttle(.seconds(1), scheduler: MainScheduler.instance)
            .asDriver(onErrorDriveWith: .empty())
            .drive(onNext: { [weak self] in
                self?.createClipMenu()
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - Menus
private extension MenuManager {
     func createClipMenu() {
        snippetMenu = NSMenu(title: Constants.Menu.snippet)

        addSnippetItems(snippetMenu!, separateMenu: false)
    }

    func menuItemTitle(_ title: String, listNumber: NSInteger, isMarkWithNumber: Bool) -> String {
        return (isMarkWithNumber) ? "\(listNumber). \(title)" : title
    }

    func makeSubmenuItem(_ count: Int, start: Int, end: Int, numberOfItems: Int) -> NSMenuItem {
        var count = count
        if start == 0 {
            count -= 1
        }
        var lastNumber = count + numberOfItems
        if end < lastNumber {
            lastNumber = end
        }
        let menuItemTitle = "\(count + 1) - \(lastNumber)"
        return makeSubmenuItem(menuItemTitle)
    }

    func makeSubmenuItem(_ title: String) -> NSMenuItem {
        let subMenu = NSMenu(title: "")
        let subMenuItem = NSMenuItem(title: title, action: nil)
        subMenuItem.submenu = subMenu
        subMenuItem.image = (AppEnvironment.current.defaults.bool(forKey: Preferences.Menu.showIconInTheMenu)) ? folderIcon : nil
        return subMenuItem
    }

    func trimTitle(_ title: String?) -> String {
        if title == nil { return "" }
        let theString = title!.trimmingCharacters(in: .whitespacesAndNewlines) as NSString

        let aRange = NSRange(location: 0, length: 0)
        var lineStart = 0, lineEnd = 0, contentsEnd = 0
        theString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: aRange)

        var titleString = (lineEnd == theString.length) ? theString as String : theString.substring(to: contentsEnd)

        var maxMenuItemTitleLength = 20
        if maxMenuItemTitleLength < shortenSymbol.count {
            maxMenuItemTitleLength = shortenSymbol.count
        }

        if titleString.utf16.count > maxMenuItemTitleLength {
            titleString = (titleString as NSString).substring(to: maxMenuItemTitleLength - shortenSymbol.count) + shortenSymbol
        }

        return titleString as String
    }
}

// MARK: - Snippets
private extension MenuManager {
    func addSnippetItems(_ menu: NSMenu, separateMenu: Bool) {
        let folderResults = realm.objects(CPYFolder.self).sorted(byKeyPath: #keyPath(CPYFolder.index), ascending: true)
        guard !folderResults.isEmpty else { return }
        if separateMenu {
            menu.addItem(NSMenuItem.separator())
        }

        // Snippet title
        let labelItem = NSMenuItem(title: L10n.snippet, action: nil)
        labelItem.isEnabled = false
        menu.addItem(labelItem)

        var subMenuIndex = menu.numberOfItems - 1
        let firstIndex = firstIndexOfMenuItems()

        folderResults
            .filter { $0.enable }
            .forEach { folder in
                let folderTitle = folder.title
                let subMenuItem = makeSubmenuItem(folderTitle)
                menu.addItem(subMenuItem)
                subMenuIndex += 1

                var i = firstIndex
                folder.snippets
                    .sorted(byKeyPath: #keyPath(CPYSnippet.index), ascending: true)
                    .filter { $0.enable }
                    .forEach { snippet in
                        let subMenuItem = makeSnippetMenuItem(snippet, listNumber: i)
                        if let subMenu = menu.item(at: subMenuIndex)?.submenu {
                            subMenu.addItem(subMenuItem)
                            i += 1
                        }
                    }
            }
    }

    func makeSnippetMenuItem(_ snippet: CPYSnippet, listNumber: Int) -> NSMenuItem {
        let isMarkWithNumber = AppEnvironment.current.defaults.bool(forKey: Preferences.Menu.menuItemsAreMarkedWithNumbers)
        let isShowIcon = AppEnvironment.current.defaults.bool(forKey: Preferences.Menu.showIconInTheMenu)

        let title = trimTitle(snippet.title)
        let titleWithMark = menuItemTitle(title, listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)

        let menuItem = NSMenuItem(title: titleWithMark, action: #selector(AppDelegate.selectSnippetMenuItem(_:)), keyEquivalent: "")
        menuItem.representedObject = snippet.identifier
        menuItem.toolTip = snippet.content
        menuItem.image = (isShowIcon) ? snippetIcon : nil

        return menuItem
    }
}

// MARK: - Status Item
private extension MenuManager {
    func changeStatusItem(_ type: StatusType) {
        removeStatusItem()
        if type == .none { return }

        let image: NSImage?
        switch type {
        case .black:
            image = Asset.StatusIcon.statusbarMenuBlack.image
        case .white:
            image = Asset.StatusIcon.statusbarMenuWhite.image
        }
        image?.isTemplate = true

        statusItem = NSStatusBar.system.statusItem(withLength: -1)
        statusItem?.button?.image = image
        let cell = statusItem?.button?.cell as? NSButtonCell
        cell?.highlightsBy = [.contentsCellMask, .changeBackgroundCellMask]
        statusItem?.button?.toolTip = "\(Constants.Application.name) \(Bundle.main.appVersion ?? "")"
        statusItem?.menu = configMenu
    }

    func removeStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }
}

// MARK: - Settings
private extension MenuManager {
    func firstIndexOfMenuItems() -> NSInteger {
        return  1
    }
}
