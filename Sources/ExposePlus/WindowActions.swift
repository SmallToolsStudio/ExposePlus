import AppKit
import ApplicationServices
import os

enum WindowActions {
    private static let log = Logger(subsystem: "local.exposeplus.app", category: "actions")

    static func perform(_ action: HotKeyAction, on target: TargetWindow) {
        switch action {
        case .closeWindow:
            report(action, close(target.axWindow))
        case .closeAllWindows:
            let appEl = AXUIElementCreateApplication(target.app.processIdentifier)
            let windows = (AX.value(appEl, kAXWindowsAttribute) as? [AXUIElement]) ?? []
            report(action, !windows.isEmpty && windows.map { close($0) }.allSatisfy { $0 })
        case .minimizeWindow:
            guard let w = target.axWindow else { return report(action, false) }
            report(action, AXUIElementSetAttributeValue(w, kAXMinimizedAttribute as CFString, kCFBooleanTrue) == .success)
        case .hideApp:
            report(action, target.app.hide())
        case .hideOthers:
            let me = ProcessInfo.processInfo.processIdentifier
            for app in NSWorkspace.shared.runningApplications
            where app.activationPolicy == .regular
                && app.processIdentifier != target.app.processIdentifier
                && app.processIdentifier != me {
                app.hide()
            }
            report(action, true)
        case .quitApp:
            report(action, target.app.terminate())
        case .forceQuit:
            report(action, target.app.forceTerminate())
        }
    }

    static func close(_ window: AXUIElement?) -> Bool {
        guard let window, let button = AX.value(window, kAXCloseButtonAttribute),
              CFGetTypeID(button) == AXUIElementGetTypeID() else { return false }
        return AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString) == .success
    }

    private static func report(_ action: HotKeyAction, _ ok: Bool) {
        Log.write("  \(action.rawValue) \(ok ? "succeeded" : "FAILED")")
    }
}
