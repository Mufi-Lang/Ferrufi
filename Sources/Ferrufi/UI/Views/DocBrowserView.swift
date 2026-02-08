//
//  DocBrowserView.swift
//  Ferrufi
//

import SwiftUI
import AppKit

public struct DocBrowserView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var docService = DocumentationService.shared
    
    @State private var searchText: String = ""
    @State private var selectedEntry: DocumentationEntry?
    @State private var entries: [DocumentationEntry] = []
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 0) {
            // Sidebar: Search and Results List
            VStack(spacing: 0) {
                searchBar
                
                Divider()
                    .background(themeManager.currentTheme.colors.border)
                
                resultsList
            }
            .frame(width: 300)
            .background(themeManager.currentTheme.colors.backgroundSecondary.opacity(0.5))
            
            Divider()
                .frame(width: 1)
                .background(themeManager.currentTheme.colors.border)
            
            // Content Area: Markdown Preview
            VStack(spacing: 0) {
                if let entry = selectedEntry {
                    contentHeader(entry)
                    
                    MarkdownView(content: entry.content)
                        .id(entry.id) // Force refresh when entry changes
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeManager.currentTheme.colors.background)
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            updateResults()
        }
        .onChange(of: searchText) {
            updateResults()
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
            
            TextField("Search Documentation...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(themeManager.currentTheme.colors.background.opacity(0.5))
        .cornerRadius(8)
        .padding(12)
    }
    
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(entries) { entry in
                    DocResultRow(
                        entry: entry,
                        isSelected: selectedEntry?.id == entry.id,
                        action: { selectedEntry = entry }
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func contentHeader(_ entry: DocumentationEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
                
                HStack(spacing: 8) {
                    Text(entry.category.displayName)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(themeManager.currentTheme.colors.accent.opacity(0.1))
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                        .cornerRadius(4)
                    
                    Text(entry.fileName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
        .padding(.bottom, 20)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.pages")
                .font(.system(size: 48))
                .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary.opacity(0.5))
            
            Text("Select a topic to view documentation")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
            
            Text("Search for Mufi syntax, keywords, or standard library functions.")
                .font(.system(size: 13))
                .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func updateResults() {
        entries = docService.search(query: searchText)
        if selectedEntry == nil, let first = entries.first {
            selectedEntry = first
        }
    }
}

struct DocResultRow: View {
    let entry: DocumentationEntry
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? themeManager.currentTheme.colors.accent : themeManager.currentTheme.colors.foregroundSecondary)
                    
                    Text(entry.category.displayName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                }
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(themeManager.currentTheme.colors.accent)
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? themeManager.currentTheme.colors.accent.opacity(0.1) : Color.clear)
                    .padding(.horizontal, 8)
            )
        }
        .buttonStyle(.plain)
    }
}

// Minimal wrapper for the existing Markdown parsing/rendering
struct MarkdownView: View {
    let content: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        WebView(htmlContent: MarkdownParser.shared.parse(content, theme: themeManager.currentTheme.colors))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
