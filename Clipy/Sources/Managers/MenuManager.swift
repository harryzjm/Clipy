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
import RxCocoa
import RxSwift
import RxOptional

final class MenuManager: NSObject {
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
    // Other
    fileprivate let disposeBag = DisposeBag()
    fileprivate let shortenSymbol = "..."

    // MARK: - Enum Values
    enum StatusType: Int {
        case black, white
    }

    // MARK: - Initialize
    override init() {
        super.init()
        folderIcon.isTemplate = true
        folderIcon.size = NSSize(width: 15, height: 13)
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
        }
    }
}

// MARK: - Binding
private extension MenuManager {
    func bind() {
        // Menu icon
        AppEnvironment.current.defaults.rx.observe(Int.self, Preferences.General.statusTypeItem, retainSelf: false)
            .filterNil()
            .asDriver(onErrorDriveWith: .empty())
            .drive(onNext: { [weak self] key in
                self?.changeStatusItem(StatusType(rawValue: key) ?? .black)
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - Menus
private extension MenuManager {
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
}

// MARK: - Status Item
private extension MenuManager {
    func changeStatusItem(_ type: StatusType) {
        removeStatusItem()

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
