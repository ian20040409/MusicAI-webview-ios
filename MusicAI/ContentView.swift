import SwiftUI
import WebKit

/// 封裝 WKWebView 的 UIViewRepresentable
struct WebView: UIViewRepresentable {
    let webView: WKWebView
    
    func makeUIView(context: Context) -> WKWebView {
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 無需更新
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
        
        return webView
    }()
    
    @State private var showShareSheet = false
    @State private var showingURLPrompt = false
    @State private var newURLString = ""
    @State private var showingShareOptions = false
    
    let url = URL(string: "https://lnu.nttu.edu.tw/app/")!
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 維持黑色背景，避免網頁透明或載入時閃爍白邊
                Color.black.ignoresSafeArea()
                
                WebView(webView: webView)
                    .onAppear {
                        let request = URLRequest(url: url)
                        webView.load(request)
                    }
                    // ▼▼▼ 修改此處 ▼▼▼
                    .ignoresSafeArea() // 讓 WebView 忽略所有安全區域，以佔滿全螢幕
                    // ▲▲▲ 修改此處 ▲▲▲
                    .toolbar {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Button(action: {
                                if webView.canGoBack {
                                    webView.goBack()
                                }
                            }) {
                                Image(systemName: "chevron.backward")
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                let homeRequest = URLRequest(url: url)
                                webView.load(homeRequest)
                            }) {
                                Image(systemName: "house")
                            }
                            
                            Button(action: {
                                showingShareOptions = true
                            }) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
            }
        }
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
    //override var prefersHomeIndicatorAutoHidden: Bool { true }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .darkContent
    }
}
#endif
