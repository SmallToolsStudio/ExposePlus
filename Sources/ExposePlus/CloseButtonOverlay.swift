import AppKit
import ExposePlusCore

/// macOS-style close dot: white circle with a dark ✕, turning red while the pointer is on it.
private final class CloseDotView: NSView {
    var onClick: (() -> Void)?
    private var hovering = false { didSet { needsDisplay = true } }

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }

    override func draw(_ dirtyRect: NSRect) {
        let dot = CloseDotPolicy.dotSize
        let r = NSRect(x: (bounds.width - dot) / 2, y: (bounds.height - dot) / 2, width: dot, height: dot)
        let circle = NSBezierPath(ovalIn: r)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set()
        (hovering ? NSColor(red: 1.0, green: 0.30, blue: 0.27, alpha: 1) : NSColor(white: 0.96, alpha: 1)).setFill()
        circle.fill()
        NSGraphicsContext.restoreGraphicsState()
        (hovering ? NSColor(red: 0.85, green: 0.22, blue: 0.20, alpha: 1) : NSColor(white: 0.70, alpha: 1)).setStroke()
        circle.lineWidth = 0.5
        circle.stroke()
        let c = NSPoint(x: r.midX, y: r.midY), d: CGFloat = 3.6
        let x = NSBezierPath()
        x.lineWidth = 1.7
        x.lineCapStyle = .round
        x.move(to: NSPoint(x: c.x - d, y: c.y - d)); x.line(to: NSPoint(x: c.x + d, y: c.y + d))
        x.move(to: NSPoint(x: c.x - d, y: c.y + d)); x.line(to: NSPoint(x: c.x + d, y: c.y - d))
        (hovering ? NSColor.white : NSColor(white: 0.25, alpha: 1)).setStroke()
        x.stroke()
    }
}

/// Small ✕ dot pinned to the top-left corner of the hovered Mission Control thumbnail.
/// Every window gets its own panel, positioned once and only shown or hidden afterwards, so a dot can
/// never slide from one window to another. All show/hide decisions live in `CloseDotState` (unit-tested).
final class CloseButtonOverlay {
    private var panels: [Int: NSPanel] = [:]
    private var activeID: Int?
    private var target: TargetWindow?
    private var timer: Timer?
    private let size = CloseDotPolicy.hitSize
    private var state = CloseDotState()

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let view = CloseDotView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        view.onClick = { [weak self] in self?.closeClicked() }
        panel.contentView = view
        return panel
    }

    func startWatching() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard Preferences.shared.showsCloseButton, MissionControl.isActive() else { return hide() }
        guard let cursor = CGEvent(source: nil)?.location else { return }
        let hovered = MissionControl.windowUnderCursor()
        let thumbnail = hovered.flatMap { t in
            t.thumbnailFrame.map { HoveredThumbnail(windowID: Int(t.windowID), frame: $0) }
        }
        switch state.update(cursor: cursor, hovered: thumbnail) {
        case .none:
            break
        case .hide:
            hideActive()
        case .show(let center, let windowID):
            guard let primary = NSScreen.screens.first else { return }
            hideActive()
            let panel = panels[windowID] ?? makePanel()
            panels[windowID] = panel
            target = hovered
            // AX coordinates are top-left based; AppKit is bottom-left based. Positioned while hidden.
            panel.setFrameOrigin(NSPoint(x: center.x - size / 2, y: primary.frame.height - center.y - size / 2))
            panel.orderFrontRegardless()
            activeID = windowID
            Log.write("dot show window=\(windowID)")
        }
    }

    private func hideActive() {
        if let id = activeID {
            panels[id]?.orderOut(nil)
            Log.write("dot hide window=\(id)")
        }
        activeID = nil
        target = nil
    }

    /// Hides everything and resets the state machine (feature off, Mission Control closed, or after a click).
    func hide() {
        _ = state.reset()
        hideActive()
        if !panels.isEmpty { panels.removeAll() }
    }

    private func closeClicked() {
        guard let t = target else { return }
        WindowActions.perform(.closeWindow, on: t)
        hide()
    }
}
