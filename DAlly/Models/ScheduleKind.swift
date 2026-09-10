import Foundation

enum ScheduleKind: String, Codable, CaseIterable, Identifiable {
    case fixedTime
    case flexibleUntil

    var id: String { rawValue }

    var editorLabel: String {
        switch self {
        case .fixedTime: "Specific time"
        case .flexibleUntil: "Finish by"
        }
    }

    var helper: String {
        switch self {
        case .fixedTime: "Pings at that time."
        case .flexibleUntil: "Done any time before the end time."
        }
    }
}
