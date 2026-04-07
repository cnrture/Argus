import AppKit

struct ScreenIdentifier: Codable, Equatable, Hashable {
    let displayID: CGDirectDisplayID?
    let localizedName: String

    func matches(_ screen: NSScreen) -> Bool {
        if let savedID = displayID, savedID == screen.displayID { return true }
        return localizedName == screen.localizedName
    }
}

enum ScreenSelection: Codable {
    case automatic
    case specific(ScreenIdentifier)
}

struct ScreenSelector {
    static func select(preference: ScreenSelection) -> NSScreen {
        let screens = NSScreen.screens

        switch preference {
        case .automatic:
            return screens.first(where: { $0.isBuiltinDisplay }) ?? NSScreen.main ?? screens[0]
        case .specific(let identifier):
            return screens.first(where: { identifier.matches($0) }) ?? NSScreen.main ?? screens[0]
        }
    }
}
