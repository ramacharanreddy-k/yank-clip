// IconPreview — renders a review sheet for Yank's icon artwork: a Dock mockup,
// the true sizes Finder draws, small sizes magnified to show real pixels, and
// the menu bar glyph on both bar appearances.
//
// Run after IconGen, from the repo root:
//
//     swift Tools/IconGen.swift Resources
//     swift Tools/IconPreview.swift Resources
//
// Writes <dir>/preview.png. Purely a design-review tool; the app never uses it.

import AppKit
import CoreGraphics
import Foundation

func hex(_ s: String, _ a: Double = 1) -> CGColor {
    var v: UInt64 = 0
    Scanner(string: s.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
    return CGColor(red: Double((v>>16)&0xff)/255, green: Double((v>>8)&0xff)/255,
                   blue: Double(v&0xff)/255, alpha: a)
}
func mkctx(_ w: Int, _ h: Int) -> CGContext {
    let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.setShouldAntialias(true); c.interpolationQuality = CGInterpolationQuality.high
    return c
}
func rr(_ r: CGRect, _ rad: Double) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
}
func text(_ c: CGContext, _ s: String, _ x: Double, _ y: Double, _ sz: Double,
          _ col: CGColor, bold: Bool = false) {
    let f = (bold ? NSFont.systemFont(ofSize: sz, weight: .semibold)
                  : NSFont.systemFont(ofSize: sz)) as CTFont
    c.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(
        string: s, attributes: [.font: f, .foregroundColor: col])), c)
}
func img(_ p: String) -> CGImage {
    NSImage(contentsOfFile: p)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}
let R = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources"

let W: Double = 1000, H: Double = 1080
let p = mkctx(Int(W), Int(H))
p.setFillColor(hex("#8A8F98")); p.fill(CGRect(x: 0, y: 0, width: W, height: H))
let white = hex("#FFFFFF"), dimw = hex("#FFFFFF", 0.78)

// ── 1. Dock mockup ──
var y = H - 250
text(p, "DOCK", 40, y + 186, 13, dimw, bold: true)
let dockW: Double = 560, dockH: Double = 118
let dockX = (W - dockW)/2
p.saveGState()
p.setShadow(offset: CGSize(width: 0, height: -6), blur: 22, color: hex("#000000", 0.35))
p.addPath(rr(CGRect(x: dockX, y: y + 40, width: dockW, height: dockH), 30))
p.setFillColor(hex("#3A3A3E", 0.92)); p.fillPath()
p.restoreGState()
// neighbour icons + ours in the middle
let slot: Double = 92
let neighbours = [hex("#3B82F6"), hex("#34D399"), hex("#F59E0B"), hex("#EF4444")]
for i in 0..<5 {
    let x = dockX + 34 + Double(i) * (slot + 10)
    let r = CGRect(x: x, y: y + 54, width: slot, height: slot)
    if i == 2 {
        p.draw(img("\(R)/Yank.iconset/icon_128x128@2x.png"), in: r)
    } else {
        let n = neighbours[i > 2 ? i-1 : i]
        p.addPath(rr(r, 21)); p.setFillColor(n); p.fillPath()
    }
}
// running dot under ours
p.addPath(CGPath(ellipseIn: CGRect(x: dockX + 34 + 2*(slot+10) + slot/2 - 3.5,
                                   y: y + 46, width: 7, height: 7), transform: nil))
p.setFillColor(hex("#FFFFFF", 0.85)); p.fillPath()

// ── 2. Size ladder, true size ──
y -= 196
text(p, "TRUE SIZE  —  what Finder actually draws", 40, y + 148, 13, dimw, bold: true)
let ladder: [(String, Int)] = [("512", 512), ("256", 256), ("128", 128),
                               ("64", 64), ("32", 32), ("16", 16)]
var lx: Double = 40
for (label, px) in ladder {
    let f = px >= 256 ? "icon_256x256.png" :
            px == 128 ? "icon_128x128.png" :
            px == 64  ? "icon_32x32@2x.png" :
            px == 32  ? "icon_32x32.png" : "icon_16x16.png"
    let drawPx = min(Double(px), 128)
    p.draw(img("\(R)/Yank.iconset/\(f)"),
           in: CGRect(x: lx, y: y, width: drawPx, height: drawPx))
    text(p, "\(label)px", lx, y - 20, 12, dimw)
    lx += drawPx + 26
}

// ── 3. Small sizes magnified 6x ──
y -= 236
text(p, "SMALL SIZES MAGNIFIED 6×  —  detail drops out on purpose", 40, y + 168, 13, dimw, bold: true)
var mx: Double = 40
for (label, file) in [("16px", "icon_16x16.png"), ("32px", "icon_32x32.png"),
                      ("64px", "icon_32x32@2x.png"), ("128px", "icon_128x128.png")] {
    let side: Double = 150
    p.saveGState()
    p.interpolationQuality = CGInterpolationQuality.none   // show real pixels
    p.draw(img("\(R)/\(file.hasPrefix("icon") ? "Yank.iconset/" + file : file)"),
           in: CGRect(x: mx, y: y, width: side, height: side))
    p.restoreGState()
    text(p, label, mx, y - 20, 12, dimw)
    mx += side + 30
}

// ── 4. Menu bar, both appearances ──
y -= 130
func stampGlyph(_ rect: CGRect, _ px: Int, _ col: CGColor) {
    let file = px == 36 ? "\(R)/MenuBarIcon@2x.png" : "\(R)/MenuBarIcon.png"
    p.saveGState(); p.clip(to: rect, mask: img(file))
    p.setFillColor(col); p.fill(rect); p.restoreGState()
}
for (row, dark) in [(0, true), (1, false)] {
    let by = y - Double(row) * 64
    p.setFillColor(dark ? hex("#1D1D1F") : hex("#F6F6F8"))
    p.fill(CGRect(x: 0, y: by, width: W, height: 58))
    let fg = dark ? hex("#FFFFFF") : hex("#000000", 0.88)
    let dim = dark ? hex("#FFFFFF", 0.60) : hex("#000000", 0.52)
    let cy = by + 29
    stampGlyph(CGRect(x: 34, y: cy - 18, width: 36, height: 36), 36, fg)
    var x: Double = 112
    for r in [7.0, 13.0, 19.0] {
        let a = CGMutablePath()
        a.addArc(center: CGPoint(x: x+20, y: cy-9), radius: r,
                 startAngle: .pi*0.22, endAngle: .pi*0.78, clockwise: false)
        p.addPath(a); p.setStrokeColor(dim); p.setLineWidth(3.4); p.setLineCap(.round); p.strokePath()
    }
    p.addPath(CGPath(ellipseIn: CGRect(x: x+17, y: cy-12, width: 6, height: 6), transform: nil))
    p.setFillColor(dim); p.fillPath()
    x += 74
    p.addPath(rr(CGRect(x: x, y: cy-9, width: 34, height: 17), 5))
    p.setStrokeColor(dim); p.setLineWidth(2.6); p.strokePath()
    p.addPath(rr(CGRect(x: x+3.5, y: cy-5.5, width: 20, height: 10), 2.5))
    p.setFillColor(dim); p.fillPath()
    x += 60
    text(p, "Thu 13 Sep  9:41", x, cy - 6, 15, fg)
    text(p, dark ? "Dark menu bar — true size" : "Light menu bar — true size",
         W - 250, cy - 6, 13, dim)
}
text(p, "MENU BAR", 40, y + 74, 13, dimw, bold: true)

let rep = NSBitmapImageRep(cgImage: p.makeImage()!)
try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: "\(R)/preview.png"))
print("ok")
