import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 800, pixelsHigh: 480,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(calibratedRed: 0.975, green: 0.968, blue: 0.995, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 800, height: 480)).fill()
func text(_ value: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    (value as NSString).draw(in: NSRect(x: 20, y: y, width: 760, height: size + 14),
        withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color, .paragraphStyle: paragraph])
}
let ink = NSColor(calibratedRed: 0.12, green: 0.10, blue: 0.23, alpha: 1)
let secondary = NSColor(calibratedRed: 0.43, green: 0.39, blue: 0.55, alpha: 1)
text("MiddleClicker", y: 394, size: 34, weight: .semibold, color: ink)
text("Fn + Click. Real middle-button control.", y: 360, size: 17, weight: .regular, color: secondary)
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 345, y: 260))
arrow.line(to: NSPoint(x: 452, y: 260))
arrow.move(to: NSPoint(x: 429, y: 281))
arrow.line(to: NSPoint(x: 453, y: 260))
arrow.line(to: NSPoint(x: 429, y: 239))
arrow.lineWidth = 5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
NSColor(calibratedRed: 0.59, green: 0.40, blue: 0.90, alpha: 1).setStroke()
arrow.stroke()
text("Drag MiddleClicker into Applications", y: 151, size: 18, weight: .medium, color: ink)
text("Free and open source · MIT License", y: 9, size: 12, weight: .regular, color: secondary)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: destination)
