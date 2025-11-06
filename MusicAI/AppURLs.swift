import Foundation

public enum AppURLs {
    // Set your default/home URL here
    public static let home: URL = {
        // Replace with your desired URL string
        let string = "https://linyounttu.dpdns.org/"
        guard let url = URL(string: string) else {
            preconditionFailure("Invalid URL: \(string)")
        }
        return url
    }()
}
