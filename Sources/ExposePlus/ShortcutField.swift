import AppKit
import QuartzCore
import ExposePlusCore

extension ShortcutModifiers {
    init(nsFlags: NSEvent.ModifierFlags) {
        var m: ShortcutModifiers = []
        if nsFlags.contains(.control) { m.insert(.control) }
        if nsFlags.contains(.option) { m.insert(.option) }
        if nsFlags.contains(.shift) { m.insert(.shift) }
        if nsFlags.contains(.command) { m.insert(.command) }
        self = m
    }
}

/// A button that shows a shortcut. Click it, then press the new keys. Delete clears, Esc cancels.
final class ShortcutField: NSButton {
    /// Called with the recorded shortcut (nil = cleared). Return false if it was refused.
    var onChange: ((Shortcut?) -> Bool)?
    var shortcut: Shortcut? { didSet { refreshTitle() } }

    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var recording = false { didSet { refreshTitle() } }

    init() {
        super.init(frame: .zero)
        wantsLayer = true   // layer-backed from the start so the shake animation never changes the layout
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 118).isActive = true
        refreshTitle()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    deinit { stopMonitors() }

    private func refreshTitle() {
        title = recording ? "Press keys…" : (shortcut?.displayLabel ?? "—")
    }

    @objc private func beginRecording() {
        guard !recording else { return }
        recording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            let inside = event.window == self.window && self.bounds.contains(self.convert(event.locationInWindow, from: nil))
            if !inside { self.endRecording() }
            return event
        }
    }

    private func endRecording() {
        stopMonitors()
        recording = false
    }

    private func stopMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        keyMonitor = nil
        mouseMonitor = nil
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if event.isARepeat { return nil }
        let mods = ShortcutModifiers(nsFlags: event.modifierFlags.intersection(.deviceIndependentFlagsMask))
        let code = Int(event.keyCode)
        if code == 53 && mods.isEmpty { endRecording(); return nil }                        // Esc cancels
        if (code == 51 || code == 117) && mods.isEmpty {                                    // Delete clears
            endRecording()
            _ = onChange?(nil)
            return nil
        }
        let label = KeyLabels.label(forKeyCode: code, characters: event.charactersIgnoringModifiers)
        endRecording()
        let accepted = onChange?(Shortcut(keyCode: code, modifiers: mods, keyLabel: label)) ?? false
        if !accepted { shake() }
        return nil
    }

    /// Refused key: beep and give the field a short shake (the reason is shown in the window's status line).
    private func shake() {
        NSSound.beep()
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.values = [0, -6, 6, -4, 4, 0]
        anim.duration = 0.3
        layer?.add(anim, forKey: "shake")
    }
}
