import SwiftUI
import WebKit
/// 封裝 WKWebView 的 UIViewRepresentable
struct WebView: UIViewRepresentable {
    let webView: WKWebView
    @Binding var showToolbar: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        webView.scrollView.delegate = context.coordinator
        // 在底部工具列高度 (約56pt) 預留空間，不讓內容被擋住
        let toolbarHeight: CGFloat = 56
        webView.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: toolbarHeight, right: 0)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.scrollIndicatorInsets = webView.scrollView.contentInset
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 無需更新
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        let parent: WebView
        init(parent: WebView) { self.parent = parent }
        private var lastContentOffsetY: CGFloat = 0
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let offsetY = scrollView.contentOffset.y
            let height = scrollView.bounds.height
            let contentHeight = scrollView.contentSize.height
            // 到底部判定
            if offsetY + height >= contentHeight - 10 {
                parent.showToolbar = true
            }
            // 快速向上滑動判定
            let delta = offsetY - lastContentOffsetY
            if delta < -20 {
                parent.showToolbar = true
            }
            lastContentOffsetY = offsetY
        }
    }
}

// 為了避免因 WKWebView 不是 Sendable 的警告，將 ContentView 限制在主執行緒上
@MainActor
struct ContentView: View {
    @State private var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        // 允許接受所有 cookie，確保 ReCAPTCHA cookie 正常運作
        HTTPCookieStorage.shared.cookieAcceptPolicy = .always
        
        let webpagePrefs = WKWebpagePreferences()
        webpagePrefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = webpagePrefs
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        // 如需攔截或注入腳本，可使用 userContentController
        config.userContentController = WKUserContentController()
       
        let zoomDisableScript = """
        var meta = document.createElement('meta');
        meta.name = 'viewport';
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
        document.head.appendChild(meta);
        """
        let userScript = WKUserScript(source: zoomDisableScript,
                                      injectionTime: .atDocumentEnd,
                                      forMainFrameOnly: true)
        config.userContentController.addUserScript(userScript)
       
        let webView = WKWebView(frame: .zero, configuration: config)
        // Mimic Safari to support reCAPTCHA
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        return webView
    }()
    @State private var showShareSheet = false
    @State private var showExportView = false
    @State private var isLongPressing = false
    @State private var showToolbar = false  // 控制工具列顯示
    @State private var showingURLPrompt = false
    @State private var newURLString = ""
    @State private var showingShareOptions = false
    
    let url = URL(string: "http://100.86.143.102:5000/")!
    //let url = URL(string: "https://100.86.143.102:5000/")!
    //let url = URL(string: "https://google.com/")!
    
    
    
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            WebView(webView: webView, showToolbar: $showToolbar)
                .onAppear {
                    let request = URLRequest(url: url)
                    webView.load(request)
                }

            // Safari 風格底部工具列
            VStack {
                Spacer()
                HStack(spacing: 40) {
                    Button(action: {
                        let homeRequest = URLRequest(url: url)
                        webView.load(homeRequest)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.primary)
                    }
                    Button(action: {
                        showingShareOptions = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(.ultraThickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                .shadow(radius: 5)
                .padding(.bottom, 16)
            }
            .opacity(showToolbar ? 1 : 0)
            .animation(.easeInOut, value: showToolbar)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                showToolbar = true
            }
        }
        .onAppear {
            // 首次顯示後自動隱藏工具列
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                withAnimation { showToolbar = false }
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .sheet(isPresented: $showShareSheet) {
            if let shareURL = webView.url {
                ShareSheet(activityItems: [shareURL])
            }
        }
        .confirmationDialog("分享選項", isPresented: $showingShareOptions) {
            Button("分享此頁面") {
                showShareSheet = true
            }
            Button("更改網址") {
                showingURLPrompt = true
            }
            Button("刪除所有瀏覽器資料") {
                let dataStore = WKWebsiteDataStore.default()
                let types = WKWebsiteDataStore.allWebsiteDataTypes()
                dataStore.removeData(ofTypes: types, modifiedSince: Date.distantPast) {
                    let homeRequest = URLRequest(url: url)
                    webView.load(homeRequest)
                }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("更改網址", isPresented: $showingURLPrompt) {
            TextField("請輸入新網址", text: $newURLString)
            Button("確定") {
                if let newURL = URL(string: newURLString) {
                    let request = URLRequest(url: newURL)
                    webView.load(request)
                }
            }
            Button("取消", role: .cancel) { }
        }
        .onChange(of: showToolbar) { visible in
            if visible {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { showToolbar = false }
                }
            }
        }
    }
}

// UIKit 分享控制器包裝
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

#if canImport(UIKit)
import UIKit
/// 使用自訂 HostingController 隱藏 Home Indicator
class HostingController: UIHostingController<ContentView> {
    //override var prefersHomeIndicatorAutoHidden: Bool {  }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .darkContent
    }
}
#endif
