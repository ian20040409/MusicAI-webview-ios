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
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 主選單視圖 (App 進入點)
struct MainMenuView: View {
    // 環境變數，用於打開 URL
    @Environment(\.openURL) private var openURL
    
    // 請將 "yourotherapp://" 替換成您想打開的 App 的 URL Scheme
    private let otherAppURLScheme = "unitymusicapp1007://"

    var body: some View {
        // 使用 NavigationStack 來管理頁面導航
        NavigationStack {
            ZStack {
                // 背景漸層
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.black]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 30) {
                    // App 標題
                    VStack {
                        Image(systemName: "apple.haptics.and.music.note")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        Text("MusicAI")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 40)

                    // 導航到 WebView 的按鈕
                    NavigationLink(destination: WebViewContainerView()) {
                        MenuButton(title: "進入Ai Chatbot", icon: "sparkles")
                    }
                    .buttonStyle(PressableButtonStyle())
                    .simultaneousGesture(TapGesture().onEnded {
                        Haptics.mediumImpact()
                    })
                    
                    // 打開另一個 App 的按鈕
                    Button(action: {
                        Haptics.success()
                        openOtherApp()
                    }) {
                        MenuButton(title: "打開樂伴 (UnityApp)", icon: "arrow.up.forward.app")
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding()
            }
            .navigationTitle("主選單")
            .statusBarHidden(true)
            .navigationBarHidden(true) // 隱藏導航列標題
        }
        .statusBarHidden(true)
    }

    /// 嘗試打開另一個 App 的 URL Scheme
    private func openOtherApp() {
        guard let url = URL(string: otherAppURLScheme) else {
            print("無效的 URL Scheme: \(otherAppURLScheme)")
            return
        }
        
        // 使用 openURL 來打開外部連結
        openURL(url) { accepted in
            if !accepted {
                print("無法打開此 URL Scheme，可能尚未安裝對應的 App。")
                // 在這裡可以加入提示用戶的 UI，例如一個 Alert
            }
        }
    }
}

// MARK: - 主選單按鈕樣式
struct MenuButton: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title)
                .fontWeight(.semibold)
        }
        .font(.headline)
        .foregroundColor(.white)
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
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

