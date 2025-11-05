import Foundation

public enum AppURLs {
    // Set your default/home URL here
    public static let home: URL = {
        // Replace with your desired URL string
        let string = "https://vercel.com/ian20040409s-projects/vercel-redirect-nttu/5sy7yNAM6fCkr1kyG2zTHqSkj1ad"
        guard let url = URL(string: string) else {
            preconditionFailure("Invalid URL: \(string)")
        }
        return url
    }()
}
