import Foundation
import XCTest
@testable import SteadyFrame

final class LocalizationTests: XCTestCase {
    func testEnglishAndChineseCatalogsHaveMatchingKeys() throws {
        let english = try catalog(language: "en")
        let chinese = try catalog(language: "zh-Hans")

        XCTAssertEqual(Set(english.keys), Set(chinese.keys))
        XCTAssertGreaterThanOrEqual(english.count, 35)
        XCTAssertEqual(english["menu.enableKeeper"], "Enable refresh-rate keeper")
        XCTAssertEqual(chinese["menu.enableKeeper"], "启用刷新率维持")
    }

    func testEveryCatalogKeyIsUsedByTheApp() throws {
        let english = try catalog(language: "en")
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRoot = projectRoot.appendingPathComponent("Sources/SteadyFrame")
        let sourceURLs = try FileManager.default.contentsOfDirectory(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "swift" }
        let pattern = #"L10n\.(?:text|format)\(\s*\"([^\"]+)\""#
        let regularExpression = try NSRegularExpression(pattern: pattern)
        var usedKeys = Set<String>()

        for url in sourceURLs {
            let source = try String(contentsOf: url, encoding: .utf8)
            let range = NSRange(source.startIndex..., in: source)
            for match in regularExpression.matches(in: source, range: range) {
                guard let keyRange = Range(match.range(at: 1), in: source) else { continue }
                usedKeys.insert(String(source[keyRange]))
            }
        }

        XCTAssertEqual(usedKeys, Set(english.keys))
    }

    private func catalog(language: String) throws -> [String: String] {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = projectRoot
            .appendingPathComponent("Packaging/Resources")
            .appendingPathComponent("\(language).lproj/Localizable.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )
        return try XCTUnwrap(plist as? [String: String])
    }
}
