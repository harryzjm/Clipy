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
        v.addItem(.init(title: L10n.Common.clearHistory, action: #selector(AppDelegate.clearAllHistory)))
        v.addItem(.init(title: L10n.Menu.clearSnippets, action: #selector(AppDelegate.deleteAllSnippets)))
        v.addItem(.init(title: L10n.Menu.preferences, action: #selector(AppDelegate.showPreferenceWindow)))
        v.addItem(.init(title: L10n.Menu.snippets, action: #selector(AppDelegate.showSnippetEditorWindow)))
        v.addItem(.separator())
        v.addItem(.init(title: L10n.Menu.restart, action: #selector(AppDelegate.restart)))
        v.addItem(.init(title: L10n.Menu.quit, action: #selector(AppDelegate.terminate)))
        return v
    }()

    // StatusMenu
    fileprivate var statusItem: NSStatusItem?
    // Other
    fileprivate let disposeBag = DisposeBag()
    fileprivate let box: ClipyBox

    fileprivate let snippetPopUp = SerialDisposable()
    fileprivate var isPresentingMenu = false

    // MARK: - Enum Values
    enum StatusType: Int {
        case black, white
    }

    // MARK: - Initialize
    init(box: ClipyBox) {
        self.box = box
        super.init()
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
            present(FilterMenu(title: L10n.Menu.historyTitle, box: box))
        case .snippet:
            snippetPopUp.disposable = SnippetMenu.build(box: box)
                .subscribe(onNext: { [weak self] menu in
                    self?.present(menu)
                }, onError: { error in
                    lError("Cannot fetch snippet folders", error)
                })
        }
    }

    func popUpSnippetFolder(_ folder: CPYFolder) {
        SnippetMenu(folder: folder).popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}

// MARK: - Presenting
private extension MenuManager {
    func present(_ menu: NSMenu) {
        guard !isPresentingMenu else { return }
        isPresentingMenu = true
        // `popUp` is synchronous: it runs the menu's tracking loop and returns once dismissed.
        defer { isPresentingMenu = false }
        menu.popUp(positioning: nil, at: popUpLocation(), in: statusItem?.button)
    }

    /// The mouse, in the status item button's coordinate space. Both reads are main thread only,
    /// which is why this happens here rather than before the snippet read.
    func popUpLocation() -> CGPoint {
        guard let origin = statusItem?.button?.window?.frame.origin else { return .zero }
        let mouse = NSEvent.mouseLocation
        return NSPoint(x: mouse.x - origin.x, y: origin.y - mouse.y)
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

// MARK: - Status Item
private extension MenuManager {
    func changeStatusItem(_ type: StatusType) {
        removeStatusItem()

        let image: NSImage?
        switch type {
        case .black:
            image = Asset.StatusIcon.menuBlack.image
        case .white:
            image = Asset.StatusIcon.menuWhite.image
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
