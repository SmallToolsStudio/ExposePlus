import AppKit

func png(_ size: Int, _ draw: (CGFloat) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(CGFloat(size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func rr(_ r: NSRect, _ c: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect: r, xRadius: c, yRadius: c) }

func appIcon(_ s: CGFloat) {
    let u = s / 1024
    // squircle tile with standard macOS margins
    let tile = NSRect(x: 100*u, y: 100*u, width: 824*u, height: 824*u)
    let path = rr(tile, 185*u)
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowOffset = NSSize(width: 0, height: -12*u); sh.shadowBlurRadius = 24*u
    sh.shadowColor = NSColor.black.withAlphaComponent(0.35); sh.set()
    NSColor.black.setFill(); path.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [NSColor(red: 0.20, green: 0.55, blue: 1.0, alpha: 1), NSColor(red: 0.38, green: 0.22, blue: 0.85, alpha: 1)])!.draw(in: path, angle: -60)
    // three windows
    let wins: [NSRect] = [
        NSRect(x: 190*u, y: 520*u, width: 300*u, height: 230*u),
        NSRect(x: 534*u, y: 520*u, width: 300*u, height: 230*u),
        NSRect(x: 362*u, y: 270*u, width: 300*u, height: 230*u),
    ]
    for (i, w) in wins.enumerated() {
        NSGraphicsContext.saveGraphicsState()
        let s2 = NSShadow(); s2.shadowOffset = NSSize(width: 0, height: -6*u); s2.shadowBlurRadius = 14*u
        s2.shadowColor = NSColor.black.withAlphaComponent(0.25); s2.set()
        NSColor.white.withAlphaComponent(0.96).setFill(); rr(w, 28*u).fill()
        NSGraphicsContext.restoreGraphicsState()
        // title bar
        NSColor(white: 0.88, alpha: 1).setFill()
        let bar = NSBezierPath(roundedRect: NSRect(x: w.minX, y: w.maxY-52*u, width: w.width, height: 52*u), xRadius: 28*u, yRadius: 28*u)
        bar.fill()
        NSColor(white: 0.88, alpha: 1).setFill()
        NSRect(x: w.minX, y: w.maxY-52*u, width: w.width, height: 28*u).fill()
        let dots = [NSColor(red: 1, green: 0.37, blue: 0.34, alpha: 1), NSColor(red: 1, green: 0.74, blue: 0.18, alpha: 1), NSColor(red: 0.16, green: 0.79, blue: 0.25, alpha: 1)]
        for (j, c) in dots.enumerated() {
            c.setFill()
            NSBezierPath(ovalIn: NSRect(x: w.minX + (20 + CGFloat(j)*30)*u, y: w.maxY - 36*u, width: 18*u, height: 18*u)).fill()
        }
        _ = i
    }
    // red close badge on top-right window
    let w = wins[1]
    let c = NSPoint(x: w.maxX - 6*u, y: w.maxY - 6*u)
    let r = 78*u
    NSGraphicsContext.saveGraphicsState()
    let s3 = NSShadow(); s3.shadowOffset = NSSize(width: 0, height: -6*u); s3.shadowBlurRadius = 12*u
    s3.shadowColor = NSColor.black.withAlphaComponent(0.4); s3.set()
    NSColor(red: 1, green: 0.27, blue: 0.23, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: c.x-r, y: c.y-r, width: 2*r, height: 2*r)).fill()
    NSGraphicsContext.restoreGraphicsState()
    let x = NSBezierPath(); x.lineWidth = 22*u; x.lineCapStyle = .round
    let d = 28*u
    x.move(to: NSPoint(x: c.x-d, y: c.y-d)); x.line(to: NSPoint(x: c.x+d, y: c.y+d))
    x.move(to: NSPoint(x: c.x-d, y: c.y+d)); x.line(to: NSPoint(x: c.x+d, y: c.y-d))
    NSColor.white.setStroke(); x.stroke()
}

func menuIcon(_ s: CGFloat) {
    let u = s / 18
    NSColor.black.setStroke(); NSColor.black.setFill()
    func win(_ r: NSRect) { let p = rr(r, 1.6*u); p.lineWidth = 1.3*u; p.stroke()
        NSRect(x: r.minX, y: r.maxY-2.2*u, width: r.width, height: 1.3*u).fill() }
    win(NSRect(x: 1.5*u, y: 10*u, width: 6.5*u, height: 5.5*u))
    win(NSRect(x: 10*u, y: 10*u, width: 6.5*u, height: 5.5*u))
    win(NSRect(x: 5.75*u, y: 2.5*u, width: 6.5*u, height: 5.5*u))
}

let out = CommandLine.arguments[1]
let fm = FileManager.default
let iconset = out + "/AppIcon.iconset"
try? fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! png(base) { appIcon($0) }.write(to: URL(fileURLWithPath: "\(iconset)/icon_\(base)x\(base).png"))
    try! png(base*2) { appIcon($0) }.write(to: URL(fileURLWithPath: "\(iconset)/icon_\(base)x\(base)@2x.png"))
}
try! png(1024) { appIcon($0) }.write(to: URL(fileURLWithPath: out + "/AppIcon-1024.png"))
try! png(18) { menuIcon($0) }.write(to: URL(fileURLWithPath: out + "/MenuBarIcon.png"))
try! png(36) { menuIcon($0) }.write(to: URL(fileURLWithPath: out + "/MenuBarIcon@2x.png"))
