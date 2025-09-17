import Foundation

private final class DictionaryBundleMarker {}

struct DetectDictionary: Decodable, Sendable {
    let definite: [String]
    let patterns: [String]
    let ambiguous: [String]
    let synonyms: [String]
    let fuzzyHints: [String]
    let version: String
}

enum DictionaryLoaderError: Error {
    case resourceNotFound
    case failedToDecode(Error)
}

struct DictionaryLoader {
    private let fileName: String
    private let fileExtension: String
    private let bundle: Bundle

    init(fileName: String = "pungent_roots_dictionary", fileExtension: String = "json", bundle: Bundle = .main) {
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.bundle = bundle
    }

    func load() throws -> DetectDictionary {
        let candidateBundles: [Bundle] = [bundle, Bundle(for: DictionaryBundleMarker.self)]
        for bundle in candidateBundles {
            if let url = bundle.url(forResource: fileName, withExtension: fileExtension) {
                do {
                    let data = try Data(contentsOf: url)
                    return try JSONDecoder().decode(DetectDictionary.self, from: data)
                } catch {
                    throw DictionaryLoaderError.failedToDecode(error)
                }
            }
        }
        throw DictionaryLoaderError.resourceNotFound
    }
}
