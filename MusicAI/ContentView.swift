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
        .sheet(isPresented: $showingShareOptions) {
            ShareOptionsView(
                showShareSheet: $showShareSheet,
                showingURLPrompt: $showingURLPrompt,
                webView: webView,
                url: url
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("更改網址", isPresented: $showingURLPrompt) {
            TextField("請輸入新網址", text: $newURLString)
            
            Button("取消") { }
            Button("確定") {
                if let newURL = URL(string: newURLString) {
                    let request = URLRequest(url: newURL)
                    webView.load(request)
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

// Official Liquid Glass Button Style following Apple guidelines
struct LiquidGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Share Options View with Enhanced Liquid Glass design
struct ShareOptionsView: View {
    @Binding var showShareSheet: Bool
    @Binding var showingURLPrompt: Bool
    let webView: WKWebView
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearDataAlert = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Enhanced Header with page info
                    VStack(spacing: 12) {
                        // Icon and title
                        HStack {
                            Image(systemName: "safari")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            
                            Text("瀏覽器選項")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        // Current page info card
                        if let currentURL = webView.url {
                            VStack(spacing: 6) {
                                Text(webView.title ?? "載入中...")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                
                                Text(currentURL.host ?? currentURL.absoluteString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.top, 8)
                    
                    // Enhanced Options List with sections
                    VStack(spacing: 20) {
                        
                        // Sharing Section
                        VStack(spacing: 12) {
                            SectionHeader(title: "分享", icon: "square.and.arrow.up")
                            
                            VStack(spacing: 8) {
                                ShareOptionButton(
                                    icon: "square.and.arrow.up",
                                    title: "分享此頁面",
                                    subtitle: "分享當前網頁連結"
                                ) {
                                    dismiss()
                                    showShareSheet = true
                                }
                                
                                ShareOptionButton(
                                    icon: "doc.on.doc",
                                    title: "複製連結",
                                    subtitle: "複製當前頁面網址到剪貼板"
                                ) {
                                    if let currentURL = webView.url {
                                        UIPasteboard.general.string = currentURL.absoluteString
                                        // Add haptic feedback
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                    }
                                    dismiss()
                                }
                            }
                        }
                        
                        // Navigation Section
                        VStack(spacing: 12) {
                            SectionHeader(title: "導航", icon: "location")
                            
                            VStack(spacing: 8) {
                                ShareOptionButton(
                                    icon: "arrow.clockwise",
                                    title: "重新載入",
                                    subtitle: "重新載入當前頁面"
                                ) {
                                    webView.reload()
                                    dismiss()
                                }
                                
                                ShareOptionButton(
                                    icon: "house",
                                    title: "回到首頁",
                                    subtitle: "返回到主頁面"
                                ) {
                                    let homeRequest = URLRequest(url: url)
                                    webView.load(homeRequest)
                                    dismiss()
                                }
                                
                                ShareOptionButton(
                                    icon: "link",
                                    title: "更改網址",
                                    subtitle: "導航到新的網址"
                                ) {
                                    dismiss()
                                    showingURLPrompt = true
                                }
                            }
                        }
                        
                        
                        
                        // Privacy Section
                        VStack(spacing: 12) {
                            SectionHeader(title: "隱私", icon: "hand.raised", isDestructive: true)
                            
                            ShareOptionButton(
                                icon: "trash",
                                title: "清除瀏覽資料",
                                subtitle: "刪除快取、Cookie 和瀏覽記錄",
                                isDestructive: true
                            ) {
                                showingClearDataAlert = true
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical, 20)
            }
            .background(.regularMaterial)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("清除瀏覽資料", isPresented: $showingClearDataAlert) {
            Button("清除", role: .destructive) {
                clearBrowsingData()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("這將會刪除所有快取、Cookie、瀏覽記錄和網站資料。此操作無法復原。")
        }
        .overlay {
            if isLoading {
                LoadingOverlay()
            }
        }
    }
    
    private func clearBrowsingData() {
        isLoading = true
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        
        dataStore.removeData(ofTypes: types, modifiedSince: Date.distantPast) {
            DispatchQueue.main.async {
                isLoading = false
                let homeRequest = URLRequest(url: url)
                webView.load(homeRequest)
                dismiss()
            }
        }
    }
}

// Section Header Component
struct SectionHeader: View {
    let title: String
    let icon: String
    var isDestructive: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(isDestructive ? .red : .secondary)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isDestructive ? .red : .secondary)
                .textCase(.uppercase)
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// Loading Overlay Component
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                
                Text("清除資料中...")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(.regularMaterial, in: .rect(cornerRadius: 16, style: .continuous))
        }
    }
}

// Individual Share Option Button
struct ShareOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isDestructive ? .red : .accentColor)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? .red : .primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(LiquidGlassButtonStyle())
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
