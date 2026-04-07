import Foundation

struct QuestionEvent: Identifiable {
    let id: String
    let question: String
    let options: [String]
    let receivedAt: Date

    var hasOptions: Bool {
        !options.isEmpty
    }
}
