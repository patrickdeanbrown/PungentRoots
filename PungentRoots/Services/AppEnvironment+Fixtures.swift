import Foundation

extension AppEnvironment {
    static func live(bundle: Bundle = .main) -> AppEnvironment {
        do {
            let dictionary = try DictionaryLoader(bundle: bundle).load()
            return AppEnvironment(
                dictionary: dictionary,
                captureOptions: defaultCaptureOptions()
            )
        } catch {
            assertionFailure("Failed to load dictionary: \(error)")
            return AppEnvironment(dictionary: .fallback, captureOptions: defaultCaptureOptions())
        }
    }

    static var preview: AppEnvironment {
        AppEnvironment(dictionary: .preview, captureOptions: .init(prefersDataScanner: false))
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

@MainActor
private func defaultCaptureOptions() -> AppEnvironment.CaptureOptions {
#if os(iOS)
    if #available(iOS 16.0, *) {
        return AppEnvironment.CaptureOptions(prefersDataScanner: DataScannerCaptureController.isSupported)
    } else {
        return AppEnvironment.CaptureOptions(prefersDataScanner: false)
    }
#else
    return AppEnvironment.CaptureOptions(prefersDataScanner: false)
#endif
}
