import SwiftUI
import WebKit
import UIKit

// MARK: - WebView 容器視圖
@MainActor
struct WebViewContainerView: View {
    // ▼ 新增：取得環境中的 dismiss 動作，用於返回上一頁
    @Environment(\.dismiss) private var dismiss

    @State private var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        HTTPCookieStorage.shared.cookieAcceptPolicy = .always
        
        // Ensure cookies are persisted and not ephemeral
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        let webpagePrefs = WKWebpagePreferences()
        webpagePrefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = webpagePrefs
        config.allowsInlineMediaPlayback = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.userContentController = WKUserContentController()

        // Append app name to default UA as a fallback (will be ignored if customUserAgent is set)
        config.applicationNameForUserAgent = "lnu"
       
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
        // Set a custom, non-standard User-Agent to bypass ngrok browser warning
        // Note: This replaces the default Safari UA; adjust if some sites depend on it.
        webView.customUserAgent = "MusicAI/1.0 (lnu)"
        // 讓 WebView 背景透明
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        // Preload shared cookies into WKWebView's cookie store
        let cookieStore = config.websiteDataStore.httpCookieStore
        let sharedCookies = HTTPCookieStorage.shared.cookies ?? []
        for cookie in sharedCookies {
            cookieStore.setCookie(cookie)
        }
        
