import Foundation

struct PermissionEvent: Identifiable {
    let id: String
    let toolName: String
    let toolInput: [String: AnyCodableValue]?
    let toolUseId: String
    let receivedAt: Date

    var displayCommand: String {
        guard let input = toolInput else { return toolName }

        switch toolName {
        case "Bash":
            return input["command"]?.stringValue ?? "bash command"
        case "Edit":
            let file = input["file_path"]?.stringValue ?? "file"
            return "Edit: \(file)"
        case "Write":
            let file = input["file_path"]?.stringValue ?? "file"
            return "Write: \(file)"
        default:
            return toolName
        }
    }

    var diffPreview: DiffPreview? {
        guard toolName == "Edit" || toolName == "Write",
              let input = toolInput else { return nil }

        let filePath = input["file_path"]?.stringValue ?? ""

        if toolName == "Edit" {
            let oldString = input["old_string"]?.stringValue ?? ""
            let newString = input["new_string"]?.stringValue ?? ""
            let deletions = oldString.components(separatedBy: "\n").filter { !$0.isEmpty }
            let additions = newString.components(separatedBy: "\n").filter { !$0.isEmpty }
            return DiffPreview(
                filePath: filePath,
                additions: additions,
                deletions: deletions,
                addedCount: additions.count,
                deletedCount: deletions.count
            )
        }

        return nil
    }
}
