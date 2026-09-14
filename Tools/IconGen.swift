// IconGen — draws Yank's icon artwork from vectors and writes every asset the
// app bundle needs. Run from the repo root:
//
//     swift Tools/IconGen.swift Resources
//
// Zero dependencies (AppKit + CoreGraphics only). Every size is rendered
// natively from the vector description rather than downscaled from a master,
// which keeps the 16pt and 32pt variants crisp instead of mushy.
//
// The mark: a stack of clips with the newest sheet lifted and tilted off the
// top. The same geometry produces the colour app icon and the monochrome
// menu bar template, so the two can never drift out of sync.

import AppKit
import CoreGraphics
import Foundation

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources"

// MARK: - Palette (Graphite)

let GRADIENT_TOP = "#52525B"
let GRADIENT_BOT = "#18181B"
let SHEET_INK    = "#27272A"

// MARK: - Small helpers

func hex(_ s: String, _ a: Double = 1) -> CGColor {
    var v: UInt64 = 0
    Scanner(string: s.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
    return CGColor(red: Double((v >> 16) & 0xff) / 255,
                   green: Double((v >> 8) & 0xff) / 255,
                   blue: Double(v & 0xff) / 255, alpha: a)
}

func makeContext(_ w: Int, _ h: Int) -> CGContext {
    let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.setShouldAntialias(true)
    c.interpolationQuality = CGInterpolationQuality.high
    return c
}

func writePNG(_ c: CGContext, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: path))
}

func roundedRect(_ r: CGRect, _ radius: Double) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// Apple-style continuous-corner squircle (superellipse, n ≈ 5).
func squircle(_ r: CGRect, _ n: Double = 5.0) -> CGPath {
    let p = CGMutablePath()
    let a = r.width / 2, b = r.height / 2, cx = r.midX, cy = r.midY
    let steps = 1440
    for i in 0...steps {
        let t = Double(i) / Double(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * (ct < 0 ? -1 : 1) * pow(abs(ct), 2 / n)
        let y = cy + b * (st < 0 ? -1 : 1) * pow(abs(st), 2 / n)
        i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
    }
    p.closeSubpath()
    return p
}

/// Without these a linear gradient paints nothing outside its start/end band.
let FILL_EVERYWHERE: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]

// MARK: - App icon

/// Renders the app icon at `px` square.
///
/// Small sizes are not scaled-down versions of the large one — they are drawn
/// differently. Below 48px the shadow, sheen and tilt are removed (they cost
/// pixels and add nothing), the tile is squared up and grown to fill more of
/// the canvas, and the stack is reduced to two high-contrast sheets. Otherwise
/// the mark collapses into a white blob in Finder's list view.
func renderAppIcon(px: Int) -> CGContext {
    let S = Double(px)
    let k = S / 1024.0              // scale factor from the 1024 design grid
    let c = makeContext(px, px)

    let tiny = px < 48              // 16px and 32px variants
    let full = px >= 128            // ink lines only survive from here up

    // Tiny tiles grow to fill the canvas (no shadow to leave room for) and use
    // a higher superellipse exponent so they stay square instead of going oval.
    let inset = tiny ? 0.055 * S : 100 * k
    let iconRect = CGRect(x: inset, y: inset, width: S - 2 * inset, height: S - 2 * inset)
    let shape = squircle(iconRect, tiny ? 6.4 : 5.0)

    if !tiny {
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: -16 * k), blur: 36 * k,
                    color: hex("#000000", 0.32))
        c.addPath(shape); c.setFillColor(hex(GRADIENT_BOT)); c.fillPath()
        c.restoreGState()
    }

    c.saveGState()
    c.addPath(shape); c.clip()
    let cs = CGColorSpaceCreateDeviceRGB()
    c.drawLinearGradient(
        CGGradient(colorsSpace: cs,
                   colors: [hex(GRADIENT_TOP), hex(GRADIENT_BOT)] as CFArray,
                   locations: [0, 1])!,
        start: CGPoint(x: S / 2, y: iconRect.maxY), end: CGPoint(x: S / 2, y: iconRect.minY),
        options: FILL_EVERYWHERE)
    if !tiny {
        c.drawLinearGradient(
            CGGradient(colorsSpace: cs,
                       colors: [hex("#ffffff", 0.20), hex("#ffffff", 0)] as CFArray,
                       locations: [0, 1])!,
            start: CGPoint(x: 512 * k, y: 924 * k), end: CGPoint(x: 512 * k, y: 600 * k),
            options: [])
    }
    c.restoreGState()

    if px >= 64 {
        c.saveGState()
        c.addPath(squircle(iconRect.insetBy(dx: 2.5 * k, dy: 2.5 * k)))
        c.setStrokeColor(hex("#ffffff", 0.22)); c.setLineWidth(max(1, 4 * k))
        c.strokePath()
        c.restoreGState()
    }

    if tiny {
        // Two sheets, no tilt, no shadow — pure silhouette contrast.
        let w = 0.42 * S, h = 0.52 * S, radius = 0.06 * S
        let cx = S / 2, cy = S / 2
        c.addPath(roundedRect(CGRect(x: cx - w / 2 - 0.075 * S, y: cy - h / 2 + 0.075 * S,
                                     width: w, height: h), radius))
        c.setFillColor(hex("#ffffff", 0.58)); c.fillPath()
        // Knock a gap so the two sheets stay visually separate at 16px.
        c.saveGState()
        c.setBlendMode(.clear)
        c.addPath(roundedRect(CGRect(x: cx - w / 2 + 0.045 * S, y: cy - h / 2 - 0.105 * S,
                                     width: w + 0.03 * S, height: h + 0.03 * S), radius))
        c.fillPath()
        c.restoreGState()
        c.addPath(roundedRect(CGRect(x: cx - w / 2 + 0.075 * S, y: cy - h / 2 - 0.075 * S,
                                     width: w, height: h), radius))
        c.setFillColor(hex("#ffffff")); c.fillPath()
        return c
    }

    // Rear sheets of the stack.
    let w = 340 * k, h = 424 * k, radius = 48 * k
    for (dx, dy, alpha) in [(-40 * k, -104 * k, 0.38), (-20 * k, -52 * k, 0.60)] {
        c.addPath(roundedRect(CGRect(x: 512 * k - w / 2 + dx, y: 512 * k - h / 2 + dy,
                                     width: w, height: h), radius))
        c.setFillColor(hex("#ffffff", alpha)); c.fillPath()
    }

    // Front sheet: lifted and tilted off the stack.
    c.saveGState()
    c.translateBy(x: 512 * k + 24 * k, y: 512 * k + 64 * k)
    c.rotate(by: 6 * .pi / 180)
    let front = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
    c.setShadow(offset: CGSize(width: -12 * k, height: -14 * k), blur: 34 * k,
                color: hex("#000000", 0.34))
    c.addPath(roundedRect(front, radius)); c.setFillColor(hex("#ffffff")); c.fillPath()
    c.setShadow(offset: .zero, blur: 0, color: nil)

    if full {
        let lineH = 26 * k
        for (i, frac) in [0.70, 0.86, 0.50].enumerated() {
            let y = front.maxY - 118 * k - Double(i) * 76 * k
            c.addPath(roundedRect(CGRect(x: front.minX + 52 * k, y: y,
                                         width: (front.width - 104 * k) * frac,
                                         height: lineH), lineH / 2))
            c.setFillColor(hex(SHEET_INK, 0.92)); c.fillPath()
        }
    }
    c.restoreGState()
    return c
}

