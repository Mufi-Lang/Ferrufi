//
//  MufiCompletionView.swift
//  Ferrufi
//
//  A modern, IDE-style autocompletion list for Mufi Script.
//

import SwiftUI

public struct MufiCompletionView: View {
    let items: [MufiCompletionItem]
    let selectedIndex: Int
    let onItemSelected: (MufiCompletionItem) -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            CompletionRow(
                                item: item,
                                isSelected: index == selectedIndex,
                                action: { onItemSelected(item) }
                            )
                            .id(index)
                        }
                    }
                }
                .onChange(of: selectedIndex) { _, newIndex in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 320, height: min(CGFloat(items.count * 28 + 8), 240))
        .background(themeManager.currentTheme.colors.backgroundSecondary)
        .padding(0)
        .cornerRadius(0)
        .overlay(
            Rectangle()
                .stroke(themeManager.currentTheme.colors.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
    }
}

private struct CompletionRow: View {
    let item: MufiCompletionItem
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Kind Icon
                icon(for: item.kind)
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 16, height: 16)
                    .background(iconBackground(for: item.kind).opacity(0.2))
                    .foregroundColor(iconBackground(for: item.kind))
                    .cornerRadius(0)
                
                // Name
                Text(item.name)
                    .font(.system(size: 12, weight: isSelected ? .bold : .regular, design: .monospaced))
                    .foregroundColor(isSelected ? .white : themeManager.currentTheme.colors.foreground)
                
                Spacer()
                
                // Type Info
                if let type = item.typeName {
                    Text(type)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : themeManager.currentTheme.colors.foregroundTertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? themeManager.currentTheme.colors.accent : Color.clear)
        }
        .buttonStyle(.plain)
    }
    
    private func icon(for kind: MufiCompletionKind) -> Image {
        switch kind {
        case .variable: return Image(systemName: "v.square")
        case .function: return Image(systemName: "f.square")
        case .struct: return Image(systemName: "s.square")
        case .keyword: return Image(systemName: "k.square")
        }
    }
    
    private func iconBackground(for kind: MufiCompletionKind) -> Color {
        switch kind {
        case .variable: return .blue
        case .function: return .purple
        case .struct: return .orange
        case .keyword: return .green
        }
    }
}
