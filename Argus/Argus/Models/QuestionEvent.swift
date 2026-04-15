import Foundation

struct QuestionEvent: Identifiable {
    let id: String
    let question: String
    let options: [String]
    let receivedAt: Date
    /// AskUserQuestion permission-request ise true; klasik elicitation ise false.
    var isPermissionRequest: Bool = false

    var hasOptions: Bool {
        !options.isEmpty
    }
}
