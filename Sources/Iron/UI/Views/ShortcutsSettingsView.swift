//
//  ShortcutsSettingsView.swift
//  Iron
//
//  Settings UI for viewing and remapping keyboard shortcuts
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let shortcutsLabelWidth: CGFloat = 240

@MainActor
public struct ShortcutsSettingsView: View {
    @EnvironmentObject var ironApp: IronApp
    @ObservedObject private var shortcuts = ShortcutsManager.shared

    @State private var editingActionId: String? = nil
    @State private var editingInitialBinding: KeyBinding? = nil

    @State private var pendingBinding: KeyBinding? = nil
    @State private var showConflictAlert: Bool = false
    @State private var conflictActions: [String] = []

    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""

    // Search/filter for the shortcuts list
    @State private var searchQuery: String = ""

    // Reset confirmation state for per-action reset
    @State private var showResetConfirm: Bool = false
    @State private var resetTargetAction: String? = nil
    @State private var resetDefaultBinding: KeyBinding? = nil
    @State private var resetConflicts: [String] = []

    // Import / Export state
    @State private var pendingImportURL: URL? = nil
    @State private var showImportConfirm: Bool = false
    @State private var showExportError: Bool = false
    @State private var exportErrorMessage: String = ""
    @State private var showImportError: Bool = false
    @State private var importErrorMessage: String = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.title3)
                    .bold()
                Spacer()
                Button("Import...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.allowsMultipleSelection = false
                    panel.allowedContentTypes = [UTType.json]
                    panel.begin { response in
                        guard response == .OK, let url = panel.url else { return }
                        // store pending URL and ask for confirmation before applying
                        pendingImportURL = url
                        showImportConfirm = true
                    }
                }
                .help("Import a shortcuts profile (JSON)")
                .controlSize(.small)

                Button("Export...") {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = "shortcuts-profile.json"
                    panel.allowedContentTypes = [UTType.json]
                    panel.canCreateDirectories = true
                    panel.begin { response in
                        guard response == .OK, let url = panel.url else { return }
                        do {
                            let data = try shortcuts.exportProfile()
                            try data.write(to: url, options: .atomic)
                        } catch {
                            exportErrorMessage = error.localizedDescription
                            showExportError = true
                        }
                    }
                }
                .help("Export current shortcuts to a JSON profile")
                .controlSize(.small)

                Button("Reset to Defaults") {
                    shortcuts.resetToDefaults()
                }
                .help("Restore all shortcuts to their default bindings")
                .controlSize(.small)
            }
            .padding(.bottom, 6)

            // Search / filter row
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search shortcuts", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 220)
                Spacer()
                Text("\(shortcuts.actionLabels.keys.count) items")
                    .foregroundColor(.secondary)
                    .font(.footnote)
                Button("Clear") {
                    searchQuery = ""
                }
                .controlSize(.small)
            }
            .padding(.bottom, 8)

            // Scrollable list of actions (filtered)
            let visibleActions = shortcuts.actionLabels.keys.sorted().filter { actionId in
                let label = (shortcuts.actionLabels[actionId] ?? actionId).lowercased()
                let bindingDisplay = shortcuts.displayString(for: actionId).lowercased()
                if searchQuery.isEmpty { return true }
                let q = searchQuery.lowercased()
                return label.contains(q) || bindingDisplay.contains(q)
            }

            ScrollView(.vertical) {
                LazyVStack(spacing: 6, pinnedViews: []) {
                    ForEach(visibleActions, id: \.self) { actionId in
                        HStack(spacing: 12) {
                            Text(shortcuts.actionLabels[actionId] ?? actionId)
                                .frame(minWidth: shortcutsLabelWidth, alignment: .leading)
                                .lineLimit(1)

                            Spacer()

                            // Inline conflict indicator (tooltip shows conflicting actions)
                            if let b = shortcuts.binding(for: actionId) {
                                let conflicts = shortcuts.conflicts(with: b, excluding: actionId)
                                if !conflicts.isEmpty {
                                    let conflictNames = conflicts.compactMap {
                                        shortcuts.actionLabels[$0] ?? $0
                                    }.joined(separator: ", ")
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.yellow)
                                        .help("Conflicts with: \(conflictNames)")
                                        .accessibilityLabel(
                                            "Conflict: \(conflicts.count) other action(s)")
                                }
                            }

                            Text(shortcuts.displayString(for: actionId))
                                .foregroundColor(.secondary)
                                .mono()
                                .frame(minWidth: 80, alignment: .trailing)

                            Button("Edit") {
                                editingInitialBinding =
                                    shortcuts.binding(for: actionId)
                                    ?? KeyBinding(key: "", modifiers: [])
                                editingActionId = actionId
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button(action: {
                                // Reset this action to its default binding (if one exists)
                                if let defaultBinding = ShortcutsConfiguration.defaultBindings[
                                    actionId]
                                {
                                    do {
                                        try shortcuts.updateBinding(actionId, to: defaultBinding)
                                    } catch {
                                        errorMessage = error.localizedDescription
                                        showErrorAlert = true
                                    }
                                }
                            }) {
                                Image(systemName: "arrow.counterclockwise")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Reset to default binding")
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 6)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.visible)
            .frame(minHeight: 260)
        }
        .padding(8)
        .frame(minWidth: 520, minHeight: 420)
        .sheet(
            isPresented: Binding(
                get: { editingActionId != nil },
                set: {
                    if !$0 {
                        editingActionId = nil
                        editingInitialBinding = nil
                        pendingBinding = nil
                    }
                }
            )
        ) {
            if let actionId = editingActionId, let initial = editingInitialBinding {
                ShortcutEditorView(
                    actionId: actionId,
                    initialBinding: initial,
                    onSave: { newBinding in
                        // Attempt to save; handle duplicate conflicts by asking the user
                        pendingBinding = newBinding
                        do {
                            try shortcuts.updateBinding(actionId, to: newBinding)
                            // Success -> close sheet
                            editingActionId = nil
                            editingInitialBinding = nil
                            pendingBinding = nil
                        } catch let ShortcutsManager.ShortcutError.duplicateBinding(conflicts) {
                            conflictActions = conflicts
                            showConflictAlert = true
                        } catch {
                            errorMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                    },
                    onCancel: {
                        editingActionId = nil
                        editingInitialBinding = nil
                        pendingBinding = nil
                    }
                )
                .frame(minWidth: 420, minHeight: 220)
            } else {
                EmptyView()
            }
        }
        .alert(isPresented: $showConflictAlert) {
            let conflictNames = conflictActions.compactMap { shortcuts.actionLabels[$0] ?? $0 }
                .joined(separator: ", ")
            return Alert(
                title: Text("Shortcut Conflict"),
                message: Text(
                    "This shortcut conflicts with: \(conflictNames). Do you want to override?"),
                primaryButton: .destructive(Text("Override")) {
                    Task { @MainActor in
                        if let actionId = editingActionId, let pending = pendingBinding {
                            do {
                                try shortcuts.updateBinding(
                                    actionId, to: pending, allowDuplicate: true)
                                editingActionId = nil
                                editingInitialBinding = nil
                                pendingBinding = nil
                                showConflictAlert = false
                            } catch {
                                errorMessage = error.localizedDescription
                                showErrorAlert = true
                            }
                        }
                    }
                },
                secondaryButton: .cancel {
                    // Keep editing open; user can adjust
                    pendingBinding = nil
                    showConflictAlert = false
                }
            )
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"), message: Text(errorMessage),
                dismissButton: .default(Text("OK")))
        }
    }
}

