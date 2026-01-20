import SwiftUI
import WebKit

// MARK: - Native Web View

struct NativeWebView: NSViewRepresentable {
    let url: URL
    let refreshInterval: TimeInterval
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        
        // Disable scrolling for kiosk mode
        webView.enclosingScrollView?.hasVerticalScroller = false
        webView.enclosingScrollView?.hasHorizontalScroller = false
        
        webView.load(URLRequest(url: url))
        
        if refreshInterval > 0 {
            context.coordinator.startRefreshTimer(webView: webView, url: url, interval: refreshInterval)
        }
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // URL changes not supported during display
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        private var timer: Timer?
        
        func startRefreshTimer(webView: WKWebView, url: URL, interval: TimeInterval) {
            timer?.invalidate()
            
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                DispatchQueue.main.async {
                    webView.load(URLRequest(url: url))
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Page loaded successfully
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Web navigation failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Web provisional navigation failed: \(error.localizedDescription)")
        }
        
        deinit {
            timer?.invalidate()
        }
    }
}

// MARK: - Web View Container

struct WebViewerView: View {
    let url: URL
    let refreshInterval: Int
    
    var body: some View {
        NativeWebView(
            url: url,
            refreshInterval: TimeInterval(refreshInterval)
        )
        .ignoresSafeArea()
    }
}

#Preview {
    WebViewerView(
        url: URL(string: "https://apple.com")!,
        refreshInterval: 0
    )
}
