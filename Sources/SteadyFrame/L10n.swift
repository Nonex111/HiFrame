import Foundation

enum L10n {
    static var language: AppLanguage = .system

    static func text(
        _ key: String,
        fallback: String,
        bundle: Bundle = .main
    ) -> String {
        localizedBundle(in: bundle).localizedString(
            forKey: key,
            value: fallback,
            table: "Localizable"
        )
    }

    static func format(
        _ key: String,
        fallback: String,
        bundle: Bundle = .main,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: text(key, fallback: fallback, bundle: bundle),
            arguments: arguments
        )
    }

    private static func localizedBundle(in baseBundle: Bundle) -> Bundle {
        guard let localization = language.localizationIdentifier,
              let path = baseBundle.path(forResource: localization, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return baseBundle
        }
        return bundle
    }
}
