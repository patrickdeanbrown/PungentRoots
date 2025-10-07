import Foundation

import SwiftUI

enum RetakeButtonAlignment: String, CaseIterable, Identifiable {
    case leading
    case trailing

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .leading: return LocalizedStringKey("settings.retake.leading")
        case .trailing: return LocalizedStringKey("settings.retake.trailing")
        }
    }
}
