import Foundation
import SwiftUI

enum MarkPattern: String, Codable, CaseIterable, Identifiable {
    case solid
    case stripes
    case crosshatch
    case dots
    case diagonal
    case ring

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .solid: "Solid"
        case .stripes: "Stripes"
        case .crosshatch: "Cross"
        case .dots: "Dots"
        case .diagonal: "Diagonal"
        case .ring: "Ring"
        }
    }
}
