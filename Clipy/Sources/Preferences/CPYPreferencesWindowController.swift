//
//  CPYPreferencesWindowController.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/02/25.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa

final class CPYPreferencesWindowController: NSWindowController {

    // MARK: - Properties
    static let sharedController = CPYPreferencesWindowController(windowNibName: NSNib.Name("CPYPreferencesWindowController"))

    @IBOutlet private weak var toolBar: NSView!
    // ImageViews
    @IBOutlet private weak var generalImageView: NSImageView!
    @IBOutlet private weak var menuImageView: NSImageView!
    @IBOutlet private weak var typeImageView: NSImageView!
    @IBOutlet private weak var excludeImageView: NSImageView!
    @IBOutlet private weak var shortcutsImageView: NSImageView!
    @IBOutlet private weak var betaImageView: NSImageView!
    // Labels
    @IBOutlet private weak var generalTextField: NSTextField!
    @IBOutlet private weak var menuTextField: NSTextField!
    @IBOutlet private weak var typeTextField: NSTextField!
    @IBOutlet private weak var excludeTextField: NSTextField!
    @IBOutlet private weak var shortcutsTextField: NSTextField!
    @IBOutlet private weak var betaTextField: NSTextField!
    // Buttons
    @IBOutlet private weak var generalButton: NSButton!
    @IBOutlet private weak var menuButton: NSButton!
    @IBOutlet private weak var typeButton: NSButton!
    @IBOutlet private weak var excludeButton: NSButton!
    @IBOutlet private weak var shortcutsButton: NSButton!
    @IBOutlet private weak var betaButton: NSButton!
    // ViewController
    private let viewController = [NSViewController(nibName: NSNib.Name("CPYGeneralPreferenceViewController"), bundle: nil),
                                      NSViewController(nibName: NSNib.Name("CPYMenuPreferenceViewController"), bundle: nil),
                                      CPYTypePreferenceViewController(nibName: NSNib.Name("CPYTypePreferenceViewController"), bundle: nil),
                                      CPYExcludeAppPreferenceViewController(nibName: NSNib.Name("CPYExcludeAppPreferenceViewController"), bundle: nil),
                                  CPYShortcutsPreferenceViewController(nibName: NSNib.Name("CPYShortcutsPreferenceViewController"), bundle: nil),
                                  CPYBetaPreferenceViewController(nibName: NSNib.Name("CPYBetaPreferenceViewController"), bundle: nil)]

    // MARK: - Window Life Cycle
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.collectionBehavior = .canJoinAllSpaces
        self.window?.titlebarAppearsTransparent = true

        toolBarItemTapped(generalButton)
        generalButton.sendAction(on: .leftMouseDown)
        menuButton.sendAction(on: .leftMouseDown)
        typeButton.sendAction(on: .leftMouseDown)
        excludeButton.sendAction(on: .leftMouseDown)
        shortcutsButton.sendAction(on: .leftMouseDown)
        betaButton.sendAction(on: .leftMouseDown)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(self)
    }
}

// MARK: - IBActions
extension CPYPreferencesWindowController {
    @IBAction private func toolBarItemTapped(_ sender: NSButton) {
        selectedTab(sender.tag)
        switchView(sender.tag)
    }
}

// MARK: - NSWindow Delegate
extension CPYPreferencesWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let viewController = viewController[2] as? CPYTypePreferenceViewController {
            AppEnvironment.current.defaults.set(viewController.storeTypes, forKey: Constants.UserDefaults.storeTypes)
            AppEnvironment.current.defaults.synchronize()
        }
        if let window = window, !window.makeFirstResponder(window) {
            window.endEditing(for: nil)
        }
        NSApp.deactivate()
    }
}

// MARK: - Layout
private extension CPYPreferencesWindowController {
    func resetImages() {
        generalImageView.image = Asset.Preference.general.image
        menuImageView.image = Asset.Preference.menu.image
        typeImageView.image = Asset.Preference.type.image
        excludeImageView.image = Asset.Preference.excluded.image
        shortcutsImageView.image = Asset.Preference.shortcut.image
        betaImageView.image = Asset.Preference.beta.image

        generalTextField.textColor = Asset.Color.tabTitle.color
        menuTextField.textColor = Asset.Color.tabTitle.color
        typeTextField.textColor = Asset.Color.tabTitle.color
        excludeTextField.textColor = Asset.Color.tabTitle.color
        shortcutsTextField.textColor = Asset.Color.tabTitle.color
        betaTextField.textColor = Asset.Color.tabTitle.color
    }

    func selectedTab(_ index: Int) {
        resetImages()

        switch index {
        case 0:
            generalImageView.image = Asset.Preference.generalOn.image
            generalTextField.textColor = Asset.Color.clipy.color
        case 1:
            menuImageView.image = Asset.Preference.menuOn.image
            menuTextField.textColor = Asset.Color.clipy.color
        case 2:
            typeImageView.image = Asset.Preference.typeOn.image
            typeTextField.textColor = Asset.Color.clipy.color
        case 3:
            excludeImageView.image = Asset.Preference.excludedOn.image
            excludeTextField.textColor = Asset.Color.clipy.color
        case 4:
            shortcutsImageView.image = Asset.Preference.shortcutOn.image
            shortcutsTextField.textColor = Asset.Color.clipy.color
        case 5:
            betaImageView.image = Asset.Preference.betaOn.image
            betaTextField.textColor = Asset.Color.clipy.color
        default: break
        }
    }

    func switchView(_ index: Int) {
        let newView = viewController[index].view
        // Remove current views without toolbar
        window?.contentView?.subviews.forEach { view in
            if view != toolBar {
                view.removeFromSuperview()
            }
        }
        // Resize view
        let frame = window!.frame
        var newFrame = window!.frameRect(forContentRect: newView.frame)
        newFrame.origin = frame.origin
        newFrame.origin.y += frame.height - newFrame.height - toolBar.frame.height
        newFrame.size.height += toolBar.frame.height
        window?.setFrame(newFrame, display: true)
        window?.contentView?.addSubview(newView)
    }
}
