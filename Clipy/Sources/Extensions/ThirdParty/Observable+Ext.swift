// 
//  Observable+Ext.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
// 
//  Created by hares on 2026/9/15.
// 
//  Copyright © 2015-2026 Clipy Project.
//

import Foundation
import RxSwift
import RxCocoa

extension ObservableType {
    @discardableResult
    func run(onNext: ((Element) -> Void)? = nil, onError: ((Swift.Error) -> Void)? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) -> Disposable {
        subscribe(onNext: onNext, onError: onError ?? { error in
            lError(error, file: file, function: function, line: line)
        })
    }
}

#if DEBUG
extension ObservableType {
    func adebug(_ identifier: String, file: StaticString = #file, function: StaticString = #function, line: UInt = #line)
    -> Observable<Element> {
        self.do(onNext: {
            lDebug(identifier, "next:\($0)".compact, file: file, function: function, line: line)
        }, onError: {
            lDebug(identifier, "error:\($0)".compact, file: file, function: function, line: line)
        }, onCompleted: {
            lDebug(identifier, "completed".compact, file: file, function: function, line: line)
        }, onDispose: {
            lDebug(identifier, "dispose".compact, file: file, function: function, line: line)
        })
    }

    func aWarning(_ identifier: String, file: StaticString = #file, function: StaticString = #function, line: UInt = #line)
    -> Observable<Element> {
        self.do(onNext: {
            lWarning(identifier, "next:\($0)".compact, file: file, function: function, line: line)
        }, onError: {
            lWarning(identifier, "error:\($0)".compact, file: file, function: function, line: line)
        }, onCompleted: {
            lWarning(identifier, "completed".compact, file: file, function: function, line: line)
        }, onDispose: {
            lWarning(identifier, "dispose".compact, file: file, function: function, line: line)
        })
    }
}

#endif
