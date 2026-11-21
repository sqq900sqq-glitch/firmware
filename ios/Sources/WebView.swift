import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    let reloadToken: UUID

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastToken != reloadToken || context.coordinator.lastURL != url {
            context.coordinator.lastToken = reloadToken
            context.coordinator.lastURL = url
            webView.load(URLRequest(url: url))
        }
    }

    final class Coordinator {
        var lastToken: UUID?
        var lastURL: URL?
    }
}
