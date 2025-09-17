import Foundation

extension String {
    func ranges(of pattern: String, options: NSRegularExpression.Options = [.caseInsensitive]) -> [Range<Int>] {
        let regex = try? NSRegularExpression(pattern: pattern, options: options)
        guard let regex else { return [] }
        let nsRange = NSRange(location: 0, length: (self as NSString).length)
        return regex.matches(in: self, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: self) else { return nil }
            let lower = range.lowerBound.utf16Offset(in: self)
            let upper = range.upperBound.utf16Offset(in: self)
            return lower..<upper
        }
    }
}
