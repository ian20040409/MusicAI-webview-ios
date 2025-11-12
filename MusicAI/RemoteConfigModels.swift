import Foundation

/// 遠端設定 JSON 對應的資料模型（供 RemoteConfig 與 Inspector 共用）
struct RemoteConfigPayload: Decodable {
    let homeURL: String?
    let userAgent: String?
    let showShareOptions: Bool?
    let externalAppURL: String?
    let version: Int?

    enum CodingKeys: String, CodingKey {
        case homeURL = "home_url"
        case userAgent = "user_agent"
        case showShareOptions = "show_share_options"
        case externalAppURL = "external_app_url"
        case version
    }
}

// MARK: - UI 輔助
extension RemoteConfigPayload {
    var showShareDescription: String? {
        showShareOptions.map { $0 ? "true" : "false" }
    }

    var versionDescription: String? {
        version.map(String.init)
    }
}
