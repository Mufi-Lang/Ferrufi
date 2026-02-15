import SwiftUI

public struct NewProjectWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var projectName = "my_project"
    @State private var projectLocation = ""
    @State private var initGit = true
    @State private var openAutomatically = true
    @State private var isCreating = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Mufi Project")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.colors.foreground)
                    Text("Create a new Mufi package with standard structure")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(themeManager.currentTheme.colors.backgroundSecondary)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Project Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Name")
                            .font(.headline)
                        
                        TextField("my_project", text: $projectName)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("This will be the directory name and project identity.")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    }
                    
                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                        
                        HStack {
                            TextField("Path to parent directory", text: $projectLocation)
                                .textFieldStyle(.roundedBorder)
                                .disabled(true)
                            
                            Button("Browse...") {
                                selectLocation()
                            }
                            .controlSize(.small)
                        }
                        
                        if !projectLocation.isEmpty {
                            Text("Project will be created at: \(projectLocation)/\(projectName)")
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.colors.accent)
                        }
                    }
                    
                    Divider()
                    
                    // Options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Options")
                            .font(.headline)
                        
                        Toggle("Initialize Git Repository", isOn: $initGit)
                            .toggleStyle(.checkbox)
                        
                        Toggle("Open in New Workspace", isOn: $openAutomatically)
                            .toggleStyle(.checkbox)
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer
            HStack(spacing: 16) {
                if isCreating {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 8)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle(themeManager: themeManager))
                .disabled(isCreating)
                
                Button("Create Project") {
                    createProject()
                }
                .buttonStyle(PrimaryButtonStyle(themeManager: themeManager, disabled: !isValid || isCreating))
                .disabled(!isValid || isCreating)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            .background(themeManager.currentTheme.colors.backgroundSecondary)
        }
        .frame(width: 500, height: 500)
        .background(themeManager.currentTheme.colors.background)
        .onAppear {
            if projectLocation.isEmpty {
                projectLocation = ferrufiApp.folderManager.rootFolder.path
            }
        }
    }
    
    private var isValid: Bool {
        !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !projectLocation.isEmpty
    }
    
    private func selectLocation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Select parent directory for the new project"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                projectLocation = url.path
            }
        }
    }
    
    private func createProject() {
        isCreating = true
        
        Task {
            do {
                try await MufiRuntimeService.shared.createNewProject(
                    name: projectName,
                    at: projectLocation,
                    initGit: initGit
                )
                
                let fullPath = URL(fileURLWithPath: projectLocation).appendingPathComponent(projectName).path
                
                await MainActor.run {
                    ToastManager.shared.show(message: "Project '\(projectName)' created", type: .success)
                    
                    if openAutomatically {
                        // Switch workspace to the new project
                        Task {
                            do {
                                try await ferrufiApp.initialize(workspacePath: fullPath)
                                await MainActor.run {
                                    ferrufiApp.folderManager.refreshNotes()
                                    if let mainMufi = ferrufiApp.notes.first(where: { $0.filePath.contains("main.mufi") }) {
                                        navigationModel.selectNote(mainMufi, ferrufiApp: ferrufiApp)
                                    }
                                }
                            } catch {
                                navigationModel.showError(error)
                            }
                        }
                    } else {
                        // Just refresh current if it's a subfolder? 
                        // For now just refresh explorer
                        ferrufiApp.folderManager.refreshNotes()
                    }
                    
                    isCreating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    navigationModel.showError(error)
                    isCreating = false
                }
            }
        }
    }
}
