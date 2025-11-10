import Foundation

public enum AppURLs {
    /// 預設 fallback 網址（遠端設定取不到時使用）
    public static let fallback = URL(string: "https://linyounttu.dpdns.org/")!

    /// 實際使用中的首頁網址（會被遠端覆蓋）
    public static var home: URL {
        RemoteConfig.shared.currentHomeURL ?? fallback
    }
}