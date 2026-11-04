import SwiftUI
import WebKit

/// A page to show inside the app (legal pages, push links). We never hand users to an external browser for these,
/// and payment never uses web views at all (Paylink SDK form only).
struct WebPage: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var title: LocalizedStringKey? = nil
    static func == (l: WebPage, r: WebPage) -> Bool { l.id == r.id }
}

/// In-app web sheet: branded header, progress, https-only navigation inside the page's own site.
struct WebSheet: View {
    let page: WebPage
    @Environment(\.dismiss) private var dismiss
    @State private var progress: Double = 0
    @State private var failed = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                WebContainer(url: page.url, progress: $progress, failed: $failed)
                if progress < 1 && !failed { ProgressView(value: progress).tint(Color.accentFill).transition(.opacity) }
                if failed {
                    EmptyState(icon: .alert, title: "web.failed_title", message: "web.failed_body", actionTitle: "common.close") { dismiss() }
                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.surface)
                }
            }
            .background(Color.surface)
            .navigationTitle(page.title.map { Text($0) } ?? Text(verbatim: page.url.host ?? ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Text("common.close") } } }
        }
        .brandSheetBackground()
    }
}

private struct WebContainer: UIViewRepresentable {
    let url: URL
    @Binding var progress: Double
    @Binding var failed: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .nonPersistent()   // no cookies/credentials kept from legal pages
        let v = WKWebView(frame: .zero, configuration: cfg)
        v.navigationDelegate = context.coordinator
        v.isOpaque = false
        v.backgroundColor = UIColor(Color.surface)
        v.scrollView.backgroundColor = UIColor(Color.surface)
        context.coordinator.observe(v)
        v.load(URLRequest(url: url))
        return v
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebContainer
        private var obs: NSKeyValueObservation?
        init(_ p: WebContainer) { parent = p }
        func observe(_ v: WKWebView) { obs = v.observe(\.estimatedProgress, options: .new) { [weak self] v, _ in DispatchQueue.main.async { self?.parent.progress = v.estimatedProgress } } }
        func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // https (and http only for local dev hosts) stays in the sheet; other schemes are dropped.
            let s = a.request.url?.scheme
            decisionHandler(s == "https" || s == "about" || (s == "http" && AppConfig.isDebug) ? .allow : .cancel)
        }
        func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { DispatchQueue.main.async { self.parent.failed = true } }
        func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { DispatchQueue.main.async { self.parent.failed = true } }
    }
}
