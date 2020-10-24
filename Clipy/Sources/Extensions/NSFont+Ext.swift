// 
//  NSFont+Ext.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
// 
//  Created by 叶落沉香 on 2020/10/24.
// 
//  Copyright © 2015-2020 Clipy Project.
//

import Foundation
import Cocoa

extension NSFont {
    var lineHeight: CGFloat {
        return ceil(abs(ascender) + abs(descender) + abs(leading))
    }
}
