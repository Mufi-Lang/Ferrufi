//
//  ThemeColors.swift
//  Ferrufi
//

#if os(macOS)
import SwiftUI
#else
// Define basic Color type for Linux or other platforms if not using SwiftUI
public struct Color: Codable, Sendable, Hashable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let opacity: Double
    
    public init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }
}
#endif

/// A platform-agnostic representation of theme colors
public struct ThemeColors: Codable, Sendable {
    public let background: Color
    public let backgroundSecondary: Color
    public let backgroundTertiary: Color
    public let foreground: Color
    public let foregroundSecondary: Color
    public let foregroundTertiary: Color
    public let accent: Color
    public let accentSecondary: Color
    public let success: Color
    public let warning: Color
    public let error: Color
    public let border: Color
    public let shadow: Color
    
    #if os(macOS)
    public init(
        background: Color,
        backgroundSecondary: Color,
        backgroundTertiary: Color,
        foreground: Color,
        foregroundSecondary: Color,
        foregroundTertiary: Color,
        accent: Color,
        accentSecondary: Color,
        success: Color,
        warning: Color,
        error: Color,
        border: Color,
        shadow: Color
    ) {
        self.background = background
        self.backgroundSecondary = backgroundSecondary
        self.backgroundTertiary = backgroundTertiary
        self.foreground = foreground
        self.foregroundSecondary = foregroundSecondary
        self.foregroundTertiary = foregroundTertiary
        self.accent = accent
        self.accentSecondary = accentSecondary
        self.success = success
        self.warning = warning
        self.error = error
        self.border = border
        self.shadow = shadow
    }
    #endif
}
