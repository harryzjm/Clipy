// 
//  NSColor+Ext.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
// 
//  Created by Hares on 8/11/23.
// 
//  Copyright © 2015-2023 Clipy Project.
//

import Foundation
import Cocoa

extension NSColor {
    convenience init?(hexString: String, alpha: CGFloat = 1) {
        guard let hexVal = Int64(hexString, radix: 16) else {
            return nil
        }

        let containAlpha = hexString.count > 6;
        let alphaHex = containAlpha ? 8:0;

        self.init(red:   CGFloat( (hexVal >> (16 + alphaHex)) & 0xFF ) / 255.0,
                  green: CGFloat( (hexVal >> (8 + alphaHex)) & 0xFF ) / 255.0,
                  blue:  CGFloat( (hexVal >> (0 + alphaHex)) & 0xFF ) / 255.0,
                  alpha: containAlpha ? CGFloat( hexVal & 0xFF ):alpha)
    }
}
