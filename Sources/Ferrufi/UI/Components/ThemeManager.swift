//
//  ThemeManager.swift
//  Ferrufi
//
//  Sophisticated theme system inspired by Ghostty with beautiful color palettes
//

import AppKit
import Combine
import CoreText
import Foundation
import SwiftUI

/// Manages beautiful themes with carefully crafted color palettes
@MainActor
public class ThemeManager: ObservableObject {
    /// The shared singleton instance
    public static let shared = ThemeManager()

    // MARK: - Published Properties

    @Published public var currentTheme: IronTheme = .ghostWhite
    @Published public var fontSize: FontSize = .medium
    @Published public var lineSpacing: LineSpacing = .comfortable
    @Published public var cornerRadius: CornerRadius = .medium
    @Published public var animationSpeed: AnimationSpeed = .normal

    // Editor font settings (user-configurable)
    @Published public var editorFontName: String = "Menlo"
    @Published public var editorFontSize: Double = 14.0

    // STRICT MODE: enforce monospaced fonts in the editor (global).
    // When `enforceMonospacedEditorFonts` is true, the editor will always use a
    // monospaced font; if `forcedMonospacedEditorFontName` is set and available
    // it will be used, otherwise the system monospaced font is used.
    @Published public var enforceMonospacedEditorFonts: Bool = true
    @Published public var forcedMonospacedEditorFontName: String? = nil

    // Canonical monospaced font resolution and helpers
    //
    // This centralizes monospaced font selection into one canonical "resolved" name,
    // and provides NSFont / Font helpers that always use that resolved name.
    // Behavior:
    // - If strict mode is enabled and a forced font name is provided and available,
    //   it will be used.
    // - Otherwise, if the configured editor font is available and appears monospaced,
    //   it will be used.
    // - Otherwise fallback to the system monospaced font.
    public var resolvedMonospacedFontName: String {
        // 1) strict forced name wins if enabled and available
        if enforceMonospacedEditorFonts, let forced = forcedMonospacedEditorFontName,
            NSFont(name: forced, size: CGFloat(editorFontSize)) != nil
        {
            return forced
        }

        // 2) use configured editor font if it appears monospaced (heuristic)
        if let custom = NSFont(name: editorFontName, size: CGFloat(editorFontSize)) {
            let narrow = ("i" as NSString).size(withAttributes: [.font: custom]).width
            let wide = ("W" as NSString).size(withAttributes: [.font: custom]).width
            if abs(narrow - wide) < 0.5 {
                return custom.fontName
            }
        }

        // 3) fallback to system monospaced font name
        return NSFont.monospacedSystemFont(ofSize: CGFloat(editorFontSize), weight: .regular)
            .fontName
    }

