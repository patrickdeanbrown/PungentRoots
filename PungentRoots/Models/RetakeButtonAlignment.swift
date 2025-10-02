import Foundation

enum RetakeButtonAlignment: String, CaseIterable, Identifiable {
    case leading
    case trailing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .leading: return "Left"
        case .trailing: return "Right"
        }
    }
}