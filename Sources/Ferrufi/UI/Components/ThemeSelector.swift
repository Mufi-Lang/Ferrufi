//
//  ThemeSelector.swift
//  Ferrufi
//
//  Beautiful theme selector inspired by Ghostty's elegant theme picker
//

import SwiftUI

public struct ThemeSelector: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @State private var hoveredTheme: IronTheme?
    @State private var showingSettings = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Themes")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.colors.foreground)

                    Text("Choose your perfect color palette")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Theme Settings")

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()
                .background(themeManager.currentTheme.colors.border)

            // Theme Grid
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                    spacing: 12
                ) {
                    ForEach(IronTheme.allCases, id: \.self) { theme in
                        ThemePreviewCard(
                            theme: theme,
                            isSelected: themeManager.currentTheme == theme,
                            isHovered: hoveredTheme == theme
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                themeManager.setTheme(theme)
                            }
                        }
                        .onHover { isHovering in
                            withAnimation(.easeOut(duration: 0.2)) {
                                hoveredTheme = isHovering ? theme : nil
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .frame(width: 480, height: 600)
        .background(themeManager.currentTheme.colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeManager.currentTheme.colors.border, lineWidth: 1)
        )
        .sheet(isPresented: $showingSettings) {
            ThemeSettingsView()
                .environmentObject(themeManager)
        }
    }
}

struct ThemePreviewCard: View {
    let theme: IronTheme
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // Preview area with mock UI elements
                VStack(spacing: 8) {
                    // Mock window bar
                    HStack {
                        Circle()
                            .fill(theme.colors.error)
                            .frame(width: 8, height: 8)
                        Circle()
                            .fill(theme.colors.warning)
                            .frame(width: 8, height: 8)
                        Circle()
                            .fill(theme.colors.success)
                            .frame(width: 8, height: 8)

                        Spacer()

                        // Mock menu dots
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle()
                                    .fill(theme.colors.foregroundTertiary)
                                    .frame(width: 2, height: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                    // Mock content
                    VStack(alignment: .leading, spacing: 4) {
                        // Mock text lines
                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.colors.accent)
                                .frame(width: 30, height: 6)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.colors.foreground)
                                .frame(width: 60, height: 6)

                            Spacer()
                        }

                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.colors.foregroundSecondary)
                                .frame(width: 80, height: 4)

                            Spacer()
                        }

                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.colors.foregroundSecondary)
                                .frame(width: 45, height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.colors.foregroundTertiary)
                                .frame(width: 35, height: 4)

                            Spacer()
                        }

                        // Mock accent elements
                        HStack {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.colors.accentSecondary)
                                .frame(width: 20, height: 8)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.colors.success)
                                .frame(width: 16, height: 8)

                            Spacer()
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .frame(height: 80)
                .background(theme.colors.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.colors.border.opacity(0.5), lineWidth: 0.5)
                )
                .cornerRadius(6)

                // Theme name and info
                VStack(spacing: 2) {
                    Text(theme.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.colors.foreground)
                        .lineLimit(1)

                    Text(theme.isDark ? "Dark" : "Light")
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                }
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
        }
        .buttonStyle(.plain)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.currentTheme.colors.backgroundSecondary)
                .opacity(isHovered ? 0.8 : 0.4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? theme.colors.accent : themeManager.currentTheme.colors.border,
                    lineWidth: isSelected ? 2 : 1
                )
                .opacity(isHovered ? 1.0 : (isSelected ? 1.0 : 0.3))
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(
            color: isSelected ? theme.colors.accent.opacity(0.3) : Color.clear,
            radius: isSelected ? 8 : 0,
            x: 0,
            y: 2
        )
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct ThemeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Font Size
                VStack(alignment: .leading, spacing: 12) {
                    Text("Font Size")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.colors.foreground)

                    Picker("Font Size", selection: $themeManager.fontSize) {
                        ForEach(FontSize.allCases, id: \.self) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Line Spacing
                VStack(alignment: .leading, spacing: 12) {
                    Text("Line Spacing")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.colors.foreground)

                    Picker("Line Spacing", selection: $themeManager.lineSpacing) {
                        ForEach(LineSpacing.allCases, id: \.self) { spacing in
                            Text(spacing.displayName).tag(spacing)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Corner Radius
                VStack(alignment: .leading, spacing: 12) {
                    Text("Corner Radius")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.colors.foreground)

                    Picker("Corner Radius", selection: $themeManager.cornerRadius) {
                        ForEach(CornerRadius.allCases, id: \.self) { radius in
                            Text(radius.displayName).tag(radius)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Animation Speed
                VStack(alignment: .leading, spacing: 12) {
                    Text("Animation Speed")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.colors.foreground)

                    Picker("Animation Speed", selection: $themeManager.animationSpeed) {
                        ForEach(AnimationSpeed.allCases, id: \.self) { speed in
                            Text(speed.displayName).tag(speed)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Spacer()
            }
            .padding(24)
            .frame(width: 400, height: 400)
            .background(themeManager.currentTheme.colors.background)
            .navigationTitle("Theme Settings")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.colors.accent)
                }
            }
        }
    }
}

// Convenient theme toggle button for toolbars
public struct ThemeToggleButton: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingThemeSelector = false

    public init() {}

    public var body: some View {
        Button {
            showingThemeSelector = true
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(themeManager.currentTheme.colors.accent)
                    .frame(width: 12, height: 12)

                Text(themeManager.currentTheme.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(themeManager.currentTheme.colors.backgroundSecondary)
                    .stroke(themeManager.currentTheme.colors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help("Change Theme")
        .popover(isPresented: $showingThemeSelector, arrowEdge: .bottom) {
            ThemeSelector()
                .environmentObject(themeManager)
        }
    }
}
