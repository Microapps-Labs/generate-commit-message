import XCTest
@testable import gcm

final class ConfigurationTests: XCTestCase {

    func testDefaultConfiguration() {
        let config = GCMConfiguration()

        XCTAssertEqual(config.commitStyle, .conventional)
        XCTAssertEqual(config.maxLength, 72)
        XCTAssertTrue(config.includeBody)
        XCTAssertFalse(config.scopeRequired)
        XCTAssertEqual(config.bodyMaxLength, 500)
        XCTAssertNil(config.customInstructions)
    }

    func testConfigurationEncoding() throws {
        let config = GCMConfiguration(
            commitStyle: .gitmoji,
            scopeRequired: true,
            maxLength: 50
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(GCMConfiguration.self, from: data)

        XCTAssertEqual(decoded.commitStyle, .gitmoji)
        XCTAssertTrue(decoded.scopeRequired)
        XCTAssertEqual(decoded.maxLength, 50)
    }

    func testConventionalTypes() {
        let config = GCMConfiguration()

        XCTAssertTrue(config.conventionalTypes.contains("feat"))
        XCTAssertTrue(config.conventionalTypes.contains("fix"))
        XCTAssertTrue(config.conventionalTypes.contains("docs"))
        XCTAssertTrue(config.conventionalTypes.contains("chore"))
    }
}