        return webView
    }()
    
    @State private var showShareSheet = false
    @State private var showingURLPrompt = false
    @State private var newURLString = ""
    @State private var showingShareOptions = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var themeBaseColor: UIColor = .systemBackground
    private var safeAreaColor: Color {
        let adjusted: UIColor
        if colorScheme == .dark {
            // 深色模式：顏色深一些（與黑色混合 25%）
            adjusted = themeBaseColor.blended(with: .black, ratio: 0.25)
        } else {
            // 淺色模式：顏色淡一些（與白色混合 70%）
            adjusted = themeBaseColor.blended(with: .white, ratio: 0.7)
        }
        return Color(uiColor: adjusted)
    }

    // MARK: - Toolbar helpers / state
    @State private var isNavigatingHome = false

    /// 簡單的觸覺反饋（在 toolbar 按鈕被點擊時呼叫）
    private func hapticTap() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    /// 可靠地導回首頁（會先同步 cookie、停止當前載入，再載入首頁）
    @MainActor
    private func navigateHome() async {
        guard !isNavigatingHome else { return }
        isNavigatingHome = true
        defer { isNavigatingHome = false }

        // 停掉目前載入，避免 race condition
        webView.stopLoading()

        // 確保 homepage 的 cookies 已同步到 webView 的 cookieStore
        let homeURL = AppURLs.home
        let sharedCookies = HTTPCookieStorage.shared.cookies(for: homeURL) ?? HTTPCookieStorage.shared.cookies ?? []
        if !sharedCookies.isEmpty {
            await setThirdPartyCookies(sharedCookies)
        }

        // 使用 cookie-aware request 進行載入
        let request = makeCookieAwareRequest(for: homeURL)
        webView.load(request)
    }
    
    // MARK: - Third-Party Cookies Helpers
    // Create a third‑party cookie (Secure recommended for SameSite=None)
    private func makeThirdPartyCookie(name: String, value: String, domain: String, path: String = "/", expires: Date? = nil) -> HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain, // e.g. ".example.com" to include subdomains
            .path: path,
            .secure: "TRUE"
        ]
        if let expires { properties[.expires] = expires }
        return HTTPCookie(properties: properties)
    }

    @MainActor
    private func setThirdPartyCookies(_ cookies: [HTTPCookie]) async {
        let store = webView.configuration.websiteDataStore.httpCookieStore
        await withCheckedContinuation { continuation in
            let group = DispatchGroup()
            for cookie in cookies {
                group.enter()
                store.setCookie(cookie) {
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                continuation.resume()
            }
        }
    }
    
    // Sync cookies from shared storage into WKWebView and build a cookie-aware URLRequest
    private func makeCookieAwareRequest(for url: URL) -> URLRequest {
        // Push shared cookies into WKWebView's store
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let sharedCookies = HTTPCookieStorage.shared.cookies(for: url) ?? HTTPCookieStorage.shared.cookies ?? []
        for cookie in sharedCookies {
            cookieStore.setCookie(cookie)
        }
        // Build request with Cookie header for first load if needed
        var request = URLRequest(url: url)
        if !sharedCookies.isEmpty {
            let cookieHeader = sharedCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            request.addValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        return request
    }
    
    let url = AppURLs.home
    
    var body: some View {
        ZStack {
            // 以網頁主題色套用 SafeArea（淺色模式較淡、深色模式較深）
            safeAreaColor.ignoresSafeArea()
            
            WebView(webView: webView)
                .onAppear {
                    Task { @MainActor in
                        // Set any third‑party cookies you require before loading content
                        // Example placeholder (replace with your domains/values or remove if not needed)
                        var thirdPartyCookies: [HTTPCookie] = []
                        if let c = makeThirdPartyCookie(name: "tp_session", value: "example_value", domain: ".thirdparty.example.com") {
                            thirdPartyCookies.append(c)
                        }
                        await setThirdPartyCookies(thirdPartyCookies)

                        let request = makeCookieAwareRequest(for: url)
                        webView.load(request)
                    }
                }
                // 移除邊距和圓角，並確保忽略所有安全區域
                .ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: .webThemeColor)) { note in
            if let hex = note.object as? String, let ui = UIColor(hex: hex) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    themeBaseColor = ui
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // ▼ 修改：顯示系統預設的返回按鈕 (改為 false)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            // Leading: 回到主畫面（Home）按鈕 — 使用 navigateHome() 確保 cookie 與載入一致性
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    hapticTap()
                    Task { @MainActor in
                        await navigateHome()
                    }
                }) {
                    if isNavigatingHome {
                        // 顯示 loading 狀態以回饋使用者
                        ProgressView()
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .padding(5)
                    }
                }
                .disabled(isNavigatingHome)
            }

            // Trailing: 分享 / 選單 按鈕（保留原本的 share options，但加入 haptic）
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    hapticTap()
                    showingShareOptions = true
                }) {
                    Image(systemName: "filemenu.and.pointer.arrow")
                        .padding(5)
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
                    Task { @MainActor in
                        // Optionally set/update third‑party cookies for the new URL context
                        let request = makeCookieAwareRequest(for: newURL)
                        webView.load(request)
                    }
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
            // 讀取 <meta name="theme-color"> 並廣播十六進位色碼（若存在）
            let js = "document.querySelector('meta[name=\\\"theme-color\\\"]')?.getAttribute('content')"
            webView.evaluateJavaScript(js) { result, _ in
                if let colorString = result as? String {
                    NotificationCenter.default.post(name: .webThemeColor, object: colorString)
                }
            }

            // 保留輕微向上捲動（可視需要調整或移除）
            let scrollPoint = CGPoint(x: 0, y: 20)
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


// Share Options View
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
                            Image(systemName: "filemenu.and.pointer.arrow")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            
                            Text("選項")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        // Current page info card - 只顯示標題
                        if let currentURL = webView.url {
                            VStack(spacing: 6) {
                                Text(webView.title ?? "載入中...")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.top, 8)
                    
                    // Enhanced Options List with sections
                    VStack(spacing: 20) {
                        
                        // Navigation Section - 移除首頁功能
                        VStack(spacing: 12) {
                            SectionHeader(title: "導航", icon: "location")
                            
                            VStack(spacing: 8) {
                                ShareOptionButton(
                                    icon: "arrow.clockwise",
                                    title: "重新載入",
                                    subtitle: "重新載入當前頁面"
                                ) {
                                    // Ensure cookies are synced before reload
                                    let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
                                    let currentURL = webView.url
                                    let sharedCookies = (currentURL.flatMap { HTTPCookieStorage.shared.cookies(for: $0) } ?? HTTPCookieStorage.shared.cookies) ?? []
                                    for cookie in sharedCookies {
                                        cookieStore.setCookie(cookie)
                                    }
                                    webView.reload()
                                    dismiss()
                                }
                                
                                //
                                
                                ShareOptionButton(
                                    icon: "memories.slash",
                                    title: "重設",
                                    subtitle: "⚠"
                                ) {
                                   
                                    let request = URLRequest(url: url)
                                    webView.load(request)
                                    dismiss()
                                }
                                
                                
                                ShareOptionButton(
                                    icon: "link",
                                    title: "前往新頁面",
                                    subtitle: "輸入新的網站位置"
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
            .background(
                ZStack {
                    Color.clear
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                    )
                }
            )
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
                // ▼ 修改：清除資料後重新載入當前頁面，而不是返回首頁
                webView.reload()
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
            .background(
                ZStack {
                    Color.clear
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(LiquidGlassButtonStyle())
    }
}


// MARK: - Theme Color Helpers
extension Notification.Name {
    static let webThemeColor = Notification.Name("webThemeColor")
}

extension UIColor {
    /// 支援 #RRGGBB 或 #RRGGBBAA（可包含 # 或不含）
    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        var hexValue: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&hexValue) else { return nil }
        if hexString.count == 6 {
            r = CGFloat((hexValue & 0xFF0000) >> 16) / 255.0
            g = CGFloat((hexValue & 0x00FF00) >> 8) / 255.0
            b = CGFloat((hexValue & 0x0000FF) >> 0) / 255.0
        } else if hexString.count == 8 {
            r = CGFloat((hexValue & 0xFF000000) >> 24) / 255.0
            g = CGFloat((hexValue & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((hexValue & 0x0000FF00) >> 8) / 255.0
            a = CGFloat((hexValue & 0x000000FF) >> 0) / 255.0
        } else {
            return nil
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }

    /// 與另一顏色混合，ratio 範圍 0~1，表示要混入目標顏色的比例
    func blended(with color: UIColor, ratio: CGFloat) -> UIColor {
        let r1 = CIColor(color: self)
        let r2 = CIColor(color: color)
        let t = max(0, min(1, ratio))
        let r = r1.red   * (1 - t) + r2.red   * t
        let g = r1.green * (1 - t) + r2.green * t
        let b = r1.blue  * (1 - t) + r2.blue  * t
        let a = r1.alpha * (1 - t) + r2.alpha * t
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

