import Foundation

/// Localization helper — dil ayarına göre string döndürür
enum L10n {
    static subscript(_ key: String) -> String {
        let language = UserDefaults.standard.string(forKey: "language") ?? "system"

        if language == "system" {
            return NSLocalizedString(key, comment: "")
        }

        // Belirli dil seçilmişse o dil bundle'ından oku
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }

        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}
