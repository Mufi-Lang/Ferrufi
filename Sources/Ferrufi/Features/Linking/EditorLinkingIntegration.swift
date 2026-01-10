//
//  EditorLinkingIntegration.swift
//  Ferrufi
//
//  Integrate linking system with the editor for automatic link detection and handling
//

import AppKit
import Combine
import Foundation
import SwiftUI

/// Integrates the linking system with text editors for real-time link processing
@MainActor
public class EditorLinkingIntegration: ObservableObject {

    // MARK: - Published Properties

    /// Current links in the active document
    @Published public private(set) var currentLinks: [WikiLink] = []

    /// Current tags in the active document
    @Published public private(set) var currentTags: [NoteTag] = []

    /// Link validation results for current document
    @Published public private(set) var validationResults: LinkValidationResult?

    /// Whether auto-completion is showing
    @Published public var isShowingAutoCompletion: Bool = false

    /// Auto-completion suggestions
    @Published public var autoCompletionSuggestions: [String] = []

    // MARK: - Dependencies

    private let linkParser: LinkParser
    private let linkManager: LinkManager
    private let storage: any UnifiedStorageProtocol

    // MARK: - State

    public var currentNoteID: String?
    private var textView: NSTextView?
    private var textViewDelegate: LinkingTextViewDelegate?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration

    public struct Configuration {
        /// Enable automatic link detection
        public var enableAutoDetection: Bool = true

        /// Enable auto-completion for links
        public var enableAutoCompletion: Bool = true

        /// Enable syntax highlighting for links
        public var enableSyntaxHighlighting: Bool = true

        /// Delay before processing changes (seconds)
        public var processingDelay: TimeInterval = 0.5

        /// Maximum auto-completion suggestions
        public var maxSuggestions: Int = 10

        public init() {}
    }

    public var configuration = Configuration()

    // MARK: - Initialization

    public init(linkManager: LinkManager, storage: any UnifiedStorageProtocol) {
        self.linkParser = LinkParser()
        self.linkManager = linkManager
        self.storage = storage

        setupObservers()
    }

    // MARK: - Public Interface

    /// Attach to a text view for link processing
    public func attachToTextView(_ textView: NSTextView, noteID: String) {
        self.textView = textView
        self.currentNoteID = noteID

        // Set up text view delegate if needed
        if textView.delegate == nil {
            let delegate = LinkingTextViewDelegate(integration: self)
            self.textViewDelegate = delegate
            textView.delegate = delegate
        }

        // Process initial content
        processTextContent(textView.string)
    }

    /// Detach from current text view
    public func detachFromTextView() {
        textView?.delegate = nil
        textView = nil
        textViewDelegate = nil
        currentNoteID = nil
        currentLinks.removeAll()
        currentTags.removeAll()
        validationResults = nil
    }

    /// Insert a wiki link at the current cursor position
    public func insertWikiLink(target: String, displayText: String? = nil) {
        guard let textView = textView else { return }

        let selectedRange = textView.selectedRange()
        let linkText = linkParser.generateWikiLink(
            target: target,
            displayText: displayText
        )

        // Insert the link
        textView.insertText(linkText, replacementRange: selectedRange)

        // Update cursor position after the link
        let newPosition = selectedRange.location + linkText.count
        textView.setSelectedRange(NSRange(location: newPosition, length: 0))
    }

    /// Convert selected text to a wiki link
    public func convertSelectionToWikiLink(target: String? = nil) {
        guard let textView = textView else { return }

        let selectedRange = textView.selectedRange()
        guard selectedRange.length > 0 else { return }

        let (newContent, linkRange) = linkParser.convertSelectionToWikiLink(
            in: textView.string,
            selectionRange: selectedRange,
            target: target
        )

        // Replace the content
        textView.string = newContent

        // Select the new link
        textView.setSelectedRange(linkRange)
    }

    /// Insert a hashtag at the current cursor position
    public func insertHashtag(_ tagName: String) {
        guard let textView = textView else { return }

        let selectedRange = textView.selectedRange()
        let tagText = linkParser.generateHashtag(tagName)

        textView.insertText(tagText + " ", replacementRange: selectedRange)

        // Update cursor position
        let newPosition = selectedRange.location + tagText.count + 1
        textView.setSelectedRange(NSRange(location: newPosition, length: 0))
    }

