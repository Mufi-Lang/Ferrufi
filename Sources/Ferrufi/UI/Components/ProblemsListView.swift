//
//  ProblemsListView.swift
//  Ferrufi
//
//  A dedicated view for displaying static analysis errors and warnings.
//

import SwiftUI

public struct ProblemsListView: View {
    @StateObject private var lspService = MufiLSPService.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Problems")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                
                Spacer()
                
                let errors = lspService.diagnostics.filter { $0.severity == .error }.count
                let warnings = lspService.diagnostics.filter { $0.severity == .warning }.count
                
                Text("\(errors) errors, \(warnings) warnings")
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(themeManager.currentTheme.colors.backgroundSecondary.opacity(0.5))
            
            Divider()
            
            if lspService.diagnostics.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundColor(themeManager.currentTheme.colors.success.opacity(0.5))
                    Text("No problems found in the current file")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(lspService.diagnostics) { diagnostic in
                        ProblemRow(diagnostic: diagnostic)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.visible)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                NotificationCenter.default.post(
                                    name: .editorNavigateToRange,
                                    object: diagnostic.range,
                                    userInfo: nil
                                )
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(themeManager.currentTheme.colors.background)
    }
}

private struct ProblemRow: View {
    let diagnostic: MufiDiagnostic
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: diagnostic.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(diagnostic.severity == .error ? .red : .orange)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(diagnostic.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
                
                Text("Line \(diagnostic.range.start.line), Column \(diagnostic.range.start.column)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