    /// Returns an NSFont using the canonical monospaced name at the requested size,
    /// falling back to the system monospaced font if the named font is missing.
    public func resolvedMonospacedNSFont(ofSize size: CGFloat) -> NSFont {
        if let f = NSFont(name: resolvedMonospacedFontName, size: size) {
            return f
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// Returns a SwiftUI Font using the canonical monospaced name at the requested size,
    /// falling back to the system monospaced font if the named font is missing.
    public func resolvedMonospacedFont(ofSize size: CGFloat) -> Font {
        if NSFont(name: resolvedMonospacedFontName, size: size) != nil {
            return Font.custom(resolvedMonospacedFontName, size: size)
        }
        return Font.system(size: size, design: .monospaced)
    }

    // Core helpers used across the UI:
    public var monospacedNSFont: NSFont {
        resolvedMonospacedNSFont(ofSize: CGFloat(editorFontSize))
    }
    public var monospacedFont: Font { resolvedMonospacedFont(ofSize: CGFloat(editorFontSize)) }

    // Common style helpers (headline/caption) that use the same canonical font family
    public var monospacedHeadline: Font {
        resolvedMonospacedFont(ofSize: CGFloat(editorFontSize + 2))
    }
    public var monospacedCaption: Font {
        resolvedMonospacedFont(ofSize: max(CGFloat(editorFontSize) - 2, 10))
    }

    // Convenience for arbitrary sizes
    public func monospacedFont(ofSize size: CGFloat) -> Font {
        resolvedMonospacedFont(ofSize: size)
    }
    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard

    // UserDefaults keys
    private enum Keys {
        static let theme = "Ferrufi.selectedTheme"
        static let fontSize = "Ferrufi.fontSize"
        static let lineSpacing = "Ferrufi.lineSpacing"
        static let cornerRadius = "Ferrufi.cornerRadius"
        static let animationSpeed = "Ferrufi.animationSpeed"

        // Editor font keys
        static let editorFontName = "Ferrufi.editorFontName"
        static let editorFontSize = "Ferrufi.editorFontSize"
    }

    // MARK: - Initialization

    public init() {
        // Migrate any legacy editor settings first, then load and bind current settings
        migrateLegacyEditorSettings()
        loadSettings()

        // Ensure strict enforcement uses a guaranteed monospaced system font by default
        // if enforcement is enabled and no explicit forced font name was set yet.
        if enforceMonospacedEditorFonts, forcedMonospacedEditorFontName == nil {
            forcedMonospacedEditorFontName =
                NSFont.monospacedSystemFont(ofSize: CGFloat(editorFontSize), weight: .regular)
                .fontName
        }

        setupBindings()
    }

    // MARK: - Public Methods

    public func setTheme(_ theme: IronTheme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
        }
        saveSettings()
    }

    public func setFontSize(_ size: FontSize) {
        fontSize = size
        saveSettings()
    }

    public func setLineSpacing(_ spacing: LineSpacing) {
        lineSpacing = spacing
        saveSettings()
    }

    public func setCornerRadius(_ radius: CornerRadius) {
        withAnimation(.easeInOut(duration: 0.2)) {
            cornerRadius = radius
        }
        saveSettings()
    }

    public func setAnimationSpeed(_ speed: AnimationSpeed) {
        animationSpeed = speed
        saveSettings()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        Publishers.CombineLatest4(
            $currentTheme,
            $fontSize,
            $lineSpacing,
            Publishers.CombineLatest($cornerRadius, $animationSpeed)
        )
        .dropFirst()
        .sink { [weak self] _ in
            self?.saveSettings()
        }
        .store(in: &cancellables)

        // Persist editor font changes as well and update syntax-highlighter fonts.
        Publishers.CombineLatest($editorFontName, $editorFontSize)
            .dropFirst()
            .sink { [weak self] name, size in
                self?.saveSettings()

                // Debug: report how the configured editor font resolves to a monospaced font
                // If the configured font exists and appears monospaced (heuristic: compare 'i' and 'W' advance widths),
                // we will use it; otherwise we fall back to the system monospaced font and log that decision.
                if let customFont = NSFont(name: name, size: CGFloat(size)) {
                    let wI = ("i" as NSString).size(withAttributes: [.font: customFont]).width
                    let wW = ("W" as NSString).size(withAttributes: [.font: customFont]).width
                    if abs(wI - wW) < 0.5 {
                        print(
                            "ThemeManager: editor font '\(name)' @ \(size) detected as monospaced — using '\(customFont.fontName)' @ \(customFont.pointSize)"
                        )
                    } else {
                        let fallback = NSFont.monospacedSystemFont(
                            ofSize: CGFloat(size), weight: .regular)
                        print(
                            "ThemeManager: editor font '\(name)' @ \(size) is NOT monospaced — falling back to system monospaced '\(fallback.fontName)' @ \(fallback.pointSize)"
                        )
                    }
                } else {
                    let fallback = NSFont.monospacedSystemFont(
                        ofSize: CGFloat(size), weight: .regular)
                    print(
                        "ThemeManager: editor font '\(name)' @ \(size) not found — falling back to system monospaced '\(fallback.fontName)' @ \(fallback.pointSize)"
                    )
                }
            }
            .store(in: &cancellables)

        // Initialize highlighter fonts from current settings so editors/highlighters are unified on startup
    }

    private func loadSettings() {
        if let themeRawValue = userDefaults.string(forKey: Keys.theme),
            let theme = IronTheme(rawValue: themeRawValue)
        {
            currentTheme = theme
        }

        if let fontSizeRawValue = userDefaults.string(forKey: Keys.fontSize),
            let fontSize = FontSize(rawValue: fontSizeRawValue)
        {
            self.fontSize = fontSize
        }

        if let lineSpacingRawValue = userDefaults.string(forKey: Keys.lineSpacing),
            let lineSpacing = LineSpacing(rawValue: lineSpacingRawValue)
        {
            self.lineSpacing = lineSpacing
        }

        if let cornerRadiusRawValue = userDefaults.string(forKey: Keys.cornerRadius),
            let cornerRadius = CornerRadius(rawValue: cornerRadiusRawValue)
        {
            self.cornerRadius = cornerRadius
        }

        if let animationSpeedRawValue = userDefaults.string(forKey: Keys.animationSpeed),
            let animationSpeed = AnimationSpeed(rawValue: animationSpeedRawValue)
        {
            self.animationSpeed = animationSpeed
        }

        // Editor font settings
        if let savedFontName = userDefaults.string(forKey: Keys.editorFontName) {
            self.editorFontName = savedFontName
        }
        if let savedFontSize = userDefaults.object(forKey: Keys.editorFontSize) as? Double {
            self.editorFontSize = savedFontSize
        }
    }

    private func saveSettings() {
        userDefaults.set(currentTheme.rawValue, forKey: Keys.theme)
        userDefaults.set(fontSize.rawValue, forKey: Keys.fontSize)
        userDefaults.set(lineSpacing.rawValue, forKey: Keys.lineSpacing)
        userDefaults.set(cornerRadius.rawValue, forKey: Keys.cornerRadius)
        userDefaults.set(animationSpeed.rawValue, forKey: Keys.animationSpeed)

        // Editor font persistence
        userDefaults.set(editorFontName, forKey: Keys.editorFontName)
        userDefaults.set(editorFontSize, forKey: Keys.editorFontSize)
    }

    /// Migrate legacy editor-related settings into the new keys (best-effort).
    /// This helps upgrade users who previously stored editor preferences under old keys.
    private func migrateLegacyEditorSettings() {
        // Example legacy keys that were used historically; if present, migrate them.
        if let legacyName = userDefaults.string(forKey: "Ferrufi.editorFont") {
            userDefaults.set(legacyName, forKey: Keys.editorFontName)
        }
        if let legacySize = userDefaults.object(forKey: "Ferrufi.editorFontSize") as? Double {
            userDefaults.set(legacySize, forKey: Keys.editorFontSize)
        }
        // Add any future migration mappings here.
    }
}

// MARK: - Theme Definitions

public enum IronTheme: String, CaseIterable, Sendable {
    case ghostWhite = "ghost_white"
    case midnightBlue = "midnight_blue"
    case tokyoNight = "tokyo_night"
    case nordLight = "nord_light"
    case nordDark = "nord_dark"
    case catppuccinLatte = "catppuccin_latte"
    case catppuccinMocha = "catppuccin_mocha"
    case solarizedLight = "solarized_light"
    case solarizedDark = "solarized_dark"
    case draculaClassic = "dracula_classic"
    case gruvboxLight = "gruvbox_light"
    case gruvboxDark = "gruvbox_dark"
    case oneDarkPro = "one_dark_pro"
    case synthwave = "synthwave"
    case forestGreen = "forest_green"
    case lavenderMist = "lavender_mist"
    case system = "system"

