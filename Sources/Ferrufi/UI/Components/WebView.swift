//
//  WebView.swift
//  Ferrufi
//
//  WebKit integration for displaying rendered HTML content
//

import SwiftUI
import WebKit

public struct WebView: NSViewRepresentable {
    let htmlContent: String

    public init(htmlContent: String) {
        self.htmlContent = htmlContent
    }

    public func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        // Enable smooth scrolling
        if #available(macOS 13.3, *) {
            webView.isInspectable = false
        }

        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        print("🌐 WebView updateNSView called")
        print("📄 HTML content length: \(htmlContent.count)")
        print("📄 HTML preview: \(String(htmlContent.prefix(100)))...")

        if !htmlContent.isEmpty {
            webView.loadHTMLString(htmlContent, baseURL: nil)
            print("✅ WebView loadHTMLString called")
        } else {
            print("⚠️ HTML content is empty, not loading")
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        public func webView(
            _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            print("🌐 WebView navigation decision requested")
            if let url = navigationAction.request.url {
                print("🔗 URL: \(url.absoluteString)")
            }

            // Handle wiki links and internal navigation
            if let url = navigationAction.request.url,
                url.scheme == "file" || url.absoluteString.hasPrefix("about:")
            {
                print("✅ Allowing file/about URL")
                decisionHandler(.allow)
                return
            }

            // Handle wiki links
            if let url = navigationAction.request.url,
                url.fragment != nil
            {
                // This is an internal link (wiki link)
                NotificationCenter.default.post(
                    name: NSNotification.Name("WikiLinkTapped"),
                    object: url.fragment
                )
                decisionHandler(.cancel)
                return
            }

            // Handle external links
            if let url = navigationAction.request.url,
                url.scheme == "http" || url.scheme == "https"
            {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        public func webView(
            _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
        ) {
            print("❌ WebView failed to load: \(error)")
        }

        public func webView(
            _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            print("❌ WebView provisional navigation failed: \(error)")
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WebView finished loading")

            // Inject CSS for better scrollbar appearance
            let css = """
                    ::-webkit-scrollbar {
                        width: 8px;
                    }
                    ::-webkit-scrollbar-track {
                        background: transparent;
                    }
                    ::-webkit-scrollbar-thumb {
                        background: rgba(0, 0, 0, 0.3);
                        border-radius: 4px;
                    }
                    ::-webkit-scrollbar-thumb:hover {
                        background: rgba(0, 0, 0, 0.5);
                    }
                    @media (prefers-color-scheme: dark) {
                        ::-webkit-scrollbar-thumb {
                            background: rgba(255, 255, 255, 0.3);
                        }
                        ::-webkit-scrollbar-thumb:hover {
                            background: rgba(255, 255, 255, 0.5);
                        }
                    }
                """

            let script = """
                    var style = document.createElement('style');
                    style.type = 'text/css';
                    style.innerHTML = '\(css)';
                    document.head.appendChild(style);

                    console.log('WebView loaded successfully');
                    console.log('Document body: ', document.body.innerHTML.substring(0, 200));
                """

            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("❌ JavaScript error: \(error)")
                } else {
                    print("✅ JavaScript executed successfully")
                }
            }
        }
    }
}

// MARK: - Preview WebView

public struct PreviewWebView: View {
    let content: String

    public init(content: String) {
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Preview header
            HStack {
                Image(systemName: "eye")
                    .foregroundColor(.secondary)
                Text("Preview")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))

            // WebView content
            WebView(htmlContent: content)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
