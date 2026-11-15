import CoreGraphics
import Foundation

/// The four modifier keys a shortcut can include.
public struct ShortcutModifiers: OptionSet, Codable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let control = ShortcutModifiers(rawValue: 1)
    public static let option = ShortcutModifiers(rawValue: 2)
    public static let shift = ShortcutModifiers(rawValue: 4)
    public static let command = ShortcutModifiers(rawValue: 8)

    /// Modifiers held in a CGEvent; Caps Lock, Fn and the like are ignored.
    public init(cgFlags: CGEventFlags) {
        var m: ShortcutModifiers = []
        if cgFlags.contains(.maskControl) { m.insert(.control) }
        if cgFlags.contains(.maskAlternate) { m.insert(.option) }
        if cgFlags.contains(.maskShift) { m.insert(.shift) }
        if cgFlags.contains(.maskCommand) { m.insert(.command) }
        self = m
    }

    /// Symbols in the standard macOS order: ⌃⌥⇧⌘.
    public var symbols: String {
        (contains(.control) ? "⌃" : "") + (contains(.option) ? "⌥" : "")
            + (contains(.shift) ? "⇧" : "") + (contains(.command) ? "⌘" : "")
    }
}

/// One key plus modifiers, e.g. ⌥W.
public struct Shortcut: Codable, Hashable {
    public var keyCode: Int
    public var modifiers: ShortcutModifiers
    /// What the key shows on the user's keyboard layout, captured when recorded ("W", "F5", "Space").
    public var keyLabel: String

    public init(keyCode: Int, modifiers: ShortcutModifiers = [], keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    public var displayLabel: String { modifiers.symbols + keyLabel }

    /// Same physical key and modifiers (the label is only for display).
    public func triggersSame(as other: Shortcut) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }
}

public enum ShortcutSlot: String, Codable, CaseIterable {
    case primary, alternate
}

/// Why a shortcut cannot be assigned.
public enum ShortcutIssue: Equatable {
    /// Unmodified navigation keys that Mission Control itself uses (Esc, arrows, Return, Tab, Space, …).
    case reservedKey(Shortcut)
    /// Already used by `actionID` (which may be the same action's other slot).
    case conflict(Shortcut, actionID: String)
}

public struct ActionShortcuts: Codable, Equatable {
    public var primary: Shortcut?
    public var alternate: Shortcut?

    public init(primary: Shortcut? = nil, alternate: Shortcut? = nil) {
        self.primary = primary
        self.alternate = alternate
    }

    public var all: [Shortcut] { [primary, alternate].compactMap { $0 } }

    public subscript(slot: ShortcutSlot) -> Shortcut? {
        get { slot == .primary ? primary : alternate }
        set { if slot == .primary { primary = newValue } else { alternate = newValue } }
    }
}

/// Which shortcut triggers which action. Actions are identified by their string id
/// (the raw value of the app's `HotKeyAction`).
public struct ShortcutMap: Codable, Equatable {
    public private(set) var bindings: [String: ActionShortcuts]

    public init(bindings: [String: ActionShortcuts]) {
        self.bindings = bindings
    }

    /// Display and matching order.
    public static let actionIDs = ["closeWindow", "closeAllWindows", "minimizeWindow", "hideApp", "hideOthers", "quitApp", "forceQuit"]

    /// Key codes: W 13, X 7, M 46, H 4, Q 12.
    public static let defaults: ShortcutMap = {
        func key(_ code: Int, _ label: String, _ mods: ShortcutModifiers = []) -> Shortcut {
            Shortcut(keyCode: code, modifiers: mods, keyLabel: label)
        }
        return ShortcutMap(bindings: [
            "closeWindow": ActionShortcuts(primary: key(13, "W"), alternate: key(7, "X")),
            "closeAllWindows": ActionShortcuts(primary: key(13, "W", .option), alternate: key(7, "X", .option)),
            "minimizeWindow": ActionShortcuts(primary: key(46, "M")),
            "hideApp": ActionShortcuts(primary: key(4, "H")),
            "hideOthers": ActionShortcuts(primary: key(4, "H", .option)),
            "quitApp": ActionShortcuts(primary: key(12, "Q")),
            "forceQuit": ActionShortcuts(primary: key(12, "Q", .option)),
        ])
    }()

    public func shortcuts(for actionID: String) -> ActionShortcuts {
        bindings[actionID] ?? ActionShortcuts()
    }

    /// The action triggered by this key and exact modifier set, if any.
    public func actionID(keyCode: Int, modifiers: ShortcutModifiers) -> String? {
        for id in Self.actionIDs {
            let hit = shortcuts(for: id).all.contains { $0.keyCode == keyCode && $0.modifiers == modifiers }
            if hit { return id }
        }
        return nil
    }

    /// Unmodified keys Mission Control needs for its own navigation.
    public static func isReserved(_ s: Shortcut) -> Bool {
        let reservedKeyCodes: Set<Int> = [53, 36, 76, 48, 49, 51, 117, 115, 119, 116, 121, 123, 124, 125, 126]
        return s.modifiers.isEmpty && reservedKeyCodes.contains(s.keyCode)
    }

    /// Nil if `shortcut` can be assigned to this action's slot.
    public func issue(assigning shortcut: Shortcut, to actionID: String, slot: ShortcutSlot) -> ShortcutIssue? {
        if Self.isReserved(shortcut) { return .reservedKey(shortcut) }
        for id in Self.actionIDs {
            for s in ShortcutSlot.allCases {
                if id == actionID && s == slot { continue }   // replacing itself
                if let existing = shortcuts(for: id)[s], existing.triggersSame(as: shortcut) {
                    return .conflict(shortcut, actionID: id)
                }
            }
        }
        return nil
    }

    /// Assigns (or clears, with nil). Returns the reason it was refused; the map is unchanged then.
    @discardableResult
    public mutating func assign(_ shortcut: Shortcut?, to actionID: String, slot: ShortcutSlot) -> ShortcutIssue? {
        if let shortcut, let problem = issue(assigning: shortcut, to: actionID, slot: slot) { return problem }
        var entry = shortcuts(for: actionID)
        entry[slot] = shortcut
        bindings[actionID] = entry
        return nil
    }

    // MARK: Persistence

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }

    /// Decodes saved data; anything missing or unreadable falls back to the defaults.
    public static func decoded(from data: Data?) -> ShortcutMap {
        guard let data, let saved = try? JSONDecoder().decode(ShortcutMap.self, from: data) else { return .defaults }
        var merged = saved.bindings
        for id in actionIDs where merged[id] == nil { merged[id] = defaults.shortcuts(for: id) }
        return ShortcutMap(bindings: merged)
    }
}

/// Text shown on a key.
public enum KeyLabels {
    private static let special: [Int: String] = [
        49: "Space", 36: "↩", 76: "⌅", 48: "⇥", 53: "⎋", 51: "⌫", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    /// `characters` is what the key types on the current layout (without modifiers).
    public static func label(forKeyCode keyCode: Int, characters: String?) -> String {
        if let name = special[keyCode] { return name }
        if let first = characters?.trimmingCharacters(in: .whitespacesAndNewlines).first {
            return String(first).uppercased()
        }
        return "Key \(keyCode)"
    }
}
