import Foundation
import Combine

final class RemoteConfig: ObservableObject {
    static let shared = RemoteConfig()
    static let didUpdateNotification = Notification.Name("remoteConfigDidUpdate")

    // Worker JSON URL（換成你自己的 Cloudflare Worker 網址）
    private let endpoint = URL(string: "https://ai-music-client-url-json.ian20040409.workers.dev/")!

    // UserDefaults keys
    private let kCachedHome = "remote_home_url"
    private let kCachedVer  = "remote_config_version"

    /// 當前生效的首頁 URL
    @Published var currentHomeURL: URL?

    private init() {
        // 載入上次成功的設定
        if let cached = UserDefaults.standard.string(forKey: kCachedHome),
           let url = URL(string: cached) {
            self.currentHomeURL = url
        }
    }

    /// 抓取遠端設定（會自動更新 currentHomeURL）
    func fetchConfig() {
        // 以 timestamp 查詢參數避開任何中間層快取
        var requestURL = endpoint
        if var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) {
            comps.queryItems = (comps.queryItems ?? []) + [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
            requestURL = comps.url ?? endpoint
        }

        var request = URLRequest(url: requestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        // 嚴格禁用快取（瀏覽器/iOS/中介）
        request.setValue("no-store, no-cache, must-revalidate", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")

        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        let session = URLSession(configuration: config)

        session.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }
            guard error == nil, let data = data else { return }

            // 解析 JSON
            guard
                let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                let urlStr = obj["home_url"] as? String,
                let newURL = URL(string: urlStr)
            else { return }
            print("Config JSON:", obj)

            let remoteVer = (obj["version"] as? Int) ?? 0
            let localVer  = UserDefaults.standard.integer(forKey: self.kCachedVer)

            // 若版本未提升且網址與快取相同，則不觸發更新
            let cachedURLStr = UserDefaults.standard.string(forKey: self.kCachedHome)
            let isSameURL = (cachedURLStr == urlStr)
            if remoteVer <= localVer && isSameURL {
                return
            }

            // 寫入快取
            UserDefaults.standard.set(urlStr, forKey: self.kCachedHome)
            UserDefaults.standard.set(remoteVer, forKey: self.kCachedVer)

            DispatchQueue.main.async {
                self.currentHomeURL = newURL
                NotificationCenter.default.post(name: RemoteConfig.didUpdateNotification, object: newURL)
            }
        }.resume()
    }
}
