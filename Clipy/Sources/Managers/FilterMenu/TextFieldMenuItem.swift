//
//  TextFieldMenuItem.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
// 
//  Created by Aphro Hares on 2020/10/22.
// 
//  Copyright © 2015-2020 Clipy Project.
//

import Foundation
import Cocoa
import Carbon

class TextFieldContentView: NSView, NSTextFieldDelegate {
    var title: String {
        get { titleTF.stringValue }
        set { titleTF.stringValue = newValue }
    }

    private lazy var eventMonitor = RunLoopLocalEventMonitor(runLoopMode: .eventTracking) { event in
        if self.processInterceptedEvent(event) {
          return nil
        } else {
          return event
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        autoresizingMask = .width
        addSubview(titleTF)

        queryTF.delegate = self
        addSubview(queryTF)

        let views = ["title": titleTF, "query": queryTF]
        addConstraints(NSLayoutConstraint.constraints(
                        withVisualFormat: "|-(==21)-[title]-[query]-(==10)-|",
                        options: [], metrics: nil, views: views))

        addConstraints(NSLayoutConstraint.constraints(
                        withVisualFormat: "V:|[title]-(==1)-|",
                        options: [], metrics: nil, views: views))

        addConstraints(NSLayoutConstraint.constraints(
                        withVisualFormat: "V:|[query]-(==1)-|",
                        options: [], metrics: nil, views: views))
    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if let _ = window {
            eventMonitor.start()
        } else {
            eventMonitor.stop()
        }
    }

    func processInterceptedEvent(_ event: NSEvent) -> Bool {
        let first = window?.firstResponder

        guard
            first != queryTF,
            first != queryTF.currentEditor(),
            event.type == .keyDown,
            !shouldPassthru(keyCode: event.keyCode),
            !event.modifierFlags.contains(.control)
        else { return false }

        var query = queryTF.stringValue

        if event.modifierFlags.contains(.option) || event.modifierFlags.contains(.command) {
            guard event.keyCode == 51 else { return false }
            set(query: "")
            return true
        }

        if event.keyCode == 51 {
            if !query.isEmpty {
                query.removeLast()
                set(query: query)
            }
            return true
        }

        if let chars = event.charactersIgnoringModifiers, chars.count == 1 {
            query.append(chars)
            set(query: query)
            return true
        }

        return false
    }

    func set(query: String) {
        guard query != queryTF.stringValue else { return }

        queryTF.stringValue = query

        RunLoop.current.perform(#selector(fireNotification), target: self, argument: nil, order: 0, modes: [.eventTracking])

        updateVisibility()
    }

    @objc func fireNotification() {
        guard let menu = enclosingMenuItem?.menu as? FilterMenu else { return }
        menu.update(filter: queryTF.stringValue)
    }

    func updateVisibility() {
        queryTF.isHidden = queryTF.stringValue.isEmpty
    }

    func shouldPassthru(keyCode: UInt16) -> Bool {
        let table: [UInt16: String] =
            [115: "Home", 117: "Delete", 116: "PgUp", 119: "End",
             121: "PgDn", 123: "Left", 124: "Right", 125: "Down",
             126: "Up", 49: "Space", 36: "Return", 53: "Esc",
             71: "Clear", 76: "Insert", 48: "Tab", 114: "Help",
             122: "F1", 120: "F2", 99: "F3", 118: "F4",
             96: "F5", 97: "F6", 98: "F7", 100: "F8",
             101: "F9", 109: "F10", 103: "F11", 111: "F12",
             105: "F13", 107: "F14", 113: "F15", 106: "F16",
             64: "F17", 79: "F18", 80: "F19"]
        return keyCode > 256 || table[keyCode] != nil
    }

    func controlTextDidChange(_ obj: Notification) {
        updateVisibility()
        fireNotification()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertTab(_:)) {
            window?.makeFirstResponder(window)
            return true
        }
        return false
    }

    lazy var titleTF: NSTextField = {
        let v = NSTextField()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.stringValue = ""
        v.isBordered = false
        v.isEditable = false
        v.isEnabled = false
        v.cell?.usesSingleLineMode = true
        v.drawsBackground = false
        v.font = .menuFont(ofSize: 13)
        v.textColor = .tertiaryLabelColor
        return v
    }()

    lazy var queryTF: NSTextField = {
        let v = NSTextField()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.stringValue = ""
        v.isEditable = true
        v.isEnabled = true
        v.cell?.usesSingleLineMode = true
        v.cell?.lineBreakMode = .byTruncatingHead
        v.isBordered = true
        v.isBezeled = true
        v.bezelStyle = .roundedBezel
        v.font = .menuFont(ofSize: 13)
        v.isHidden = true
        return v
    }()
}

class TextFieldMenuItem: NSMenuItem {
    let content: TextFieldContentView

    override init(title string: String, action selector: Selector?, keyEquivalent charCode: String) {
        content = TextFieldContentView(frame: .init(x: 0, y: 0, width: 220, height: 21))
        content.title = string
        super.init(title: string, action: selector, keyEquivalent: charCode)
        title = content.title
        view = content
    }

    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
