//
//  CPYSnippet+Store.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation

/// Compatibility shim over `ClipyBox`. See `CPYFolder+Store.swift`.
extension CPYSnippet {

    func merge() {
        let table = toTable
        AppEnvironment.current.box.snippetTransaction { try $0.snippetDb.upsertSnippet(table) }.run()
    }

    func remove() {
        let identifier = self.identifier
        AppEnvironment.current.box.snippetTransaction { try $0.removeSnippet(identifier: identifier) }.run()
    }
}
