import Foundation
import CoreGraphics
import ExposePlusCore

/// Actions available while hovering a window in Mission Control.
/// Which keys trigger them is configurable (see `Preferences.shortcutMap`); the raw value is the action id.
enum HotKeyAction: String, CaseIterable {
    case closeWindow, closeAllWindows, minimizeWindow, hideApp, hideOthers, quitApp, forceQuit

    var title: String {
        switch self {
        case .closeWindow: return "Close Window"
        case .closeAllWindows: return "Close All Windows of App"
        case .minimizeWindow: return "Minimize Window"
        case .hideApp: return "Hide App"
        case .hideOthers: return "Hide Other Apps"
        case .quitApp: return "Quit App"
        case .forceQuit: return "Force Quit App"
        }
    }
}

final class Preferences {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard
    private let disabledKey = "disabledHotKeys"
    private let overlayKey = "showCloseButton"
    private let shortcutsKey = "shortcutMap.v1"
    private var cachedMap: ShortcutMap?

    /// Current key bindings (cached; changes are saved immediately).
    var shortcutMap: ShortcutMap {
        get {
            if let cachedMap { return cachedMap }
            let loaded = ShortcutMap.decoded(from: defaults.data(forKey: shortcutsKey))
            cachedMap = loaded
            return loaded
        }
        set {
            cachedMap = newValue
            defaults.set(newValue.encoded(), forKey: shortcutsKey)
        }
    }

    func resetShortcuts() { shortcutMap = .defaults }

    private var disabled: Set<String> {
        Set(defaults.stringArray(forKey: disabledKey) ?? [])
    }

    func isEnabled(_ action: HotKeyAction) -> Bool {
        !disabled.contains(action.rawValue)
    }

    func setEnabled(_ action: HotKeyAction, _ enabled: Bool) {
        var set = disabled
        if enabled { set.remove(action.rawValue) } else { set.insert(action.rawValue) }
        defaults.set(Array(set).sorted(), forKey: disabledKey)
    }

    var showsCloseButton: Bool {
        get { defaults.object(forKey: overlayKey) == nil ? true : defaults.bool(forKey: overlayKey) }
        set { defaults.set(newValue, forKey: overlayKey) }
    }
}