    public var displayName: String {
        switch self {
        case .ghostWhite: return "Ghost White"
        case .midnightBlue: return "Midnight Blue"
        case .tokyoNight: return "Tokyo Night"
        case .nordLight: return "Nord Light"
        case .nordDark: return "Nord Dark"
        case .catppuccinLatte: return "Catppuccin Latte"
        case .catppuccinMocha: return "Catppuccin Mocha"
        case .solarizedLight: return "Solarized Light"
        case .solarizedDark: return "Solarized Dark"
        case .draculaClassic: return "Dracula Classic"
        case .gruvboxLight: return "Gruvbox Light"
        case .gruvboxDark: return "Gruvbox Dark"
        case .oneDarkPro: return "One Dark Pro"
        case .synthwave: return "Synthwave"
        case .forestGreen: return "Forest Green"
        case .lavenderMist: return "Lavender Mist"
        case .system: return "System"
        }
    }

    @MainActor
    public var colors: ThemeColors {
        switch self {
        case .system:
            // Dynamic theme that follows system appearance
            return NSApp.effectiveAppearance.name == .darkAqua 
                ? IronTheme.midnightBlue.colors 
                : IronTheme.ghostWhite.colors
        case .ghostWhite:
            return ThemeColors(
                background: Color(hex: "fafafa"),
                backgroundSecondary: Color(hex: "f5f5f5"),
                backgroundTertiary: Color(hex: "eeeeee"),
                foreground: Color(hex: "1a1a1a"),
                foregroundSecondary: Color(hex: "666666"),
                foregroundTertiary: Color(hex: "999999"),
                accent: Color(hex: "007AFF"),
                accentSecondary: Color(hex: "5AC8FA"),
                success: Color(hex: "34C759"),
                warning: Color(hex: "FF9500"),
                error: Color(hex: "FF3B30"),
                border: Color(hex: "e5e5e5"),
                shadow: Color(hex: "000000").opacity(0.08)
            )

        case .midnightBlue:
            return ThemeColors(
                background: Color(hex: "0f1419"),
                backgroundSecondary: Color(hex: "1a2332"),
                backgroundTertiary: Color(hex: "253649"),
                foreground: Color(hex: "e6e1cf"),
                foregroundSecondary: Color(hex: "b8b4a3"),
                foregroundTertiary: Color(hex: "828997"),
                accent: Color(hex: "39bae6"),
                accentSecondary: Color(hex: "73d0ff"),
                success: Color(hex: "c2d94c"),
                warning: Color(hex: "ffb454"),
                error: Color(hex: "ff6b6b"),
                border: Color(hex: "3e4b5c"),
                shadow: Color(hex: "000000").opacity(0.3)
            )

        case .tokyoNight:
            return ThemeColors(
                background: Color(hex: "1a1b26"),
                backgroundSecondary: Color(hex: "24283b"),
                backgroundTertiary: Color(hex: "414868"),
                foreground: Color(hex: "c0caf5"),
                foregroundSecondary: Color(hex: "9aa5ce"),
                foregroundTertiary: Color(hex: "565f89"),
                accent: Color(hex: "7aa2f7"),
                accentSecondary: Color(hex: "bb9af7"),
                success: Color(hex: "9ece6a"),
                warning: Color(hex: "e0af68"),
                error: Color(hex: "f7768e"),
                border: Color(hex: "3b4261"),
                shadow: Color(hex: "000000").opacity(0.4)
            )

        case .nordLight:
            return ThemeColors(
                background: Color(hex: "eceff4"),
                backgroundSecondary: Color(hex: "e5e9f0"),
                backgroundTertiary: Color(hex: "d8dee9"),
                foreground: Color(hex: "2e3440"),
                foregroundSecondary: Color(hex: "3b4252"),
                foregroundTertiary: Color(hex: "5e81ac"),
                accent: Color(hex: "5e81ac"),
                accentSecondary: Color(hex: "81a1c1"),
                success: Color(hex: "a3be8c"),
                warning: Color(hex: "ebcb8b"),
                error: Color(hex: "bf616a"),
                border: Color(hex: "d8dee9"),
                shadow: Color(hex: "000000").opacity(0.1)
            )

        case .nordDark:
            return ThemeColors(
                background: Color(hex: "2e3440"),
                backgroundSecondary: Color(hex: "3b4252"),
                backgroundTertiary: Color(hex: "434c5e"),
                foreground: Color(hex: "eceff4"),
                foregroundSecondary: Color(hex: "e5e9f0"),
                foregroundTertiary: Color(hex: "d8dee9"),
                accent: Color(hex: "88c0d0"),
                accentSecondary: Color(hex: "8fbcbb"),
                success: Color(hex: "a3be8c"),
                warning: Color(hex: "ebcb8b"),
                error: Color(hex: "bf616a"),
                border: Color(hex: "4c566a"),
                shadow: Color(hex: "000000").opacity(0.3)
            )

        case .catppuccinLatte:
            return ThemeColors(
                background: Color(hex: "eff1f5"),
                backgroundSecondary: Color(hex: "e6e9ef"),
                backgroundTertiary: Color(hex: "dce0e8"),
                foreground: Color(hex: "4c4f69"),
                foregroundSecondary: Color(hex: "5c5f77"),
                foregroundTertiary: Color(hex: "6c6f85"),
                accent: Color(hex: "1e66f5"),
                accentSecondary: Color(hex: "7287fd"),
                success: Color(hex: "40a02b"),
                warning: Color(hex: "df8e1d"),
                error: Color(hex: "d20f39"),
                border: Color(hex: "ccd0da"),
                shadow: Color(hex: "000000").opacity(0.08)
            )

        case .catppuccinMocha:
            return ThemeColors(
                background: Color(hex: "1e1e2e"),
                backgroundSecondary: Color(hex: "313244"),
                backgroundTertiary: Color(hex: "45475a"),
                foreground: Color(hex: "cdd6f4"),
                foregroundSecondary: Color(hex: "bac2de"),
                foregroundTertiary: Color(hex: "a6adc8"),
                accent: Color(hex: "89b4fa"),
                accentSecondary: Color(hex: "b4befe"),
                success: Color(hex: "a6e3a1"),
                warning: Color(hex: "f9e2af"),
                error: Color(hex: "f38ba8"),
                border: Color(hex: "585b70"),
                shadow: Color(hex: "000000").opacity(0.4)
            )

        case .solarizedLight:
            return ThemeColors(
                background: Color(hex: "fdf6e3"),
                backgroundSecondary: Color(hex: "eee8d5"),
                backgroundTertiary: Color(hex: "e3dcc9"),
                foreground: Color(hex: "586e75"),
                foregroundSecondary: Color(hex: "657b83"),
                foregroundTertiary: Color(hex: "839496"),
                accent: Color(hex: "268bd2"),
                accentSecondary: Color(hex: "2aa198"),
                success: Color(hex: "859900"),
                warning: Color(hex: "b58900"),
                error: Color(hex: "dc322f"),
                border: Color(hex: "e3dcc9"),
                shadow: Color(hex: "000000").opacity(0.05)
            )

        case .solarizedDark:
            return ThemeColors(
                background: Color(hex: "002b36"),
                backgroundSecondary: Color(hex: "073642"),
                backgroundTertiary: Color(hex: "0f4c5a"),
                foreground: Color(hex: "839496"),
                foregroundSecondary: Color(hex: "93a1a1"),
                foregroundTertiary: Color(hex: "657b83"),
                accent: Color(hex: "268bd2"),
                accentSecondary: Color(hex: "2aa198"),
                success: Color(hex: "859900"),
                warning: Color(hex: "b58900"),
                error: Color(hex: "dc322f"),
                border: Color(hex: "1a4c5a"),
                shadow: Color(hex: "000000").opacity(0.6)
            )

        case .draculaClassic:
            return ThemeColors(
                background: Color(hex: "282a36"),
                backgroundSecondary: Color(hex: "44475a"),
                backgroundTertiary: Color(hex: "5a5e72"),
                foreground: Color(hex: "f8f8f2"),
                foregroundSecondary: Color(hex: "e6e6e6"),
                foregroundTertiary: Color(hex: "6272a4"),
                accent: Color(hex: "bd93f9"),
                accentSecondary: Color(hex: "8be9fd"),
                success: Color(hex: "50fa7b"),
                warning: Color(hex: "ffb86c"),
                error: Color(hex: "ff5555"),
                border: Color(hex: "6272a4"),
                shadow: Color(hex: "000000").opacity(0.4)
            )

        case .gruvboxLight:
            return ThemeColors(
                background: Color(hex: "f9f5d7"),
                backgroundSecondary: Color(hex: "f2e5bc"),
                backgroundTertiary: Color(hex: "ebdbb2"),
                foreground: Color(hex: "3c3836"),
                foregroundSecondary: Color(hex: "504945"),
                foregroundTertiary: Color(hex: "7c6f64"),
                accent: Color(hex: "458588"),
                accentSecondary: Color(hex: "689d6a"),
                success: Color(hex: "98971a"),
                warning: Color(hex: "d79921"),
                error: Color(hex: "cc241d"),
                border: Color(hex: "d5c4a1"),
                shadow: Color(hex: "000000").opacity(0.08)
            )

        case .gruvboxDark:
            return ThemeColors(
                background: Color(hex: "282828"),
                backgroundSecondary: Color(hex: "3c3836"),
                backgroundTertiary: Color(hex: "504945"),
                foreground: Color(hex: "ebdbb2"),
                foregroundSecondary: Color(hex: "d5c4a1"),
                foregroundTertiary: Color(hex: "a89984"),
                accent: Color(hex: "83a598"),
                accentSecondary: Color(hex: "8ec07c"),
                success: Color(hex: "b8bb26"),
                warning: Color(hex: "fabd2f"),
                error: Color(hex: "fb4934"),
                border: Color(hex: "665c54"),
                shadow: Color(hex: "000000").opacity(0.4)
            )

        case .oneDarkPro:
            return ThemeColors(
                background: Color(hex: "1e2127"),
                backgroundSecondary: Color(hex: "2c313a"),
                backgroundTertiary: Color(hex: "3e4451"),
                foreground: Color(hex: "abb2bf"),
                foregroundSecondary: Color(hex: "9da5b4"),
                foregroundTertiary: Color(hex: "5c6370"),
                accent: Color(hex: "61afef"),
                accentSecondary: Color(hex: "c678dd"),
                success: Color(hex: "98c379"),
                warning: Color(hex: "e5c07b"),
                error: Color(hex: "e06c75"),
                border: Color(hex: "4b5263"),
                shadow: Color(hex: "000000").opacity(0.3)
            )

        case .synthwave:
            return ThemeColors(
                background: Color(hex: "0d1117"),
                backgroundSecondary: Color(hex: "161b22"),
                backgroundTertiary: Color(hex: "21262d"),
                foreground: Color(hex: "ff6ac1"),
                foregroundSecondary: Color(hex: "ff9500"),
                foregroundTertiary: Color(hex: "bd93f9"),
                accent: Color(hex: "ff00ff"),
                accentSecondary: Color(hex: "00ffff"),
                success: Color(hex: "39ff14"),
                warning: Color(hex: "ffff00"),
                error: Color(hex: "ff073a"),
                border: Color(hex: "30363d"),
                shadow: Color(hex: "ff00ff").opacity(0.2)
            )

        case .forestGreen:
            return ThemeColors(
                background: Color(hex: "1a2b1a"),
                backgroundSecondary: Color(hex: "2d4a2d"),
                backgroundTertiary: Color(hex: "3d5e3d"),
                foreground: Color(hex: "e8f5e8"),
                foregroundSecondary: Color(hex: "c7e8c7"),
                foregroundTertiary: Color(hex: "8fbc8f"),
                accent: Color(hex: "32cd32"),
                accentSecondary: Color(hex: "7fff00"),
                success: Color(hex: "90ee90"),
                warning: Color(hex: "f0e68c"),
                error: Color(hex: "fa8072"),
                border: Color(hex: "556b55"),
                shadow: Color(hex: "000000").opacity(0.5)
            )

        case .lavenderMist:
            return ThemeColors(
                background: Color(hex: "f8f5ff"),
                backgroundSecondary: Color(hex: "f0ebff"),
                backgroundTertiary: Color(hex: "e6d9ff"),
                foreground: Color(hex: "4a3c5a"),
                foregroundSecondary: Color(hex: "6b5b7b"),
                foregroundTertiary: Color(hex: "9b8cac"),
                accent: Color(hex: "8b7cf6"),
                accentSecondary: Color(hex: "c4b5fd"),
                success: Color(hex: "10b981"),
                warning: Color(hex: "f59e0b"),
                error: Color(hex: "ef4444"),
                border: Color(hex: "ddd6fe"),
                shadow: Color(hex: "8b7cf6").opacity(0.1)
            )
        }
    }

