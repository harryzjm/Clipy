//
//  LiquidGlass.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI

// Liquid Glass landed in macOS 26. The deployment target is macOS 14, so every call into those
// APIs has to be availability-gated with a material fallback that still reads correctly on 14/15.
extension View {

    /// Glass background on macOS 26, `regularMaterial` below it.
    @ViewBuilder
    func clipyGlass(in shape: some Shape = RoundedRectangle(cornerRadius: 12, style: .continuous)) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }

    /// Glass button style on macOS 26, the standard bordered style below it.
    @ViewBuilder
    func clipyGlassButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}