    /// Show auto-completion for the current typing context
    public func showAutoCompletion(for partialText: String) {
        guard configuration.enableAutoCompletion else { return }

        Task {
            let suggestions = await linkManager.findLinkSuggestions(
                for: partialText,
                excludingNoteID: currentNoteID
            )

            await MainActor.run {
                self.autoCompletionSuggestions = Array(
                    suggestions.prefix(configuration.maxSuggestions))
                self.isShowingAutoCompletion = !suggestions.isEmpty
            }
        }
    }

    /// Hide auto-completion
    public func hideAutoCompletion() {
        isShowingAutoCompletion = false
        autoCompletionSuggestions.removeAll()
    }

    /// Get link at the specified location
    public func getLinkAt(location: Int) -> WikiLink? {
        return currentLinks.first { link in
            NSLocationInRange(location, link.range)
        }
    }

    /// Get tag at the specified location
    public func getTagAt(location: Int) -> NoteTag? {
        return currentTags.first { tag in
            NSLocationInRange(location, tag.range)
        }
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Listen for text changes with debouncing
        NotificationCenter.default
            .publisher(for: NSText.didChangeNotification)
            .debounce(for: .seconds(configuration.processingDelay), scheduler: RunLoop.main)
            .sink { [weak self] notification in
                guard let textView = notification.object as? NSTextView,
                    textView == self?.textView,
                    let content = self?.textView?.string
                else { return }

                self?.processTextContent(content)
            }
            .store(in: &cancellables)

        // Listen for selection changes
        NotificationCenter.default
            .publisher(for: NSTextView.didChangeSelectionNotification)
            .sink { [weak self] notification in
                guard let textView = notification.object as? NSTextView,
                    textView == self?.textView
                else { return }

                self?.handleSelectionChange()
            }
            .store(in: &cancellables)
    }

    private func processTextContent(_ content: String) {
        guard configuration.enableAutoDetection else { return }

        // Parse links and tags
        let analysis = linkParser.parseContent(content)

        currentLinks = analysis.wikiLinks
        currentTags = analysis.tags

        // Update link manager if we have a note ID
        if let noteID = currentNoteID {
            Task {
                await linkManager.updateLinks(for: noteID, content: content)

                // Get validation results
                let validation = linkManager.validationResults[noteID]
                await MainActor.run {
                    self.validationResults = validation
                }
            }
        }

        // Apply syntax highlighting if enabled
        if configuration.enableSyntaxHighlighting {
            applySyntaxHighlighting()
        }
    }

    private func handleSelectionChange() {
        guard let textView = textView else { return }

        let selectedRange = textView.selectedRange()

        // Check if cursor is at the end of a potential link
        if selectedRange.length == 0 {
            let location = selectedRange.location

            // Check for partial link typing
            if location > 2 {
                let searchRange = NSRange(
                    location: max(0, location - 50),
                    length: min(50, location)
                )

                if let range = Range(searchRange, in: textView.string) {
                    let searchText = String(textView.string[range])

                    // Look for incomplete wiki links
                    if let linkMatch = searchText.range(
                        of: #"\[\[([^\]]+)$"#, options: .regularExpression)
                    {
                        let partialLink = String(searchText[linkMatch])
                            .replacingOccurrences(of: "[[", with: "")

                        if partialLink.count > 1 {
                            showAutoCompletion(for: partialLink)
                            return
                        }
                    }
                }
            }
        }

        // Hide auto-completion if not in a relevant context
        hideAutoCompletion()
    }

    private func applySyntaxHighlighting() {
        guard let textView = textView,
            let textStorage = textView.textStorage
        else { return }

        // Remove existing link attributes
        textStorage.removeAttribute(
            .foregroundColor, range: NSRange(location: 0, length: textStorage.length))
        textStorage.removeAttribute(
            .underlineStyle, range: NSRange(location: 0, length: textStorage.length))

        // Highlight valid links
        for link in currentLinks {
            let color: NSColor = link.isValid ? .systemBlue : .systemOrange

            textStorage.addAttribute(.foregroundColor, value: color, range: link.range)
            textStorage.addAttribute(
                .underlineStyle, value: NSUnderlineStyle.single.rawValue, range: link.range)
        }

        // Highlight tags
        for tag in currentTags {
            textStorage.addAttribute(
                .foregroundColor, value: NSColor.systemPurple, range: tag.range)
        }
    }
}

// MARK: - Text View Delegate

private class LinkingTextViewDelegate: NSObject, NSTextViewDelegate {
    weak var integration: EditorLinkingIntegration?

