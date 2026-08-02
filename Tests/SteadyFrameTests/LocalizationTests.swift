import Foundation
import XCTest
@testable import SteadyFrame

final class LocalizationTests: XCTestCase {
    func testEnglishAndChineseCatalogsHaveMatchingKeys() throws {
        let english = try catalog(language: "en")
        let chinese = try catalog(language: "zh-Hans")

        XCTAssertEqual(Set(english.keys), Set(chinese.keys))
        XCTAssertGreaterThanOrEqual(english.count, 37)
        XCTAssertEqual(english["menu.enableKeeper"], "Enable refresh-rate keeper")
        XCTAssertEqual(chinese["menu.enableKeeper"], "启用刷新率维持")
        XCTAssertEqual(english["menu.language"], "Language")
        XCTAssertEqual(chinese["menu.language"], "语言")
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

    func testExplicitLanguageOverrideLoadsTheSelectedCatalog() throws {
        let bundle = try XCTUnwrap(Bundle(path: resourcesRoot.path))
        defer { L10n.language = .system }

        L10n.language = .english
        XCTAssertEqual(
            L10n.text("menu.language", fallback: "fallback", bundle: bundle),
            "Language"
        )
        XCTAssertEqual(
            L10n.text("language.system", fallback: "fallback", bundle: bundle),
            "Follow System"
        )

        L10n.language = .simplifiedChinese
        XCTAssertEqual(
            L10n.text("menu.language", fallback: "fallback", bundle: bundle),
            "语言"
        )
        XCTAssertEqual(
            L10n.text("language.system", fallback: "fallback", bundle: bundle),
            "跟随系统"
        )
    }

    private func catalog(language: String) throws -> [String: String] {
        let url = resourcesRoot
            .appendingPathComponent("\(language).lproj/Localizable.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )
        return try XCTUnwrap(plist as? [String: String])
    }

    private var resourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Packaging/Resources")
    }
}