    @MainActor
    public var isDark: Bool {
        switch self {
        case .system:
            // Dynamic theme that follows system appearance
            return NSApp.effectiveAppearance.name == .darkAqua 
                ? true : false // simplified check for the property
        case .ghostWhite, .nordLight, .catppuccinLatte, .solarizedLight, .gruvboxLight,
            .lavenderMist:
            return false
        default:
            return true
        }
    }
}

// MARK: - Theme Colors Structure

public struct ThemeColors {
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
}

// MARK: - Supporting Enums

public enum FontSize: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extra_large"

    public var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }

    public var scale: CGFloat {
        switch self {
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .extraLarge: return 1.2
        }
    }
}

public enum LineSpacing: String, CaseIterable {
    case compact = "compact"
    case comfortable = "comfortable"
    case spacious = "spacious"

    public var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .comfortable: return "Comfortable"
        case .spacious: return "Spacious"
        }
    }

    public var value: CGFloat {
        switch self {
        case .compact: return 1.0
        case .comfortable: return 1.2
        case .spacious: return 1.4
        }
    }
}

public enum CornerRadius: String, CaseIterable {
    case none = "none"
    case small = "small"
    case medium = "medium"
    case large = "large"

    public var displayName: String {
        switch self {
        case .none: return "Sharp"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    public var value: CGFloat {
        switch self {
        case .none: return 0
        case .small: return 4
        case .medium: return 8
        case .large: return 12
        }
    }
}

public enum AnimationSpeed: String, CaseIterable {
    case none = "none"
    case slow = "slow"
    case normal = "normal"
    case fast = "fast"

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .slow: return "Slow"
        case .normal: return "Normal"
        case .fast: return "Fast"
        }
    }

