import AppKit
import CoreGraphics
import ExposePlusCore

/// Session event tap that intercepts the user's configured shortcuts (defaults: W/X, M, H, Q, optionally with ⌥)
/// only while Mission Control is showing and the cursor is over a window thumbnail.
final class HotKeyTap {
    private var tap: CFMachPort?
    private var lastDiag = Date.distantPast

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let me = Unmanaged<HotKeyTap>.fromOpaque(refcon!).takeUnretainedValue()
            return me.handle(type, event)
        }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                           options: .defaultTap, eventsOfInterest: mask,
                                           callback: callback,
                                           userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        tap = port
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, port, 0), .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        guard type == .keyDown else { return pass }

        let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = ShortcutModifiers(cgFlags: event.flags)
        guard let id = Preferences.shared.shortcutMap.actionID(keyCode: code, modifiers: modifiers),
              let action = HotKeyAction(rawValue: id),
              Preferences.shared.isEnabled(action) else { return pass }
        Log.write("key \(code) -> \(action.rawValue)")
        guard MissionControl.isActive() else {
            Log.write("  Mission Control not detected (Dock has no 'mc' child)")
            let now = Date()
            if now.timeIntervalSince(lastDiag) > 10 { lastDiag = now; MissionControl.logDiagnostics() }
            return pass
        }
        guard let target = MissionControl.windowUnderCursor(log: true) else { Log.write("  no window resolved under cursor"); return pass }
        Log.write("  target: \(target.app.localizedName ?? "?") window \(target.windowID) '\(target.title)'")

        // Swallow key repeats so holding the key doesn't act on the next window.
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            WindowActions.perform(action, on: target)
        }
        return nil
    }
}
