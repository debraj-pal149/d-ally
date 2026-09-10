import Foundation

enum DayLogStatus: String, Codable, CaseIterable, Identifiable {
    case kept
    case skipped
    var id: String { rawValue }
}
