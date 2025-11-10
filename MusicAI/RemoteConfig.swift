import Foundation
import Combine

final class RemoteConfig: ObservableObject {
    static let shared = RemoteConfig()
    static let didUpdateNotification = Notification.Name("remoteConfigDidUpdate")

    // Worker JSON URL（換成你自己的 Cloudflare Worker 網址）
    private let endpoint = URL(string: "https://ai-music-client-url-json.ian20040409.workers.dev/")!

    /// 當前生效的首頁 URL
    @Published var currentHomeURL: URL?

    private init() {
        // 載入快取（上次成功的設定）
        if let cached = UserDefaults.standard.string(forKey: "remote_home_url"),
           let url = URL(string: cached) {
            self.currentHomeURL = url
        }
    }

    /// 抓取遠端設定（會自動更新 currentHomeURL）
    func fetchConfig() {
        let request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard error == nil,
                  let data = data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let urlStr = obj["home_url"] as? String,
                  let newURL = URL(string: urlStr)
            else { return }

            // 寫入快取
            UserDefaults.standard.set(urlStr, forKey: "remote_home_url")

            DispatchQueue.main.async {
                self.currentHomeURL = newURL
                NotificationCenter.default.post(name: RemoteConfig.didUpdateNotification, object: newURL)
            }
        }.resume()
    }
}
