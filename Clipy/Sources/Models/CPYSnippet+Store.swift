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

    func merge(in box: ClipyBox) {
        let table = toTable
        box.snippetTransaction { try $0.snippetDb.upsertSnippet(table) }.run()
    }

    func remove(in box: ClipyBox) {
        let identifier = self.identifier
        box.snippetTransaction { try $0.removeSnippet(identifier: identifier) }.run()
    }
}
