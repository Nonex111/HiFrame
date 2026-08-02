import Foundation

enum L10n {
    static func text(
        _ key: String,
        fallback: String,
        bundle: Bundle = .main
    ) -> String {
        bundle.localizedString(forKey: key, value: fallback, table: "Localizable")
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
}
