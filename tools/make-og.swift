// Generates docs/assets/og.png — the 1200x630 social-share cover.
// Run:  swift tools/make-og.swift
import AppKit

let W: CGFloat = 1200, H: CGFloat = 630

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)!

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: a)
}
let ground  = rgb(0x0A, 0x0C, 0x11)
let ink     = rgb(0xEE, 0xF0, 0xF4)
let inkSoft = rgb(0x98, 0xA0, 0xAE)
let accent  = rgb(0x5E, 0x80, 0xFF)
let spark   = rgb(0xFF, 0x6A, 0x33)

// background
ground.setFill()
NSRect(x: 0, y: 0, width: W, height: H).fill()

// faint dot grid, top-left, fading out
let dot = accent.withAlphaComponent(0.10)
dot.setFill()
var gy: CGFloat = H - 60
var row = 0
while gy > H - 320 {
    var gx: CGFloat = 60
    while gx < 520 {
        let fade = max(0, 1 - (Double(row) / 9.0))
        dot.withAlphaComponent(0.12 * fade).setFill()
        NSBezierPath(ovalIn: NSRect(x: gx - 2, y: gy - 2, width: 4, height: 4)).fill()
        gx += 34
    }
    gy -= 34
    row += 1
}

// helper: corner bracket at point p, arms toward (dx,dy)
func bracket(_ p: NSPoint, _ dx: CGFloat, _ dy: CGFloat, arm: CGFloat, lw: CGFloat, _ c: NSColor) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: p.x + dx * arm, y: p.y))
    path.line(to: p)
    path.line(to: NSPoint(x: p.x, y: p.y + dy * arm))
    path.lineWidth = lw
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    c.setStroke()
    path.stroke()
}

// helper: draw text with a top-left anchor (y measured from the top edge)
func text(_ s: String, font: NSFont, color: NSColor, topLeft: NSPoint,
          kern: CGFloat = 0, maxWidth: CGFloat = W, lineSpacing: CGFloat = 0) {
    let para = NSMutableParagraphStyle()
    para.lineSpacing = lineSpacing
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color, .kern: kern, .paragraphStyle: para]
    let str = NSAttributedString(string: s, attributes: attrs)
    let bounds = str.boundingRect(with: NSSize(width: maxWidth, height: 1000),
                                  options: [.usesLineFragmentOrigin, .usesFontLeading])
    str.draw(with: NSRect(x: topLeft.x, y: H - topLeft.y - bounds.height,
                          width: maxWidth, height: bounds.height),
             options: [.usesLineFragmentOrigin, .usesFontLeading])
}

// ---- logo mark (top-left) ----
let cx: CGFloat = 78, cy = H - 82, s: CGFloat = 24
bracket(NSPoint(x: cx - s, y: cy + s),  1, -1, arm: 15, lw: 6, accent)
bracket(NSPoint(x: cx + s, y: cy + s), -1, -1, arm: 15, lw: 6, accent)
bracket(NSPoint(x: cx + s, y: cy - s), -1,  1, arm: 15, lw: 6, accent)
bracket(NSPoint(x: cx - s, y: cy - s),  1,  1, arm: 15, lw: 6, accent)
spark.setFill()
NSBezierPath(ovalIn: NSRect(x: cx - 6, y: cy - 6, width: 12, height: 12)).fill()

text("QuickSnap", font: .systemFont(ofSize: 40, weight: .bold), color: ink,
     topLeft: NSPoint(x: 120, y: 60))

// ---- marquee + headline ----
let mx: CGFloat = 74, mw: CGFloat = 900, mTop: CGFloat = 168, mh: CGFloat = 288
let marquee = NSBezierPath(rect: NSRect(x: mx, y: H - mTop - mh, width: mw, height: mh))
marquee.lineWidth = 3
marquee.setLineDash([14, 11], count: 2, phase: 0)
accent.withAlphaComponent(0.85).setStroke()
marquee.stroke()

let corners = [
    (NSPoint(x: mx, y: H - mTop), CGFloat(1), CGFloat(-1)),
    (NSPoint(x: mx + mw, y: H - mTop), CGFloat(-1), CGFloat(-1)),
    (NSPoint(x: mx + mw, y: H - mTop - mh), CGFloat(-1), CGFloat(1)),
    (NSPoint(x: mx, y: H - mTop - mh), CGFloat(1), CGFloat(1)),
]
for (p, dx, dy) in corners { bracket(p, dx, dy, arm: 26, lw: 7, accent) }

// spark where the drag "releases"
spark.withAlphaComponent(0.28).setFill()
NSBezierPath(ovalIn: NSRect(x: mx + mw - 16, y: H - mTop - mh - 16, width: 32, height: 32)).fill()
spark.setFill()
NSBezierPath(ovalIn: NSRect(x: mx + mw - 9, y: H - mTop - mh - 9, width: 18, height: 18)).fill()

text("Drag a box.\nPaste it anywhere.",
     font: .systemFont(ofSize: 86, weight: .heavy), color: ink,
     topLeft: NSPoint(x: mx + 44, y: mTop + 34), kern: -1.5, maxWidth: mw - 80, lineSpacing: 6)

// ---- captions ----
text("Press \u{2318}\u{21E7}2  ·  drag  ·  Copy  ·  paste anywhere  —  a tiny macOS menu-bar app",
     font: .systemFont(ofSize: 27, weight: .regular), color: inkSoft,
     topLeft: NSPoint(x: 78, y: 520), maxWidth: W - 156)

text("jtroshani.github.io/QuickSnap  ·  free & open source",
     font: .systemFont(ofSize: 22, weight: .medium), color: accent,
     topLeft: NSPoint(x: 78, y: 566), maxWidth: W - 156)

NSGraphicsContext.restoreGraphicsState()

let out = URL(fileURLWithPath: "docs/assets/og.png")
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote \(out.path)  (\(rep.pixelsWide)x\(rep.pixelsHigh))")
