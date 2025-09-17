import Foundation
import Testing
@testable import PungentRoots

struct TextAcquisitionServiceTests {
    private let service = TextAcquisitionService()

    @Test("Combines recognized strings into normalized output")
    func combinesRecognizedStrings() {
        let lines = ["Onio-", "n Powder", "Garlic", " Salt"]
        let recognized = service.makeRecognizedText(from: lines)
        #expect(recognized.raw.contains("Onio-"))
        #expect(recognized.normalized.contains("onion powder"))
        #expect(recognized.normalized.contains("garlic salt"))
    }
}
