import Foundation

struct PlanEvent: Identifiable {
    let id: String
    let planMarkdown: String
    let receivedAt: Date
}
