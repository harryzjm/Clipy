// 
//  SMLog.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
// 
//  Created by Aphro Hares on 2020/10/26.
// 
//  Copyright © 2015-2020 Clipy Project.
//

import Foundation

let kSMLogLevel: SMLogLevel = .verbose

enum SMLogLevel: UInt {
    case verbose = 0
    case debug
    case info
    case warning
    case error
}

func lError(_ items: Any?..., separator: String = " ", terminator: String = "\n", file: StaticString = #file, function: StaticString = #function, line: UInt = #line, date: Date = Date()) {
    SMLog.shared.log(items, separator: separator, terminator: terminator, async: false, level: .error, file: file, function: function, line: line, date: date)
}

func lWarning(_ items: Any?..., separator: String = " ", terminator: String = "\n", file: StaticString = #file, function: StaticString = #function, line: UInt = #line, date: Date = Date()) {
    SMLog.shared.log(items, separator: separator, terminator: terminator, async: true, level: .warning, file: file, function: function, line: line, date: date)
}

func lInfo(_ items: Any?..., separator: String = " ", terminator: String = "\n", file: StaticString = #file, function: StaticString = #function, line: UInt = #line, date: Date = Date()) {
    SMLog.shared.log(items, separator: separator, terminator: terminator, async: true, level: .info, file: file, function: function, line: line, date: date)
}

func lDebug(_ items: Any?..., separator: String = " ", terminator: String = "\n", file: StaticString = #file, function: StaticString = #function, line: UInt = #line, date: Date = Date()) {
    SMLog.shared.log(items, separator: separator, terminator: terminator, async: true, level: .debug, file: file, function: function, line: line, date: date)
}

func lVerbose(_ items: Any?..., separator: String = " ", terminator: String = "\n", file: StaticString = #file, function: StaticString = #function, line: UInt = #line, date: Date = Date()) {
    SMLog.shared.log(items, separator: separator, terminator: terminator, async: true, level: .verbose, file: file, function: function, line: line, date: date)
}

private struct SMLog {
    static let shared = SMLog()
    let queue = DispatchQueue(label: "com.swifter.log", qos: .background)

    func log(_ items: [Any?], separator: String, terminator: String, async: Bool, level: SMLogLevel, file: StaticString, function: StaticString, line: UInt, date: Date) {
        guard check(level) else { return }
        let isMain = Thread.isMainThread

        let handle = {
            let prefix = manage(level: level, file: file, function: function, line: line, date: date, isMain: isMain)
            let content = items
                .map { $0.flatMap { "\($0)" } ?? "nil" }
                .joined(separator: separator)

            print(prefix, content, terminator: terminator)
        }

        async ? queue.async(execute: handle):handle()
    }

    func check(_ level: SMLogLevel) -> Bool {
        return kSMLogLevel <= level
    }

    func manage(level: SMLogLevel, file: StaticString, function: StaticString, line: UInt, date: Date, isMain: Bool) -> String {
        let isMainThread = isMain ? "1":"0"
        let fileName = file.description.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? ""
        let functionName = function.description.firstSubstring(pattern: "[a-z]+", options: .caseInsensitive) ?? ""
        let minute = Calendar.autoupdatingCurrent.component(.minute, from: date)
        let second = Calendar.autoupdatingCurrent.component(.second, from: date)
        let nanosecond = Calendar.autoupdatingCurrent.component(.nanosecond, from: date)
        let dateFormat = String(format: "%02d:%02d.%02d", minute, second, nanosecond / 10000000)
        return "[" + fileName + "." + functionName + ":\(line)] " +
            isMainThread + " " +
            dateFormat + " " +
            level.icon + "> "
    }
}

extension SMLogLevel: Comparable {
    static func < (lhs: SMLogLevel, rhs: SMLogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

private extension SMLogLevel {
    var icon: String {
        switch self {
        case .error: return "💥"
        case .warning: return "😱"
        case .info: return "😈"
        case .debug: return "⛄"
        case .verbose: return "🍀"
        }
    }
}
