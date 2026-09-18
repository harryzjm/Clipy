// 
//  Sequence+Ext.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
// 
//  Created by hares on 2026/9/18.
// 
//  Copyright © 2015-2026 Clipy Project.
//

import Foundation

extension Sequence {
    public func firstMap<ElementOfResult>(_ transform: (Element) throws -> ElementOfResult?) rethrows -> ElementOfResult? {
        for item in self {
            if let res = try transform(item) {
                return res
            }
        }
        return nil
    }
}