    init(integration: EditorLinkingIntegration) {
        self.integration = integration
        super.init()
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let integration = integration else { return false }

        // Check if it's a wiki link
        if let wikiLink = integration.getLinkAt(location: charIndex) {
            // Handle wiki link click - could open the target note
            NotificationCenter.default.post(
                name: .wikiLinkClicked,
                object: wikiLink,
                userInfo: ["noteID": integration.currentNoteID as Any]
            )
            return true
        }

        // Let the system handle other links
        return false
    }

    func textView(
        _ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        // Allow all text changes
        return true
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        // This will be handled by the integration's observer
    }
}

// MARK: - SwiftUI Integration

/// SwiftUI view for auto-completion overlay
public struct LinkAutoCompletionView: View {
    @ObservedObject var integration: EditorLinkingIntegration
    let onSuggestionSelected: (String) -> Void

    public var body: some View {
        if integration.isShowingAutoCompletion && !integration.autoCompletionSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(integration.autoCompletionSuggestions, id: \.self) { suggestion in
                    Button(action: {
                        onSuggestionSelected(suggestion)
                        integration.hideAutoCompletion()
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.secondary)

                            Text(suggestion)
                                .font(.caption)

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(Color.clear)
                    .onHover { hovering in
                        if hovering {
                            // Could add hover highlighting here
                        }
                    }

                    if suggestion != integration.autoCompletionSuggestions.last {
                        Divider()
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 4)
            .frame(maxWidth: 300)
        }
    }
}

/// SwiftUI view for link status indicator
public struct LinkStatusView: View {
    @ObservedObject var integration: EditorLinkingIntegration

    public var body: some View {
        HStack {
            // Link count
            if !integration.currentLinks.isEmpty {
                Label("\(integration.currentLinks.count)", systemImage: "link")
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            // Tag count
            if !integration.currentTags.isEmpty {
                Label("\(integration.currentTags.count)", systemImage: "tag")
                    .font(.caption)
                    .foregroundColor(.purple)
            }

            // Broken links warning
            if let validation = integration.validationResults,
                !validation.brokenLinks.isEmpty
            {
                Label("\(validation.brokenLinks.count)", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - Toolbar Integration

/// Toolbar buttons for linking functionality
public struct LinkingToolbarButtons: View {
    @ObservedObject var integration: EditorLinkingIntegration
    @State private var showingLinkDialog = false
    @State private var showingTagDialog = false

    public var body: some View {
        Group {
            // Insert link button
            Button(action: { showingLinkDialog = true }) {
                Image(systemName: "link.badge.plus")
            }
            .help("Insert Link")

            // Insert tag button
            Button(action: { showingTagDialog = true }) {
                Image(systemName: "tag.fill")
            }
            .help("Insert Tag")

            // Convert selection to link
            Button(action: {
                integration.convertSelectionToWikiLink()
            }) {
                Image(systemName: "link")
            }
            .help("Convert Selection to Link")
        }
        .sheet(isPresented: $showingLinkDialog) {
            LinkInsertionDialog(integration: integration)
        }
        .sheet(isPresented: $showingTagDialog) {
            TagInsertionDialog(integration: integration)
        }
    }
}

// MARK: - Dialog Views

struct LinkInsertionDialog: View {
    @ObservedObject var integration: EditorLinkingIntegration
    @Environment(\.dismiss) var dismiss

    @State private var linkTarget = ""
    @State private var displayText = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Insert Link")
                .font(.headline)

            TextField("Link Target", text: $linkTarget)
                .textFieldStyle(.roundedBorder)

            TextField("Display Text (optional)", text: $displayText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Insert") {
                    let display = displayText.isEmpty ? nil : displayText
                    integration.insertWikiLink(target: linkTarget, displayText: display)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(linkTarget.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct TagInsertionDialog: View {
    @ObservedObject var integration: EditorLinkingIntegration
    @Environment(\.dismiss) var dismiss

    @State private var tagName = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Insert Tag")
                .font(.headline)

            TextField("Tag Name", text: $tagName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Insert") {
                    integration.insertHashtag(tagName)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(tagName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let wikiLinkClicked = Notification.Name("wikiLinkClicked")
}

// MARK: - Preview

struct EditorLinkingIntegration_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Editor Linking Integration Preview")
                .font(.title)
            Text("Requires vault path to initialize properly")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
