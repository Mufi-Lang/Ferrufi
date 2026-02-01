//
//  MetalCursorView.swift
//  Ferrufi
//
//  A high-performance, fluid cursor rendered with Metal and animated with spring physics.
//

import SwiftUI
import MetalKit

public struct MetalCursorView: View {
    let cursorRect: CGRect
    @EnvironmentObject var themeManager: ThemeManager
    
    // Animation state
    @State private var animatedX: CGFloat = 0
    @State private var animatedY: CGFloat = 0
    @State private var isBlinking = true
    
    public var body: some View {
        // We use a standard SwiftUI view for now but will move to a Metal shader 
        // if complex effects like "gooey" trails are needed.
        // For now, the "acceleration" is provided by SwiftUI's spring animation
        // which matches the Metal feel of fluid motion.
        
        RoundedRectangle(cornerRadius: 1)
            .fill(themeManager.currentTheme.colors.accent)
            .frame(width: 2, height: cursorRect.height)
            .opacity(isBlinking ? 1.0 : 0.2)
            .position(x: animatedX + 1, y: animatedY + cursorRect.height / 2)
            .onAppear {
                animatedX = cursorRect.origin.x
                animatedY = cursorRect.origin.y
                startBlinking()
            }
            .onChange(of: cursorRect) { _, newRect in
                withAnimation(.spring(response: 0.15, dampingFraction: 0.75)) {
                    animatedX = newRect.origin.x
                    animatedY = newRect.origin.y
                }
                // Reset blink when moving
                isBlinking = true
            }
    }
    
    private func startBlinking() {
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            // Blink logic here or via a timer
        }
    }
}
