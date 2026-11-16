import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

enum AX {
    static func value(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
    }
    static func string(_ el: AXUIElement, _ name: String) -> String? { value(el, name) as? String }
    static func children(_ el: AXUIElement) -> [AXUIElement] {
        (value(el, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    }
    static func parent(_ el: AXUIElement) -> AXUIElement? {
        guard let v = value(el, kAXParentAttribute), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }
    static func frame(_ el: AXUIElement) -> CGRect? {
        guard let v = value(el, "AXFrame"), CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
        var r = CGRect.zero
        return AXValueGetValue(v as! AXValue, .cgRect, &r) ? r : nil
    }
    static func windowID(_ el: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        return _AXUIElementGetWindow(el, &id) == .success ? id : nil
    }
}

/// A real window the user is hovering in Mission Control.
struct TargetWindow {
    let app: NSRunningApplication
    let windowID: CGWindowID
    let title: String
    /// Frame of the Mission Control thumbnail, top-left global coordinates.
    let thumbnailFrame: CGRect?

    var axWindow: AXUIElement? {
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        let windows = (AX.value(appEl, kAXWindowsAttribute) as? [AXUIElement]) ?? []
        return windows.first { AX.windowID($0) == windowID }
            ?? windows.first { AX.string($0, kAXTitleAttribute) == title }
    }
}

enum MissionControl {
    static var dockPID: pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
    }

    /// The Dock puts a screen-sized layer-20 window on screen only while
    /// Mission Control is open (verified on macOS 27: absent when closed).
    static func isActive() -> Bool {
        guard let pid = dockPID else { return false }
        let infos = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
        let screenWidth = NSScreen.screens.first?.frame.width ?? 0
        return infos.contains {
            ($0[kCGWindowOwnerPID as String] as? pid_t) == pid
                && ($0[kCGWindowLayer as String] as? Int ?? 0) >= 18
                && (($0[kCGWindowBounds as String] as? [String: Any])?["Width"] as? Double ?? 0) >= screenWidth * 0.9
        }
    }

    private static func isSystemProcess(_ pid: pid_t) -> Bool {
        var buf = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 else { return false }
        return String(cString: buf).hasPrefix("/System/")
    }

    private static func describe(_ el: AXUIElement) -> String {
        "\(AX.string(el, kAXRoleAttribute) ?? "?") id=\(AX.string(el, kAXIdentifierAttribute) ?? "") frame=\(AX.frame(el).map { "\($0)" } ?? "-")"
    }

    /// While Mission Control is open, a system-wide accessibility hit-test at the
    /// cursor returns the hovered thumbnail as an AXButton whose identifier is
    /// "<bundle id>.space.<n>", whose title is the window title and whose frame
    /// is the thumbnail (verified on macOS 27). The Dock's own tree is empty.
    static func windowUnderCursor(log: Bool = false) -> TargetWindow? {
        func note(_ m: String) { if log { Log.write("  " + m) } }
        guard let point = CGEvent(source: nil)?.location else { return nil }
        var hit: AXUIElement?
        let r = AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &hit)
        guard r == .success, var el = hit else { note("hit-test failed (\(r.rawValue))"); return nil }

        var thumb: AXUIElement?
        var ident = ""
        for _ in 0..<6 {
            if let id = AX.string(el, kAXIdentifierAttribute), id.contains(".space.") { thumb = el; ident = id; break }
            guard let p = AX.parent(el) else { break }
            el = p
        }
        guard let thumb else { note("no thumbnail under cursor; hit \(describe(hit!))"); return nil }
        var ownerPID: pid_t = 0
        AXUIElementGetPid(thumb, &ownerPID)
        note("thumbnail \(describe(thumb)) ownerPID=\(ownerPID) dockPID=\(dockPID.map { String($0) } ?? "-")")
        // On macOS 27 the thumbnails belong to WindowManager, not the Dock, so accept
        // any element owned by a program inside /System/ and reject third-party owners.
        guard ownerPID > 0, isSystemProcess(ownerPID) else {
            note("thumbnail owner \(ownerPID) is not a system process; ignored")
            return nil
        }

        guard let sep = ident.range(of: ".space.") else { return nil }
        let bundleID = String(ident[..<sep.lowerBound])
        let title = AX.string(thumb, kAXTitleAttribute) ?? ""
        let thumbFrame = AX.frame(thumb)
        let pids = Set(NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).map { $0.processIdentifier })
        guard !pids.isEmpty else { note("no running app for \(bundleID)"); return nil }

