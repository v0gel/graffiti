// Draws the icons, the wordmark and the installer background from the art in assets/art.

import AppKit
func art(_ name: String) -> NSImage { NSImage(contentsOfFile: "assets/art/\(name).svg")! }
func flatten(_ img: NSImage, _ px: CGFloat) -> NSImage {
    let s = px / max(img.size.width, img.size.height)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(img.size.width * s), pixelsHigh: Int(img.size.height * s),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: CGFloat(rep.pixelsWide), height: CGFloat(rep.pixelsHigh)))
    NSGraphicsContext.restoreGraphicsState()
    let out = NSImage(size: img.size); out.addRepresentation(rep); return out
}
// Turns the white outline into a see-through gap, so the wordmark can be recoloured for dark mode
// and the letters still stay apart.
func knockout(_ img: NSImage, _ px: CGFloat) -> NSImage {
    let flat = flatten(img, px)
    let rep = flat.representations.first as! NSBitmapImageRep
    let w = rep.pixelsWide, h = rep.pixelsHigh
    let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: w * 4, bitsPerPixel: 32)!
    let src = rep.bitmapData!, dst = out.bitmapData!, row = rep.bytesPerRow
    for y in 0..<h { for x in 0..<w {
        let i = y * row + x * 4, o = y * w * 4 + x * 4
        let light = (Int(src[i]) + Int(src[i + 1]) + Int(src[i + 2])) / 3
        dst[o] = 0; dst[o + 1] = 0; dst[o + 2] = 0; dst[o + 3] = UInt8(max(0, Int(src[i + 3]) - light))
    } }
    let result = NSImage(size: img.size); result.addRepresentation(out); return result
}
func fit(_ img: NSImage, in r: CGRect) -> CGRect {
    let s = min(r.width / img.size.width, r.height / img.size.height)
    let w = img.size.width * s, h = img.size.height * s
    return CGRect(x: r.midX - w / 2, y: r.midY - h / 2, width: w, height: h)
}
func drawing(_ w: Int, _ h: Int, _ body: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    body(ctx)
    NSGraphicsContext.restoreGraphicsState()
    return ctx.makeImage()!
}
func save(_ img: CGImage, _ out: String) {
    try! NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
}
let wordmark = art("wordmark"), solidWord = knockout(art("wordmark"), 1600), letterG = art("g"), sprayCan = flatten(art("can"), 2000), menuCan = art("menu")
let black = CGColor(gray: 0, alpha: 1)
let paper = CGColor(red: 0.98, green: 0.976, blue: 0.965, alpha: 1)

save(drawing(18, 18) { _ in menuCan.draw(in: fit(menuCan, in: CGRect(x: 1, y: 1, width: 16, height: 16))) }, "Resources/MenuIcon.png")
save(drawing(36, 36) { _ in menuCan.draw(in: fit(menuCan, in: CGRect(x: 2, y: 2, width: 32, height: 32))) }, "Resources/MenuIcon@2x.png")
save(drawing(360, 44) { _ in solidWord.draw(in: fit(solidWord, in: CGRect(x: 4, y: 4, width: 352, height: 36))) }, "Resources/Header@2x.png")
save(drawing(1600, 320) { _ in solidWord.draw(in: fit(solidWord, in: CGRect(x: 0, y: 0, width: 1600, height: 320))) }, "site/wordmark.png")

func appIcon(_ px: Int) -> CGImage {
    drawing(px, px) { ctx in
        let p = CGFloat(px)
        ctx.setFillColor(paper)
        ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: p, height: p), cornerWidth: p * 0.22, cornerHeight: p * 0.22, transform: nil))
        ctx.fillPath()
        letterG.draw(in: fit(letterG, in: CGRect(x: p * 0.07, y: p * 0.20, width: p * 0.42, height: p * 0.56)))
        sprayCan.draw(in: fit(sprayCan, in: CGRect(x: p * 0.45, y: p * 0.14, width: p * 0.50, height: p * 0.70)))
    }
}
try? FileManager.default.createDirectory(atPath: "assets/Graffiti.iconset", withIntermediateDirectories: true)
for s in [16, 32, 128, 256, 512] {
    for (scale, suffix) in [(1, ""), (2, "@2x")] {
        save(appIcon(s * scale), "assets/Graffiti.iconset/icon_\(s)x\(s)\(suffix).png")
    }
}
save(appIcon(512), "site/icon.png")

