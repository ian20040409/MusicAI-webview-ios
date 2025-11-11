import SwiftUI

struct RemoteConfigInspectorView: View {
    @State private var isLoading = false
    @State private var payload: RemoteConfigPayload?
    @State private var errorMessage: String?
    @State private var lastUpdated: Date?

    var body: some View {
        NavigationStack {
            Form {
                Section("抓取狀態") {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("讀取中…")
                        }
                    } else {
                        Text(lastUpdatedLabel)
                            .foregroundColor(.secondary)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section("解析結果") {
                    LabeledContent("home_url", value: truncated(payload?.homeURL, limit: 14))
                    LabeledContent("user_agent", value: truncated(payload?.userAgent))
                    LabeledContent("show_share_options", value: truncated(payload?.showShareDescription))
                    LabeledContent("external_app_url", value: truncated(payload?.externalAppURL))
                    LabeledContent("version", value: truncated(payload?.versionDescription))
                }
            }
            .navigationTitle("遠端設定")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Haptic feedback before triggering fetch
                        Haptics.mediumImpact()
                        Task { await fetchConfig(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .task {
            if payload == nil && !isLoading {
                await fetchConfig(force: false)
            }
        }
    }

    private var lastUpdatedLabel: String {
        guard let lastUpdated else { return "尚未取得資料" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return "最後更新：\(formatter.string(from: lastUpdated))"
    }

    private func fetchConfig(force: Bool) async {
        await MainActor.run {
            isLoading = true
            if force {
                errorMessage = nil
            }
        }

        var requestURL = RemoteConfig.workerEndpoint
        if var comps = URLComponents(url: requestURL, resolvingAgainstBaseURL: false) {
            comps.queryItems = (comps.queryItems ?? []) + [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
            requestURL = comps.url ?? requestURL
        }

        var request = URLRequest(url: requestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.setValue("no-store, no-cache, must-revalidate", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(RemoteConfigPayload.self, from: data)
            await MainActor.run {
                payload = decoded
                errorMessage = nil
                lastUpdated = Date()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func truncated(_ value: String?, limit: Int = 7) -> String {
        guard let value, !value.isEmpty else { return "—" }
        if value.count <= limit { return value }
        let prefix = value.prefix(limit)
        return "\(prefix)…"
    }
}

private struct RemoteConfigPayload: Decodable {
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        homeURL = try container.decodeIfPresent(String.self, forKey: .homeURL)
        userAgent = try container.decodeIfPresent(String.self, forKey: .userAgent)
        showShareOptions = try container.decodeIfPresent(Bool.self, forKey: .showShareOptions)
        externalAppURL = try container.decodeIfPresent(String.self, forKey: .externalAppURL)
        version = try container.decodeIfPresent(Int.self, forKey: .version)
    }

    var showShareDescription: String? {
        showShareOptions.map { $0 ? "true" : "false" }
    }

    var versionDescription: String? {
        version.map(String.init)
    }
}
