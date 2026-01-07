//
//  test_themes.swift
//  Iron
//
//  Simple test app to showcase beautiful themes
//

import SwiftUI

@main
struct ThemeTestApp: App {
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ThemeTestView()
                .environmentObject(themeManager)
        }
    }
}

struct ThemeTestView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingThemeSelector = false
    @State private var sampleText = """
        # Welcome to Iron Themes!

        This is a **bold** statement with *italic* emphasis and `inline code`.

        ## Beautiful Color Palettes

        Our themes are inspired by the most elegant color schemes:

        - **Tokyo Night**: Dark theme with vibrant blues and purples
        - **Catppuccin**: Soothing pastels for comfortable coding
        - **Nord**: Arctic-inspired cool colors
        - **Dracula**: Classic vampiric dark theme
        - **Gruvbox**: Retro groove with warm earth tones

        ### Code Example

        ```swift
        func createNote() {
            let note = Note(title: "Beautiful", content: "Amazing!")
            print("Theme: \\(themeManager.currentTheme.displayName)")
        }
        ```

        > This is a blockquote with ==highlighted text== and ~~strikethrough~~.

        Visit [[Another Note]] for more information.

        Tags: #themes #beautiful #design
        """

    var body: some View {
        HSplitView {
            // Sidebar
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "paintpalette")
                        .font(.title2)
                        .foregroundColor(themeManager.currentTheme.colors.accent)

                    Text("Themes")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.colors.foreground)

                    Spacer()
                }
                .padding()
                .background(themeManager.currentTheme.colors.backgroundSecondary)

                Divider()
                    .background(themeManager.currentTheme.colors.border)

                // Theme list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(IronTheme.allCases, id: \.self) { theme in
                            ThemeRowCard(
                                theme: theme,
                                isSelected: themeManager.currentTheme == theme
                            ) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    themeManager.setTheme(theme)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .background(themeManager.currentTheme.colors.background)
            }
            .frame(minWidth: 280)

            // Main content
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Text("Preview")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.currentTheme.colors.foreground)

                    Spacer()

                    // Theme info
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(themeManager.currentTheme.displayName)
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.colors.accent)

                        Text(themeManager.currentTheme.isDark ? "Dark Theme" : "Light Theme")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    }

                    // Settings
                    Button {
                        showingThemeSelector = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.colors.backgroundSecondary,
                            themeManager.currentTheme.colors.background,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Divider()
                    .background(themeManager.currentTheme.colors.border)

                // Content area
                GeometryReader { geometry in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Sample rendered markdown
                            VStack(alignment: .leading, spacing: 12) {
                                Text("# Welcome to Iron Themes!")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(themeManager.currentTheme.colors.foreground)

                                Text(
                                    "This is a **bold** statement with *italic* emphasis and `inline code`."
                                )
                                .font(.body)
                                .foregroundColor(themeManager.currentTheme.colors.foreground)

                                Text("## Beautiful Color Palettes")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(themeManager.currentTheme.colors.foreground)
                                    .padding(.top)

                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(
                                        [
                                            "Tokyo Night: Dark theme with vibrant blues and purples",
                                            "Catppuccin: Soothing pastels for comfortable coding",
                                            "Nord: Arctic-inspired cool colors",
                                            "Dracula: Classic vampiric dark theme",
                                            "Gruvbox: Retro groove with warm earth tones",
                                        ], id: \.self
                                    ) { item in
                                        HStack(alignment: .top, spacing: 8) {
                                            Circle()
                                                .fill(themeManager.currentTheme.colors.accent)
                                                .frame(width: 6, height: 6)
                                                .padding(.top, 6)

                                            Text(item)
                                                .font(.body)
                                                .foregroundColor(
                                                    themeManager.currentTheme.colors.foreground)
                                        }
                                    }
                                }

                                // Code block
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("### Code Example")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(
                                            themeManager.currentTheme.colors.foreground
                                        )
                                        .padding(.top)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("swift")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(
                                                themeManager.currentTheme.colors.foregroundSecondary
                                            )
                                            .padding(.horizontal, 12)
                                            .padding(.top, 8)

                                        Text(
                                            """
                                            func createNote() {
                                                let note = Note(title: "Beautiful", content: "Amazing!")
                                                print("Theme: \\(themeManager.currentTheme.displayName)")
                                            }
                                            """
                                        )
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(themeManager.currentTheme.colors.accent)
                                        .padding(.horizontal, 12)
                                        .padding(.bottom, 12)
                                    }
                                    .background(themeManager.currentTheme.colors.backgroundTertiary)
                                    .cornerRadius(8)
                                }

                                // Quote
                                HStack(alignment: .top, spacing: 12) {
                                    Rectangle()
                                        .fill(themeManager.currentTheme.colors.accent)
                                        .frame(width: 4)

                                    Text(
                                        "This is a blockquote with highlighted text and strikethrough."
                                    )
                                    .font(.body)
                                    .italic()
                                    .foregroundColor(
                                        themeManager.currentTheme.colors.foregroundSecondary)
                                }
                                .padding()
                                .background(themeManager.currentTheme.colors.backgroundSecondary)
                                .cornerRadius(8)

                                // Tags
                                HStack {
                                    ForEach(["#themes", "#beautiful", "#design"], id: \.self) {
                                        tag in
                                        Text(tag)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(
                                                themeManager.currentTheme.colors.accent
                                            )
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                themeManager.currentTheme.colors.accent.opacity(0.1)
                                            )
                                            .cornerRadius(12)
                                    }
                                }
                                .padding(.top)
                            }
                        }
                        .padding(20)
                        .frame(minHeight: geometry.size.height)
                    }
                }
                .background(themeManager.currentTheme.colors.background)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(themeManager.currentTheme.colors.background)
        .sheet(isPresented: $showingThemeSelector) {
            ThemeSettingsView()
                .environmentObject(themeManager)
        }
    }
}

struct ThemeRowCard: View {
    let theme: IronTheme
    let isSelected: Bool
    let onSelect: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Color preview
                HStack(spacing: 2) {
                    Circle()
                        .fill(theme.colors.background)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(theme.colors.border, lineWidth: 0.5)
                        )

                    Circle()
                        .fill(theme.colors.accent)
                        .frame(width: 12, height: 12)

                    Circle()
                        .fill(theme.colors.accentSecondary)
                        .frame(width: 12, height: 12)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(
                            isSelected
                                ? themeManager.currentTheme.colors.accent
                                : themeManager.currentTheme.colors.foreground
                        )
                        .lineLimit(1)

                    Text(theme.isDark ? "Dark" : "Light")
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(themeManager.currentTheme.colors.success)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected
                            ? themeManager.currentTheme.colors.accent.opacity(0.1)
                            : (isHovering
                                ? themeManager.currentTheme.colors.backgroundSecondary
                                : Color.clear)
                    )
                    .stroke(
                        isSelected ? themeManager.currentTheme.colors.accent : Color.clear,
                        lineWidth: isSelected ? 1 : 0
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}
