    import Foundation
import Combine

final class RemoteConfig: ObservableObject {
    static let shared = RemoteConfig()
    static let didUpdateNotification = Notification.Name("remoteConfigDidUpdate")
    static let defaultUserAgent = "MusicAI/1.0 (lnu)"
    static let defaultExternalAppURL = "unitymusicapp1007://"
    /// 預設 Cloudflare Worker 端點（可由使用者覆寫）
    static let defaultWorkerEndpoint = URL(string: "https://ai-music-client-url-json.ian20040409.workers.dev/")!
    /// 目前使用的 Worker 端點（若使用者提供合法覆寫則採用覆寫值）
    static var workerEndpoint: URL {
        let defaults = UserDefaults.standard
        if let override = defaults.string(forKey: Defaults.remoteWorkerEndpointOverride),
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let url = URL(string: override) {
            return url
        }
        return defaultWorkerEndpoint
    }

    enum Defaults {
        static let cachedHome = "remote_home_url"
        static let cachedUserAgent = "cachedUserAgent"
        static let remoteShowShareOptions = "remoteShowShareOptions"
        static let remoteExternalAppURL = "remoteExternalAppURL"
        static let remoteWorkerEndpointOverride = "remoteWorkerEndpointOverride"
    }

    // 動態 Worker JSON URL（可由使用者覆寫）

    /// 當前生效的首頁 URL
    @Published var currentHomeURL: URL?

    private init() {
        // 載入上次成功的設定
        if let cached = UserDefaults.standard.string(forKey: Defaults.cachedHome),
           let url = URL(string: cached) {
            self.currentHomeURL = url
        } else {
            self.currentHomeURL = AppURLs.fallback
        }
    }

    /// 抓取遠端設定（會自動更新 currentHomeURL）
    func fetchConfig() {
        // 以 timestamp 查詢參數避開任何中間層快取
        let endpoint = RemoteConfig.workerEndpoint
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
            guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                return
            }

            DispatchQueue.main.async {
                self.applyConfigDictionary(obj)
            }
        }.resume()
    }

    private func applyConfigDictionary(_ obj: [String: Any]) {
        print("Config JSON:", obj)
        let defaults = UserDefaults.standard

        // 1) home_url
        let previousHome = currentHomeURL
        let resolvedHomeURL: URL
        if let urlStr = obj["home_url"] as? String,
           let url = URL(string: urlStr) {
            resolvedHomeURL = url
            defaults.set(urlStr, forKey: Defaults.cachedHome)
        } else if let cached = defaults.string(forKey: Defaults.cachedHome),
                  let url = URL(string: cached) {
            resolvedHomeURL = url
        } else {
            resolvedHomeURL = AppURLs.fallback
        }

        currentHomeURL = resolvedHomeURL
        NotificationCenter.default.post(name: RemoteConfig.didUpdateNotification, object: resolvedHomeURL)

        if previousHome?.absoluteString != resolvedHomeURL.absoluteString {
                NotifyOrToast.send(
                    title: "✨有新的內容✨",
                     body: "✅已部署設定需重開APP套用更新",
                     symbolName: "gear.badge.checkmark"
                 )
             }
     
        // 2) user_agent
        let resolvedUserAgent: String
        if let ua = (obj["user_agent"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !ua.isEmpty {
            resolvedUserAgent = ua
        } else if let cachedUA = defaults.string(forKey: Defaults.cachedUserAgent),
                  !cachedUA.isEmpty {
            resolvedUserAgent = cachedUA
        } else {
            resolvedUserAgent = RemoteConfig.defaultUserAgent
        }
        defaults.set(resolvedUserAgent, forKey: Defaults.cachedUserAgent)
        NotificationCenter.default.post(name: .userAgentDidUpdate, object: resolvedUserAgent)

        // 3) show_share_options + external_app_url
        let resolvedShareOptions: Bool
        if let share = obj["show_share_options"] as? Bool {
            resolvedShareOptions = share
        } else if defaults.object(forKey: Defaults.remoteShowShareOptions) != nil {
            resolvedShareOptions = defaults.bool(forKey: Defaults.remoteShowShareOptions)
        } else {
            resolvedShareOptions = true
        }
        defaults.set(resolvedShareOptions, forKey: Defaults.remoteShowShareOptions)

        let resolvedExternalAppURL: String
        if let external = (obj["external_app_url"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !external.isEmpty {
            resolvedExternalAppURL = external
        } else if let cachedExternal = defaults.string(forKey: Defaults.remoteExternalAppURL),
                  !cachedExternal.isEmpty {
            resolvedExternalAppURL = cachedExternal
        } else {
            resolvedExternalAppURL = RemoteConfig.defaultExternalAppURL
        }
        defaults.set(resolvedExternalAppURL, forKey: Defaults.remoteExternalAppURL)

        NotificationCenter.default.post(
            name: .remoteUIFlagsDidUpdate,
            object: nil,
            userInfo: [
                "show_share_options": resolvedShareOptions,
                "external_app_url": resolvedExternalAppURL
            ]
        )
    }
}

extension Notification.Name {
    static let userAgentDidUpdate = Notification.Name("remoteConfigUserAgentDidUpdate")
    static let remoteUIFlagsDidUpdate = Notification.Name("remoteConfigRemoteUIFlagsDidUpdate")
    static let workerEndpointDidUpdate = Notification.Name("remoteConfigWorkerEndpointDidUpdate")
}

// MARK: - Worker Endpoint Override API
extension RemoteConfig {
    /// 設定或清除 Worker 端點覆寫；傳入 nil 或空字串即為清除
    /// - Returns: 是否成功套用（無效 URL 會回傳 false）
    @discardableResult
    static func setWorkerEndpointOverride(_ urlString: String?) -> Bool {
        let defaults = UserDefaults.standard
        let trimmed = urlString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            defaults.removeObject(forKey: Defaults.remoteWorkerEndpointOverride)
            NotificationCenter.default.post(name: .workerEndpointDidUpdate, object: workerEndpoint)
            return true
        }
        guard let url = URL(string: trimmed), url.scheme?.isEmpty == false else {
            return false
        }
        defaults.set(trimmed, forKey: Defaults.remoteWorkerEndpointOverride)
        NotificationCenter.default.post(name: .workerEndpointDidUpdate, object: url)
        return true
    }
}
