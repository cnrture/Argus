import Foundation

struct SessionTitleResolver {
    /// Claude Code'un JSONL log dosyasından oturum başlığını çözümler.
    /// Proje dizininin son bileşenini başlık olarak kullanır.
    static func resolve(cwd: String?) -> String {
        guard let cwd, !cwd.isEmpty else {
            return "Claude Code"
        }
        let dirName = URL(fileURLWithPath: cwd).lastPathComponent
        return "\(dirName) — Claude Code"
    }

    /// JSONL dosyasından ilk kullanıcı mesajını başlık olarak okumaya çalışır.
    static func resolveFromJSONL(at path: String) -> String? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path),
              let data = fm.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        // İlk satırı parse et
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            // "type": "human" olan ilk mesajın içeriğini al
            if json["type"] as? String == "human",
               let message = json["message"] as? [String: Any],
               let content = message["content"] as? String {
                // İlk 50 karakteri döndür
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count > 50 {
                    return String(trimmed.prefix(50)) + "..."
                }
                return trimmed
            }
        }

        return nil
    }
}
