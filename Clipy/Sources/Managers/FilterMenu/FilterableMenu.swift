//
//  FilterableMenu.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Foundation

/// A menu carrying a `TextFieldMenuItem` at its top.
///
/// The search field knows nothing about what it is filtering — it walks up to its enclosing menu
/// and hands over the raw text. Everything else, including whether the query hits a database or
/// an array already in memory, is the menu's business.
protocol FilterableMenu: AnyObject {
    func update(filter: String)
}
