import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL

        static let baseURLString = "http://127.0.0.1:18789?token=127b26a2b269fe4d29f26d7288bba5c4092ef55c52a6bf20"
    private static let sidebarHidingCSS = """
    body > openclaw-app { }
    [role=complementary] { display: none !important; }
    [role=banner] { display: none !important; }
    main { margin-left: 0 !important; }
    """

    static func url(for panel: Panel) -> URL {
        guard var components = URLComponents(string: baseURLString) else {
            return URL(string: baseURLString) ?? URL(string: "http://127.0.0.1:18789")!
        }
        components.path = panel.path
        return components.url ?? URL(string: baseURLString)!
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController = makeContentController()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.load(URLRequest(url: url))
        context.coordinator.lastURL = url
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard context.coordinator.lastURL != url else { return }
        context.coordinator.lastURL = url

        let escapedURL = Self.javaScriptEscapedString(url.absoluteString)
        let script = "window.location.href = '\(escapedURL)';"
        nsView.evaluateJavaScript(script) { _, error in
            if error != nil {
                nsView.load(URLRequest(url: url))
            }
        }
    }

    private func makeContentController() -> WKUserContentController {
        let controller = WKUserContentController()
        controller.addUserScript(Self.makeSidebarHidingScript())
        return controller
    }

    private static func makeSidebarHidingScript() -> WKUserScript {
        let escapedCSS = javaScriptEscapedString(sidebarHidingCSS)
        let source = """
        const style = document.createElement('style');
        style.textContent = '\(escapedCSS)';
        document.head.appendChild(style);
        """
        return WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    }

    private static func javaScriptEscapedString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    final class Coordinator {
        var lastURL: URL?
    }
}
