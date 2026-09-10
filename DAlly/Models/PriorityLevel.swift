import Foundation

enum PriorityLevel: String, Codable, CaseIterable, Identifiable {
    case low, normal, high
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        }
    }
    var sortRank: Int {
        switch self {
        case .high: 0
        case .normal: 1
        case .low: 2
        }
    }
}
