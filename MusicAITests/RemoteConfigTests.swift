import XCTest
@testable import MusicAI

final class RemoteConfigTests: XCTestCase {

    func decode(_ json: String) throws -> RemoteConfigPayload {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(RemoteConfigPayload.self, from: data)
    }

    func testValidPayloadDecoding() throws {
        let json = """
        {
          "home_url": "https://example.com/",
          "user_agent": "UA/1.0",
          "show_share_options": true,
          "external_app_url": "myapp://open",
          "version": 3
        }
        """
        let payload = try decode(json)
        XCTAssertEqual(payload.homeURL, "https://example.com/")
        XCTAssertEqual(payload.userAgent, "UA/1.0")
        XCTAssertEqual(payload.showShareOptions, true)
        XCTAssertEqual(payload.externalAppURL, "myapp://open")
        XCTAssertEqual(payload.version, 3)
    }

    func testMissingFieldsDecoding() throws {
        let json = "{}"
        let payload = try decode(json)
        XCTAssertNil(payload.homeURL)
        XCTAssertNil(payload.userAgent)
        XCTAssertNil(payload.showShareOptions)
        XCTAssertNil(payload.externalAppURL)
        XCTAssertNil(payload.version)
    }

    func testTypeMismatchDecodingFails() {
        let json = """
        {
          "home_url": true,
          "user_agent": 123,
          "show_share_options": "yes",
          "external_app_url": {"x":1},
          "version": "v1"
        }
        """
        XCTAssertThrowsError(try decode(json))
    }

    func testValidationLogic() {
        // 準備 initial state
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: RemoteConfig.Defaults.cachedHome)
        defaults.removeObject(forKey: RemoteConfig.Defaults.cachedUserAgent)
        defaults.removeObject(forKey: RemoteConfig.Defaults.remoteShowShareOptions)
        defaults.removeObject(forKey: RemoteConfig.Defaults.remoteExternalAppURL)

        // 1) 非法 home_url -> fallback
        let p1 = RemoteConfigPayload(homeURL: "not a url", userAgent: nil, showShareOptions: nil, externalAppURL: nil, version: nil)
        RemoteConfig.shared.applyTestPayload(p1)
        XCTAssertEqual(RemoteConfig.shared.currentHomeURL, AppURLs.fallback)

        // 2) 合法 https home_url
        let p2 = RemoteConfigPayload(homeURL: "https://ok.com", userAgent: "", showShareOptions: nil, externalAppURL: nil, version: nil)
        RemoteConfig.shared.applyTestPayload(p2)
        XCTAssertEqual(RemoteConfig.shared.currentHomeURL, URL(string: "https://ok.com")!)

        // 3) external 必須有 scheme
        let p3 = RemoteConfigPayload(homeURL: nil, userAgent: nil, showShareOptions: nil, externalAppURL: "nonsense", version: nil)
        RemoteConfig.shared.applyTestPayload(p3)
        let ext = UserDefaults.standard.string(forKey: RemoteConfig.Defaults.remoteExternalAppURL)
        XCTAssertNotNil(ext)
    }
}
