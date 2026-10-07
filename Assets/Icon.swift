import AppKit

let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(size) / 1024)
    transform.concat()
    NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.19, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 55, y: 55, width: 914, height: 914), xRadius: 205, yRadius: 205).fill()
    NSColor(calibratedRed: 0.03, green: 0.04, blue: 0.10, alpha: 0.6).setFill()
    NSBezierPath(roundedRect: NSRect(x: 414, y: 160, width: 445, height: 676), xRadius: 220, yRadius: 220).fill()
    NSColor(calibratedRed: 0.96, green: 0.97, blue: 1, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 405, y: 191, width: 445, height: 676), xRadius: 220, yRadius: 220).fill()
    let seam = NSBezierPath()
    seam.move(to: NSPoint(x: 435, y: 595))
    seam.line(to: NSPoint(x: 820, y: 595))
    seam.move(to: NSPoint(x: 628, y: 817))
    seam.line(to: NSPoint(x: 628, y: 598))
    seam.lineWidth = 11
    seam.lineCapStyle = .round
    NSColor(calibratedRed: 0.78, green: 0.81, blue: 0.89, alpha: 1).setStroke()
    seam.stroke()
    NSColor(calibratedRed: 0.97, green: 0.59, blue: 0.31, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 584, y: 620, width: 88, height: 166), xRadius: 43, yRadius: 43).fill()
    NSColor(calibratedRed: 0.36, green: 0.23, blue: 0.72, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 135, y: 253, width: 330, height: 330), xRadius: 97, yRadius: 97).fill()
    NSColor(calibratedRed: 0.59, green: 0.40, blue: 0.94, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 135, y: 270, width: 330, height: 330), xRadius: 97, yRadius: 97).fill()
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    ("fn" as NSString).draw(in: NSRect(x: 135, y: 345, width: 330, height: 202),
        withAttributes: [.font: NSFont.systemFont(ofSize: 155, weight: .semibold),
            .foregroundColor: NSColor.white, .paragraphStyle: paragraph])
    NSGraphicsContext.restoreGraphicsState()
    let data = bitmap.representation(using: .png, properties: [:])!
    for base in [16, 32, 128, 256, 512] {
        if size == base { try data.write(to: folder.appendingPathComponent("icon_\(base)x\(base).png")) }
        if size == base * 2 { try data.write(to: folder.appendingPathComponent("icon_\(base)x\(base)@2x.png")) }
    }
}