        let infos = (CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
        func bounds(_ w: [String: Any]) -> CGRect {
            CGRect(dictionaryRepresentation: (w[kCGWindowBounds as String] as? NSDictionary) ?? [:]) ?? .zero
        }
        let candidates = infos.filter {
            ($0[kCGWindowLayer as String] as? Int) == 0
                && pids.contains($0[kCGWindowOwnerPID as String] as? pid_t ?? -1)
                && bounds($0).width >= 100 && bounds($0).height >= 100
        }
        let titled = candidates.filter { ($0[kCGWindowName as String] as? String) == title }
        let pool = titled.isEmpty ? candidates : titled
        // Several windows can share a title: pick the one whose aspect ratio matches the thumbnail.
        let aspect = thumbFrame.map { $0.width / max($0.height, 1) } ?? 1
        guard let best = pool.min(by: {
            abs(bounds($0).width / bounds($0).height - aspect) < abs(bounds($1).width / bounds($1).height - aspect)
        }), let id = best[kCGWindowNumber as String] as? UInt32,
              let ownerPID = best[kCGWindowOwnerPID as String] as? pid_t,
              let app = NSRunningApplication(processIdentifier: ownerPID) else {
            note("no real window matched \(bundleID) (\(candidates.count) candidates)")
            return nil
        }
        return TargetWindow(app: app, windowID: id, title: title, thumbnailFrame: thumbFrame)
    }

    /// Writes the Dock tree and Dock window list to the log (for diagnosing detection).
    static func logDiagnostics() {
        guard let pid = dockPID else { return Log.write("  diag: Dock not running") }
        func walk(_ el: AXUIElement, _ depth: Int) {
            guard depth < 6 else { return }
            let role = AX.string(el, kAXRoleAttribute) ?? "?"
            let sub = AX.string(el, kAXSubroleAttribute) ?? ""
            let id = AX.string(el, kAXIdentifierAttribute) ?? ""
            Log.write("  diag: " + String(repeating: ".", count: depth) + "\(role) sub=\(sub) id=\(id)")
            for c in AX.children(el).prefix(12) { walk(c, depth + 1) }
        }
        walk(AXUIElementCreateApplication(pid), 0)
        let infos = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
        for w in infos where (w[kCGWindowOwnerPID as String] as? pid_t) == pid {
            Log.write("  diag: dock window layer=\(w[kCGWindowLayer as String] ?? "?") name=\(w[kCGWindowName as String] ?? "") bounds=\(w[kCGWindowBounds as String] ?? "")")
        }
    }

    /// Prints the Dock's accessibility tree. Run while Mission Control is open
    /// to check the element structure on a new macOS version.
    static func dumpTree() {
        guard let pid = dockPID else { print("Dock not running"); return }
        func walk(_ el: AXUIElement, _ depth: Int) {
            guard depth < 7 else { return }
            let role = AX.string(el, kAXRoleAttribute) ?? "?"
            let id = AX.string(el, kAXIdentifierAttribute) ?? ""
            let title = AX.string(el, kAXTitleAttribute) ?? ""
            let frame = AX.frame(el).map { "\($0)" } ?? ""
            print(String(repeating: "  ", count: depth) + "\(role) id=\(id) title=\(title) \(frame)")
            for c in AX.children(el) { walk(c, depth + 1) }
        }
        walk(AXUIElementCreateApplication(pid), 0)
    }
}
