import Foundation

extension AppEnvironment {
    static func live(bundle: Bundle = .main) -> AppEnvironment {
        do {
            let dictionary = try DictionaryLoader(bundle: bundle).load()
            return AppEnvironment(dictionary: dictionary)
        } catch {
            assertionFailure("Failed to load dictionary: \(error)")
            return AppEnvironment(dictionary: .fallback)
        }
    }

    static var preview: AppEnvironment {
        AppEnvironment(dictionary: .preview)
    }
}

private extension DetectDictionary {
    static var preview: DetectDictionary {
        DetectDictionary(
            definite: ["onion", "garlic"],
            patterns: ["dehydrated\\s+garlic"],
            ambiguous: ["stock"],
            synonyms: ["allium"],
            fuzzyHints: ["garilc"],
            version: "preview"
        )
    }

    static var fallback: DetectDictionary {
        DetectDictionary(
            definite: [],
            patterns: [],
            ambiguous: [],
            synonyms: [],
            fuzzyHints: [],
            version: "fallback"
        )
    }
}
