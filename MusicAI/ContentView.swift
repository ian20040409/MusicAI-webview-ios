import SwiftUI
import WebKit

// MARK: - WebView 容器視圖
@MainActor
struct WebViewContainerView: View {
    // ▼ 新增：取得環境中的 dismiss 動作，用於返回上一頁
    @Environment(\.dismiss) private var dismiss

    @State private var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        HTTPCookieStorage.shared.cookieAcceptPolicy = .always
        
        let webpagePrefs = WKWebpagePreferences()
        webpagePrefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = webpagePrefs
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
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
        // 讓 WebView 背景透明
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }()
    
    @State private var showShareSheet = false
    @State private var showingURLPrompt = false
    @State private var newURLString = ""
    @State private var showingShareOptions = false
    
    let url = URL(string: "https://lnu.nttu.edu.tw/app/")!
    
    var body: some View {
        ZStack {
            // 將背景改回黑色，或任何您喜歡的顏色
            Color.black.ignoresSafeArea()
            
            WebView(webView: webView)
                .onAppear {
                    let request = URLRequest(url: url)
                    webView.load(request)
                }
                // 移除邊距和圓角，並確保忽略所有安全區域
                .ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        // ▼ 新增：隱藏系統預設的返回按鈕
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // ▼ 新增：在左上角加入自訂的選單按鈕
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // 呼叫 dismiss 來返回主選單
                    dismiss()
                }) {
                    Image(systemName: "line.3.horizontal") // 使用漢堡選單圖示
                }
            }
            
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


// MARK: - 輔助視圖

/// 封裝 WKWebView 的 UIViewRepresentable
struct WebView: UIViewRepresentable {
    let webView: WKWebView
    
    func makeUIView(context: Context) -> WKWebView {
        // 設定 navigationDelegate，以便追蹤網頁載入狀態
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 無需更新
    }
    
    // 建立 Coordinator 來處理代理事件
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Coordinator 類別，負責監聽網頁載入完成事件
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        // 當網頁內容載入完成時，這個方法會被呼叫
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 設定要向上捲動的距離，您可以根據需求調整這個數值
           
            let scrollPoint = CGPoint(x: 0, y: 10)
            
            // 使用動畫讓捲動看起來更平滑
            webView.scrollView.setContentOffset(scrollPoint, animated: true)
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

