import AppKit
import ApplicationServices

if CommandLine.arguments.contains("--dump-mc") {
    print("Open Mission Control within 5 seconds…")
    sleep(5)
    MissionControl.dumpTree()
    exit(0)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private let tap = HotKeyTap()
    private let overlay = CloseButtonOverlay()
    private var trustTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.exposeplus.app")
            .filter { $0 != NSRunningApplication.current }
        if !others.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Expose Plus is already running."
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        Log.write("launch; accessibility trusted=\(AXIsProcessTrusted())")
        menuBar = MenuBarController()
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(opts) { activate() } else {
            // Wait for the user to grant Accessibility, then start.
            trustTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
                if AXIsProcessTrusted() { t.invalidate(); self?.activate() }
            }
        }
    }

    private func activate() {
        let started = tap.start()
        Log.write("event tap started=\(started)")
        if !started {
            let alert = NSAlert()
            alert.messageText = "Could not install the keyboard hook."
            alert.informativeText = "Grant Accessibility (and Input Monitoring if prompted) in System Settings → Privacy & Security, then relaunch."
            alert.runModal()
        }
        overlay.startWatching()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