    public var duration: Double {
        switch self {
        case .none: return 0
        case .slow: return 0.5
        case .normal: return 0.3
        case .fast: return 0.15
        }
    }
}

// MARK: - Color Extension

// MARK: - Theme View Extensions

extension View {
    public func themedBackground(_ themeManager: ThemeManager) -> some View {
        self.background(themeManager.currentTheme.colors.background)
    }

    public func themedForeground(_ themeManager: ThemeManager) -> some View {
        self.foregroundStyle(themeManager.currentTheme.colors.foreground)
    }

    public func themedAccent(_ themeManager: ThemeManager) -> some View {
        self.accentColor(themeManager.currentTheme.colors.accent)
    }

    public func themedCornerRadius(_ themeManager: ThemeManager) -> some View {
        self.cornerRadius(themeManager.cornerRadius.value)
    }

    public func themedShadow(_ themeManager: ThemeManager) -> some View {
        self.shadow(
            color: themeManager.currentTheme.colors.shadow,
            radius: themeManager.cornerRadius.value / 2,
            x: 0,
            y: 2
        )
    }

    public func themedFont(_ themeManager: ThemeManager, style: Font.TextStyle = .body) -> some View
    {
        self.font(.system(style).weight(.regular))
            .scaleEffect(themeManager.fontSize.scale)
    }

    public func themedAnimation<V: Equatable>(_ themeManager: ThemeManager, value: V) -> some View {
        self.animation(
            themeManager.animationSpeed == .none
                ? nil : .easeInOut(duration: themeManager.animationSpeed.duration),
            value: value
        )
    }
}