// Simple convenience modifier to use a monospaced display for the shortcut text.
extension View {
    fileprivate func mono() -> some View {
        self.font(.system(.body, design: .monospaced))
    }
}

// MARK: - Shortcut Editor View

struct ShortcutEditorView: View {
    let actionId: String

    @State private var key: String
    @State private var cmd: Bool
    @State private var option: Bool
    @State private var shift: Bool
    @State private var control: Bool
    @State private var showCapture: Bool = false

    var onSave: (KeyBinding) -> Void
    var onCancel: () -> Void

    init(
        actionId: String, initialBinding: KeyBinding, onSave: @escaping (KeyBinding) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.actionId = actionId
        self._key = State(initialValue: initialBinding.key)
        self._cmd = State(
            initialValue: initialBinding.modifiers.contains(where: {
                ["cmd", "command"].contains($0.lowercased())
            }))
        self._option = State(
            initialValue: initialBinding.modifiers.contains(where: {
                ["opt", "option", "alt"].contains($0.lowercased())
            }))
        self._shift = State(
            initialValue: initialBinding.modifiers.contains(where: { $0.lowercased() == "shift" }))
        self._control = State(
            initialValue: initialBinding.modifiers.contains(where: {
                ["ctrl", "control"].contains($0.lowercased())
            }))
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Edit Shortcut")
                    .font(.headline)
                Spacer()
                Text(ShortcutsManager.shared.actionLabels[actionId] ?? actionId)
                    .foregroundColor(.secondary)
            }

            Form {
                HStack {
                    Text("Key:")
                    Spacer()
                    TextField("Enter single key (e.g. N or / or [)", text: $key)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .disableAutocorrection(true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Modifiers:")
                    HStack {
                        Toggle("⌘ Command", isOn: $cmd)
                        Toggle("⌥ Option", isOn: $option)
                        Toggle("⇧ Shift", isOn: $shift)
                        Toggle("⌃ Control", isOn: $control)
                    }
                    .toggleStyle(.switch)
                }
            }
            .padding(.bottom, 6)

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Capture") {
                    // open capture sheet to let user press a key combination
                    showCapture = true
                }
                .buttonStyle(.bordered)
                .help("Click this then press the desired key combination (Esc to cancel)")

                Button("Save") {
                    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let first = trimmed.first else {
                        // invalid input; do nothing (parent will show validation if required)
                        return
                    }

                    var mods: [String] = []
                    if cmd { mods.append("cmd") }
                    if option { mods.append("option") }
                    if shift { mods.append("shift") }
                    if control { mods.append("control") }

                    let binding = KeyBinding(key: String(first), modifiers: mods)
                    onSave(binding)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .sheet(isPresented: $showCapture) {
                KeyCaptureView(
                    onCaptured: { newBinding in
                        // Update editor fields from captured binding
                        let trimmed = newBinding.key.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let first = trimmed.first {
                            key = String(first)
                        } else {
                            key = ""
                        }
                        cmd = newBinding.modifiers.contains {
                            ["cmd", "command"].contains($0.lowercased())
                        }
                        option = newBinding.modifiers.contains {
                            ["option", "opt", "alt"].contains($0.lowercased())
                        }
                        shift = newBinding.modifiers.contains { $0.lowercased() == "shift" }
                        control = newBinding.modifiers.contains {
                            ["control", "ctrl"].contains($0.lowercased())
                        }
                        showCapture = false
                    },
                    onCancel: {
                        showCapture = false
                    })
            }
        }
        .padding()
    }
}

// MARK: - Previews

struct ShortcutsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ShortcutsSettingsView()
            .environmentObject(IronApp())
            .frame(width: 680, height: 480)
    }
}
