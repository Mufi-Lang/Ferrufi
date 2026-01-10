/*
 KeyCaptureView.swift
 Ferrufi

 A small SwiftUI / AppKit bridge that captures a single keyboard combination
 (key + modifiers) and returns it as a `KeyBinding` via a callback.

 Usage:
   KeyCaptureView { binding in
       // binding.key, binding.modifiers -> persist/update state
   } onCancel: {
       // user cancelled capture (Esc or clicked Cancel)
   }

 Notes:
 - This implementation captures the first keyDown (with modifiers) and calls back.
 - It attempts to provide a human-friendly preview (e.g. "⌘⇧N") while capturing.
 - For non-character keys it falls back to a small set of readable names (arrows,
   escape, return) where feasible.
*/

import AppKit
import SwiftUI

@MainActor
public struct KeyCaptureView: View {
    public var onCaptured: (KeyBinding) -> Void
    public var onCancel: (() -> Void)?

    @State private var displayText: String = "Press the key combination"
    @State private var capturedBinding: KeyBinding? = nil
    @State private var isActive: Bool = true

    public init(onCaptured: @escaping (KeyBinding) -> Void, onCancel: (() -> Void)? = nil) {
        self.onCaptured = onCaptured
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            // Invisible capture area (receives key events)
            CaptureNSViewRepresentable { binding, rendered in
                // Update the preview and hold the captured binding;
                // require explicit confirmation to finalize the choice.
                capturedBinding = binding
                displayText = rendered
            } onCancel: {
                // Clear any staged capture if the system canceled the capture (e.g. Esc)
                capturedBinding = nil
                displayText = "Press the key combination"
                onCancel?()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
            .accessibilityHidden(true)

            // Foreground UI / instructions (compact)
            VStack(spacing: 10) {
                Text("Press the key combination")
                    .font(.headline)
                Text(displayText)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Captured shortcut")
                    .accessibilityValue(displayText)
                HStack(spacing: 10) {
                    Button("Cancel") {
                        // Clear staged binding and dismiss
                        capturedBinding = nil
                        displayText = "Press the key combination"
                        onCancel?()
                    }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.bordered)
                    .help("Cancel and do not save the captured key combination")

                    Button("Confirm") {
                        if let b = capturedBinding {
                            onCaptured(b)
                            capturedBinding = nil
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(capturedBinding == nil)
                    .help("Apply the captured key combination as the shortcut")
                    .accessibilityLabel("Confirm shortcut")
                    .accessibilityHint("Saves the captured key combination")
                }
            }
            .padding(14)
            .frame(minWidth: 380, minHeight: 140)
            .background(VisualEffectView(material: .windowBackground, blendingMode: .behindWindow))
            .cornerRadius(9)
            .shadow(radius: 8, y: 4)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Shortcut capture dialog")
            .accessibilityHint("Press a key combination, then Confirm to apply or Cancel to abort")
        }
        .onAppear {
            // Ensure app becomes frontmost and our capture view becomes first responder
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - NSViewRepresentable for capturing key presses

private struct CaptureNSViewRepresentable: NSViewRepresentable {
    let onCaptured: (KeyBinding, String) -> Void
    let onCancel: () -> Void

    init(onCaptured: @escaping (KeyBinding, String) -> Void, onCancel: @escaping () -> Void) {
        self.onCaptured = onCaptured
        self.onCancel = onCancel
    }

    func makeNSView(context: Context) -> CaptureNSView {
        let v = CaptureNSView()
        v.onCaptured = { binding, preview in
            onCaptured(binding, preview)
        }
        v.onCancel = {
            onCancel()
        }
        return v
    }

    func updateNSView(_ nsView: CaptureNSView, context: Context) {
        // no-op
    }
}

private class CaptureNSView: NSView {
    var onCaptured: ((KeyBinding, String) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Make sure this view is first responder so it receives key events immediately
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        // ESC (cancel)
        if let chars = event.characters, chars == "\u{1b}" {
            onCancel?()
            return
        }

        // Incoming characters ignoring modifiers
        let raw = event.charactersIgnoringModifiers ?? event.characters ?? ""
        let keyString: String
        if !raw.isEmpty {
            // Take first character (most useful for shortcuts)
            keyString = String(raw.first!)
        } else {
            // Fallback to keyCode mapping for non-character keys
            keyString = keyNameForEvent(event) ?? ""
        }

        // Determine modifiers
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods: [String] = []
        if flags.contains(.command) { mods.append("cmd") }
        if flags.contains(.option) { mods.append("option") }
        if flags.contains(.shift) { mods.append("shift") }
        if flags.contains(.control) { mods.append("control") }

        // Build human display string (symbols first)
        let human = modifiersSymbols(for: mods) + humanReadableKey(for: keyString)

        let binding = KeyBinding(key: keyString, modifiers: mods)
        onCaptured?(binding, human)
    }

    override func flagsChanged(with event: NSEvent) {
        // Nothing to do until a keyDown is observed; keeping for future realtime previews.
    }

    // HELPERS

    private func modifiersSymbols(for mods: [String]) -> String {
        // Using common macOS symbols
        var s = ""
        for m in mods {
            switch m.lowercased() {
            case "cmd", "command": s += "⌘"
            case "option", "opt", "alt": s += "⌥"
            case "shift": s += "⇧"
            case "control", "ctrl": s += "⌃"
            default: break
            }
        }
        return s
    }

    private func humanReadableKey(for key: String) -> String {
        // Normalize common visible characters
        if key == " " { return "Space" }
        if key == "\r" { return "Return" }
        // Printable single character - show uppercase
        if key.count == 1 {
            return key.uppercased()
        }
        // fallback
        return key
    }

    private func keyNameForEvent(_ event: NSEvent) -> String? {
        // Map a few special keys by keyCode as fallback (including common function keys)
        switch event.keyCode {
        // Function keys (common macOS keyCodes)
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        // Arrows
        case 123: return "LeftArrow"
        case 124: return "RightArrow"
        case 125: return "DownArrow"
        case 126: return "UpArrow"
        default:
            return nil
        }
    }
}

// MARK: - VisualEffectView for a subtle background

private struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
