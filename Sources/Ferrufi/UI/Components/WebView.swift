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
        
        // Add script message handler for running code
        configuration.userContentController.add(context.coordinator, name: "ferrufiRunCode")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        // Enable smooth scrolling
        if #available(macOS 13.3, *) {
            webView.isInspectable = true // Set to true for debugging
        }

        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        if !htmlContent.isEmpty {
            webView.loadHTMLString(htmlContent, baseURL: nil)
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        var webView: WKWebView?

        init(_ parent: WebView) {
            self.parent = parent
        }
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "ferrufiRunCode", let body = message.body as? [String: Any],
               let code = body["code"] as? String,
               let id = body["id"] as? String {
                
                // We need a way to send the output back to this specific WebView instance.
                // Store the blockId in the notification userInfo so listeners know which block to update.
                NotificationCenter.default.post(
                    name: .runMufiInPreview, 
                    object: code, 
                    userInfo: ["blockId": id, "coordinator": self]
                )
            }
        }
        
        public func updateOutput(id: String, output: String) {
            let escapedOutput = output.replacingOccurrences(of: "\\", with: "\\\\")
                                     .replacingOccurrences(of: "\"", with: "\\\"")
                                     .replacingOccurrences(of: "\n", with: "\\n")
                                     .replacingOccurrences(of: "\r", with: "")
            
            let js = "window.updateMufiOutput('\(id)', \"\(escapedOutput)\");"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        public func webView(
            _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            self.webView = webView
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
            // Inject CSS for better scrollbar appearance and general styling
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
                    @media (prefers-color-scheme: dark) {
                        ::-webkit-scrollbar-thumb {
                            background: rgba(255, 255, 255, 0.3);
                        }
                    }
                """

            let js = """
                (function() {
                    var style = document.createElement('style');
                    style.innerHTML = `\(css)`;
                    document.head.appendChild(style);
                })();
            """

            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}

// MARK: - Sample WebView

public struct SampleWebView: View {
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
                Text("Rendered HTML")
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
