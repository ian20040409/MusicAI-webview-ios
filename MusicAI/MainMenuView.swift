import SwiftUI
import UIKit

// MARK: - Haptics Helper & Button Style
struct Haptics {
    static func lightImpact() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func mediumImpact() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavyImpact() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.81 : 1.0)
            .animation(.easeInOut(duration: 0.152), value: configuration.isPressed)
    }
}

// MARK: - 主選單視圖 (App 進入點)
struct MainMenuView: View {
    // 環境變數，用於打開 URL
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var externalAppURL: URL = MainMenuView.initialExternalURL()

    var body: some View {
        TabView {
            mainMenuContent
                .tabItem {
                    Label("主選單", systemImage: "safari")
                }

            RemoteConfigInspectorView()
                .tabItem {
                    Label("遠端設定", systemImage: "gearshape.arrow.trianglehead.2.clockwise.rotate.90")
                }
        }
        .applySidebarAdaptableTabStyle() // iPad 上自動切換為側邊欄樣式（iOS 18+）
        .statusBarHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: .remoteUIFlagsDidUpdate)) { note in
            if let urlString = note.userInfo?["external_app_url"] as? String,
               let url = URL(string: urlString) {
                externalAppURL = url
            }
        }
    }

    private var mainMenuContent: some View {
        // 使用 NavigationStack 來管理頁面導航
        NavigationStack {
            ZStack {
                // 背景漸層
                LinearGradient(
                    gradient: Gradient(colors: backgroundGradientColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(colorScheme == .dark ? 0.6 : 0.8)
                .ignoresSafeArea()

                VStack(spacing: 30) {
                    // App 標題
                    VStack {
                        Image(systemName: "apple.haptics.and.music.note")
                            .font(.system(size: 60))
                            .foregroundColor(.primary)
                        Text("MusicAI")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .padding(.bottom, 40)

                    // 導航到 WebView 的按鈕
                    NavigationLink(destination: WebViewContainerView()) {
                        MenuButton(title: "進入Ai Chatbot", icon: "sparkles")
                    }
                    .buttonStyle(PressableButtonStyle())
                    .simultaneousGesture(TapGesture().onEnded {
                        Haptics.success()
                    })
                    
                    // 打開另一個 App 的按鈕
                    Button(action: {
                        Haptics.heavyImpact()
                        openOtherApp()
                    }) {
                        MenuButton(title: "打開樂伴 (UnityApp)", icon: "arrow.up.forward.app")
                    }
                    .buttonStyle(PressableButtonStyle())
                    /*
                    #if DEBUG
                    // 🧪 Debug：測試 Toast 顯示
                    Button(action: {
                        Haptics.lightImpact()
                        ToastCenter.shared.show(
                            title: "Toast 測試",
                            message: "這是一則內建 Toast 提示",
                            symbolName: "sparkles",
                            
                        )
                    }) {
                        MenuButton(title: "🧪 測試 Toast", icon: "wand.and.stars")
                    }
                    .buttonStyle(PressableButtonStyle())
                    #endif
                     */
                }
                .onAppear {
                    // 主畫面出現時自動更新遠端設定（從 Cloudflare Worker 抓 config.json）
                    print("🔄 正在更新遠端設定...")
                    RemoteConfig.shared.fetchConfig()
                }
                .padding()
            }
            .navigationTitle("主選單")
            .statusBarHidden(true)
            .navigationBarHidden(true) // 隱藏導航列標題
        }
    }

    /// 嘗試打開另一個 App 的 URL Scheme
    private func openOtherApp() {
        // 使用 openURL 來打開外部連結
        openURL(externalAppURL) { accepted in
            if !accepted {
                print("無法打開此 URL Scheme，可能尚未安裝對應的 App。")
                // 在這裡可以加入提示用戶的 UI，例如一個 Alert
            }
        }
    }

    private static func initialExternalURL() -> URL {
        if let cached = UserDefaults.standard.string(forKey: RemoteConfig.Defaults.remoteExternalAppURL),
           let url = URL(string: cached) {
            return url
        }
        return URL(string: RemoteConfig.defaultExternalAppURL)!
    }
    
    private var backgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.08, green: 0.08, blue: 0.12),
                Color(red: 0.15, green: 0.18, blue: 0.28)
            ]
        } else {
            return [
                Color(red: 0.95, green: 0.97, blue: 1.0),
                Color(red: 0.78, green: 0.86, blue: 1.0)
            ]
        }
    }
}

// MARK: - 主選單按鈕樣式
struct MenuButton: View {
    let title: String
    let icon: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let textColor: Color = colorScheme == .dark ? .white : .primary
        let border = colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.15)
        let effect: Glass = colorScheme == .dark
            ? .regular.tint(.white.opacity(0.2)).interactive()
            : .regular.tint(.white.opacity(0.4)).interactive()
        
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .foregroundColor(textColor)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .center) // 提升可點擊高度
        .padding(.horizontal, 20)
        .background { Color.clear } // 需要一個背景才能確保擴展後區域可被命中
        .glassEffect(in: .rect(cornerRadius: 20.0))
        .contentShape(.rect(cornerRadius: 20.0)) // 讓圓角外觀整體成為可點擊區域
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
        .accessibilityLabel("\(title)")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Helpers: Conditional Sidebar Adaptable TabView Style
extension View {
    @ViewBuilder
    func applySidebarAdaptableTabStyle() -> some View {
        if #available(iOS 18.0, *) {
            self.tabViewStyle(.sidebarAdaptable)
        } else {
            self
        }
    }
}

// MARK: - 預覽
struct MainMenuView_Previews: PreviewProvider {
    static var previews: some View {
        MainMenuView()
    }
}

// MARK: - Hosting Controller
#if canImport(UIKit)
import UIKit
/// 使用自訂 HostingController 隱藏 Home Indicator
class HostingController: UIHostingController<MainMenuView> { // 改為指向 MainMenuView
    //override var prefersHomeIndicatorAutoHidden: Bool { true }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent // 主選單是深色背景，狀態列改為淺色內容
    }
}
#endif