// MARK: - Menu bar glyph

/// Monochrome template glyph on an 18pt grid. Drawn in pure black with
/// transparency; AppKit recolours it for the light and dark menu bar once the
/// NSImage is flagged `isTemplate`.
func renderMenuBarGlyph(px: Int) -> CGContext {
    let u = Double(px) / 18.0
    let c = makeContext(px, px)

    c.setLineWidth(1.5 * u)
    c.setStrokeColor(hex("#000000"))
    c.addPath(roundedRect(CGRect(x: 2.4 * u, y: 2.6 * u, width: 7.2 * u, height: 9.0 * u), 1.7 * u))
    c.strokePath()

    c.saveGState()
    c.translateBy(x: 10.4 * u, y: 11.0 * u)
    c.rotate(by: 12 * .pi / 180)
    // Punch a hole so the tilted sheet sits cleanly above the rear outline.
    c.setBlendMode(.clear)
    c.addPath(roundedRect(CGRect(x: -4.15 * u, y: -5.05 * u, width: 8.3 * u, height: 10.1 * u),
                          1.95 * u))
    c.fillPath()
    c.setBlendMode(.normal)
    c.setFillColor(hex("#000000"))
    c.addPath(roundedRect(CGRect(x: -3.6 * u, y: -4.5 * u, width: 7.2 * u, height: 9.0 * u), 1.7 * u))
    c.fillPath()
    c.restoreGState()
    return c
}

// MARK: - Emit

let fm = FileManager.default
let iconsetDir = "\(outDir)/Yank.iconset"
try? fm.removeItem(atPath: iconsetDir)
try! fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// (filename, pixel size) — the ten variants iconutil expects.
let iconsetSizes: [(String, Int)] = [
    ("icon_16x16.png", 16),       ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),       ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),    ("icon_512x512@2x.png", 1024),
]
for (name, px) in iconsetSizes {
    writePNG(renderAppIcon(px: px), "\(iconsetDir)/\(name)")
}

// 1024px master, kept for the README and any future Icon Composer work.
writePNG(renderAppIcon(px: 1024), "\(outDir)/AppIcon-1024.png")

// Menu bar template pair.
writePNG(renderMenuBarGlyph(px: 18), "\(outDir)/MenuBarIcon.png")
writePNG(renderMenuBarGlyph(px: 36), "\(outDir)/MenuBarIcon@2x.png")

print("wrote \(iconsetSizes.count) iconset PNGs, AppIcon-1024.png, MenuBarIcon.png, MenuBarIcon@2x.png")
