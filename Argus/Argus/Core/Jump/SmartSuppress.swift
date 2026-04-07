import AppKit

struct SmartSuppress {
    /// Kullanıcı ilgili session'ın terminal/IDE'sine bakıyorsa true döner.
    /// Bu durumda notification bastırılmalı — kullanıcı zaten farkında.
    static func isUserWatchingSession(_ session: Session) -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }

        // Session'ın sahibi ön plandaysa kullanıcı zaten bakıyor
        if let ownerBundle = session.ownerBundleID,
           frontApp.bundleIdentifier == ownerBundle {
            return true
        }

        // Bilinen terminal/IDE ön plandaysa ve CWD eşleşiyorsa
        if let bundleID = frontApp.bundleIdentifier,
           isTerminalOrIDE(bundleID) {
            // Terminal ön planda — muhtemelen bu session'a bakıyor
            return true
        }

        return false
    }

    private static func isTerminalOrIDE(_ bundleID: String) -> Bool {
        let known: Set<String> = [
            "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty",
            "dev.warp.Warp-Stable", "io.alacritty", "net.kovidgoyal.kitty",
            "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92",
            "com.google.android.studio", "com.jetbrains.intellij",
        ]
        return known.contains(bundleID)
    }
}