func background(_ out: String, scale: CGFloat) {
    let w: CGFloat = 640, h0: CGFloat = 560
    let W = Int(w * scale), H = Int(h0 * scale)
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    ctx.setFillColor(CGColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h0))
    let g0 = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = g0
    wordmark.draw(in: fit(wordmark, in: CGRect(x: 0, y: h0 - 30 - 52, width: w, height: 52)))
    NSGraphicsContext.restoreGraphicsState()
    ctx.setFillColor(black)
    let y: CGFloat = h0 - 165
    let curve = CGMutablePath()
    curve.move(to: CGPoint(x: 252, y: y - 4))
    curve.addQuadCurve(to: CGPoint(x: 378, y: y - 4), control: CGPoint(x: 315, y: y + 34))
    ctx.setLineCap(.round)
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.10)); ctx.setLineWidth(22); ctx.addPath(curve); ctx.strokePath()
    ctx.setStrokeColor(black); ctx.setLineWidth(9); ctx.addPath(curve); ctx.strokePath()
    let head = CGMutablePath()
    head.move(to: CGPoint(x: 398, y: y - 12)); head.addLine(to: CGPoint(x: 370, y: y + 12)); head.addLine(to: CGPoint(x: 364, y: y - 22)); head.closeSubpath()
    ctx.setFillColor(black); ctx.addPath(head); ctx.fillPath()
    for (px, py, r) in [(300.0, y + 30, 2.0), (336, y + 26, 1.5), (270, y + 18, 1.2), (356, y + 14, 2.2), (318, y + 40, 1.0)] {
        ctx.fillEllipse(in: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
    }
    ctx.setFillColor(CGColor(gray: 0, alpha: 0.12)); ctx.fill(CGRect(x: 40, y: h0 - 300, width: w - 80, height: 1))

    let g = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = g
    func step(_ n: Int, _ title: String, _ detail: String, x: CGFloat, top: CGFloat, width: CGFloat) {
        let cy = h0 - top - 11
        NSColor(white: 0.2, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: x, y: cy - 11, width: 22, height: 22)).fill()
        let num = NSAttributedString(string: "\(n)", attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .bold), .foregroundColor: NSColor.white])
        num.draw(at: NSPoint(x: x + 11 - num.size().width / 2, y: cy - num.size().height / 2))
        let text = NSMutableAttributedString(string: title, attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor(white: 0.2, alpha: 1)])
        if !detail.isEmpty {
            text.append(NSAttributedString(string: "\n" + detail, attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor(white: 0.4, alpha: 1)]))
        }
        text.draw(in: NSRect(x: x + 32, y: h0 - top - 60, width: width - 32, height: 60))
    }
    step(1, "Drag Graffiti to Applications", "", x: 220, top: 262, width: 300)
    step(2, "Open Graffiti from Applications", "If your Mac blocks it, click Done.", x: 48, top: 330, width: 330)
    step(3, "Double-click Allow Graffiti", "Scroll down, click Open Anyway, then Open.", x: 48, top: 400, width: 330)
    NSGraphicsContext.restoreGraphicsState()
    try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: out))
}
try? FileManager.default.createDirectory(atPath: "assets/dmg", withIntermediateDirectories: true)
background("assets/dmg/background.png", scale: 1)
background("assets/dmg/background@2x.png", scale: 2)
print("assets written")

save(appIcon(180), "site/apple-touch-icon.png")
save(drawing(32, 32) { _ in menuCan.draw(in: fit(menuCan, in: CGRect(x: 1, y: 1, width: 30, height: 30))) }, "site/favicon-32.png")
save(drawing(1200, 630) { ctx in
    ctx.setFillColor(CGColor(red: 0.92, green: 0.91, blue: 0.89, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 630))
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: CGColor(gray: 0, alpha: 0.18))
    NSImage(cgImage: appIcon(360), size: NSSize(width: 360, height: 360)).draw(in: CGRect(x: 90, y: 135, width: 360, height: 360))
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    wordmark.draw(in: fit(wordmark, in: CGRect(x: 510, y: 330, width: 600, height: 130)))
    let tag = NSAttributedString(string: "The clipboard history for Mac.\nFree, from Kingdom of Id.", attributes: [
        .font: NSFont.systemFont(ofSize: 34, weight: .medium), .foregroundColor: NSColor(white: 0.2, alpha: 1)])
    tag.draw(in: CGRect(x: 520, y: 170, width: 640, height: 130))
}, "site/social.png")
print("site images written")
