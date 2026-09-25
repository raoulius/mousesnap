// Generates AppIcon.icns: `swift icon.swift`
import Cocoa

func draw(_ c: CGContext, _ scale: CGFloat) {
    let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

    // macOS icon grid: 824pt rounded square centered on a 1024 canvas.
    let bg = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 30 * scale, color: CGColor(gray: 0, alpha: 0.35))
    c.addPath(bg); c.setFillColor(white); c.fillPath()
    c.restoreGState()
    c.saveGState()
    c.addPath(bg); c.clip()
    let gradient = CGGradient(colorsSpace: nil, colors: [
        CGColor(red: 0.36, green: 0.58, blue: 1.00, alpha: 1),
        CGColor(red: 0.23, green: 0.25, blue: 0.85, alpha: 1),
    ] as CFArray, locations: nil)!
    c.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
    c.restoreGState()

    // Monitor
    let screen = CGPath(roundedRect: CGRect(x: 230, y: 290, width: 564, height: 370), cornerWidth: 36, cornerHeight: 36, transform: nil)
    c.addPath(screen); c.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.16)); c.fillPath()
    c.addPath(screen); c.setStrokeColor(white); c.setLineWidth(30); c.strokePath()
    c.setFillColor(white)
    c.fill(CGRect(x: 477, y: 672, width: 70, height: 60))
    c.addPath(CGPath(roundedRect: CGRect(x: 382, y: 726, width: 260, height: 32), cornerWidth: 16, cornerHeight: 16, transform: nil))
    c.fillPath()

    // Rays around the screen's center, skipping the quadrant the cursor sits in.
    let center = CGPoint(x: 512, y: 475)
    c.setLineCap(.round); c.setLineWidth(22)
    c.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
    for angle in [-90.0, 180, -135, -45, 135] {
        let (dx, dy) = (cos(angle * .pi / 180), sin(angle * .pi / 180))
        c.move(to: CGPoint(x: center.x + dx * 62, y: center.y + dy * 62))
        c.addLine(to: CGPoint(x: center.x + dx * 118, y: center.y + dy * 118))
    }
    c.strokePath()

    // Classic arrow cursor, tip on the exact center.
    let arrow = CGMutablePath()
    let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, 16), (4, 12.5), (6.8, 19), (9.2, 18), (6.5, 11.6), (11.5, 11.6)]
    arrow.addLines(between: pts.map { CGPoint(x: center.x + $0.0 * 8.5, y: center.y + $0.1 * 8.5) })
    arrow.closeSubpath()
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -6 * scale), blur: 14 * scale, color: CGColor(gray: 0, alpha: 0.4))
    c.setLineJoin(.round); c.setLineWidth(16)
    c.addPath(arrow); c.setStrokeColor(white); c.strokePath()
    c.restoreGState()
    c.addPath(arrow); c.setFillColor(CGColor(gray: 0.08, alpha: 1)); c.fillPath()
}

func png(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let c = NSGraphicsContext.current!.cgContext
    let scale = CGFloat(px) / 1024
    c.scaleBy(x: scale, y: -scale); c.translateBy(x: 0, y: -1024) // draw in 1024pt, top-left origin
    draw(c, scale)
    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

let dir = URL(fileURLWithPath: "AppIcon.iconset")
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try! png(size).write(to: dir.appendingPathComponent("icon_\(size)x\(size).png"))
    try! png(size * 2).write(to: dir.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", "AppIcon.iconset"]
try! p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(at: dir)
try! png(1024).write(to: URL(fileURLWithPath: "AppIcon.png")) // preview
