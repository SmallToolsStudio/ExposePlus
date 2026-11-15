import AppKit
import ExposePlusCore

/// "Settings…" window: edit the Mission Control shortcuts and choose whether the close ✕ is shown.
final class SettingsWindowController: NSWindowController {
    private var map = Preferences.shared.shortcutMap
    private var enableBoxes: [HotKeyAction: NSButton] = [:]
    private var fields: [HotKeyAction: [ShortcutSlot: ShortcutField]] = [:]
    private let status = NSTextField(wrappingLabelWithString: SettingsWindowController.hint)
    private let closeButtonBox = NSButton(checkboxWithTitle: "Show close button (✕) on hover", target: nil, action: nil)
    private var placedOnce = false

    private static let hint = "Click a shortcut, then press the new keys. Delete clears it, Esc cancels. Changes apply immediately."

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Expose Plus Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show() {
        map = Preferences.shared.shortcutMap
        refresh()
        status.stringValue = Self.hint
        status.textColor = .secondaryLabelColor
        if !placedOnce { window?.center(); placedOnce = true }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: Layout

    private func label(_ text: String, bold: Bool = false, secondary: Bool = false) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = bold ? .boldSystemFont(ofSize: 13) : .systemFont(ofSize: 13)
        if secondary { f.textColor = .secondaryLabelColor }
        return f
    }

    private func buildContent() {
        let title = label("Shortcuts in Mission Control", bold: true)
        let subtitle = label("Hover a window in Mission Control, then press the shortcut.", secondary: true)

        func header(_ text: String) -> NSTextField {
            let f = label(text, secondary: true)
            f.font = .systemFont(ofSize: 11, weight: .medium)
            return f
        }
        var rows: [[NSView]] = [[header("On"), header("Action"), header("Shortcut"), header("Alternate")]]
        for action in HotKeyAction.allCases {
            let box = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleEnabled(_:)))
            box.identifier = NSUserInterfaceItemIdentifier(action.rawValue)
            enableBoxes[action] = box
            var slotFields: [ShortcutSlot: ShortcutField] = [:]
            for slot in ShortcutSlot.allCases {
                let field = ShortcutField()
                field.onChange = { [weak self] new in self?.apply(new, to: action, slot: slot) ?? false }
                slotFields[slot] = field
            }
            fields[action] = slotFields
            rows.append([box, label(action.title), slotFields[.primary]!, slotFields[.alternate]!])
        }
        let grid = NSGridView(views: rows)
        grid.columnSpacing = 14
        grid.rowSpacing = 9
        grid.column(at: 0).xPlacement = .center
        grid.column(at: 1).xPlacement = .leading
        grid.rowAlignment = .firstBaseline

        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        status.preferredMaxLayoutWidth = 440
        status.maximumNumberOfLines = 2
        status.heightAnchor.constraint(equalToConstant: 30).isActive = true   // fixed: a one- or two-line message never shifts the layout

        let reset = NSButton(title: "Reset Shortcuts to Defaults", target: self, action: #selector(resetDefaults))
        reset.bezelStyle = .rounded

        let divider = NSBox()
        divider.boxType = .separator

        closeButtonBox.target = self
        closeButtonBox.action = #selector(toggleCloseButton(_:))
        let closeHint = NSTextField(wrappingLabelWithString: "A small ✕ appears on the hovered window in Mission Control; click it to close that window.")
        closeHint.font = .systemFont(ofSize: 11)
        closeHint.textColor = .secondaryLabelColor
        closeHint.preferredMaxLayoutWidth = 440

        let stack = NSStackView(views: [title, subtitle, grid, status, reset, divider, closeButtonBox, closeHint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.setCustomSpacing(4, after: title)
        stack.setCustomSpacing(16, after: subtitle)
        stack.setCustomSpacing(16, after: reset)
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 22, bottom: 22, right: 22)
        divider.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -44).isActive = true

        let content = NSView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window?.contentView = content
        content.layoutSubtreeIfNeeded()
        let fit = stack.fittingSize
        window?.setContentSize(NSSize(width: max(fit.width, 500), height: fit.height))
    }

    // MARK: State

    private func refresh() {
        for action in HotKeyAction.allCases {
            let enabled = Preferences.shared.isEnabled(action)
            enableBoxes[action]?.state = enabled ? .on : .off
            let entry = map.shortcuts(for: action.rawValue)
            for slot in ShortcutSlot.allCases {
                fields[action]?[slot]?.shortcut = entry[slot]
                fields[action]?[slot]?.isEnabled = enabled
            }
        }
        closeButtonBox.state = Preferences.shared.showsCloseButton ? .on : .off
    }

    private func apply(_ shortcut: Shortcut?, to action: HotKeyAction, slot: ShortcutSlot) -> Bool {
        var updated = map
        if let issue = updated.assign(shortcut, to: action.rawValue, slot: slot) {
            show(issue)
            return false
        }
        map = updated
        Preferences.shared.shortcutMap = updated
        refresh()
        let slotName = slot == .primary ? "shortcut" : "alternate"
        say(shortcut.map { "\(action.title): \(slotName) set to \($0.displayLabel)" } ?? "\(action.title): \(slotName) cleared", error: false)
        return true
    }

    private func show(_ issue: ShortcutIssue) {
        switch issue {
        case .reservedKey(let s):
            say("\(s.displayLabel) is used by Mission Control itself. Pick another key or add a modifier such as ⌥.", error: true)
        case .conflict(let s, let id):
            let owner = HotKeyAction(rawValue: id)?.title ?? id
            say("\(s.displayLabel) is already used by “\(owner)”. Change or clear that one first.", error: true)
        }
    }

    private func say(_ text: String, error: Bool) {
        status.stringValue = text
        status.textColor = error ? .systemRed : .secondaryLabelColor
    }

    // MARK: Actions

    @objc private func toggleEnabled(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let action = HotKeyAction(rawValue: raw) else { return }
        Preferences.shared.setEnabled(action, sender.state == .on)
        refresh()
    }

    @objc private func toggleCloseButton(_ sender: NSButton) {
        Preferences.shared.showsCloseButton = (sender.state == .on)
    }

    @objc private func resetDefaults() {
        Preferences.shared.resetShortcuts()
        map = Preferences.shared.shortcutMap
        refresh()
        say("Shortcuts reset to the defaults.", error: false)
    }
}
