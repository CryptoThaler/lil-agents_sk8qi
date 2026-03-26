import AppKit
import AVFoundation
import Foundation

struct CharacterPalette {
    let name: String
    let outputMovie: URL
    let previewPNG: URL
    let skin: NSColor
    let shellDark: NSColor
    let shellLight: NSColor
    let jacket: NSColor
    let jacketShadow: NSColor
    let hoodie: NSColor
    let pants: NSColor
    let shoe: NSColor
    let sole: NSColor
    let accent: NSColor
    let boardAccent: NSColor
    let isAxolotl: Bool
}

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let appRoot = repoRoot.appendingPathComponent("LilSk8ers", isDirectory: true)
let size = CGSize(width: 1080, height: 1920)
let fps: Int32 = 24
let duration = 10.0
let frameCount = Int(duration * Double(fps))

let axo = CharacterPalette(
    name: "AXO",
    outputMovie: appRoot.appendingPathComponent("walk-bruce-01.mov"),
    previewPNG: repoRoot.appendingPathComponent("generated-axo.png"),
    skin: NSColor(calibratedRed: 0.99, green: 0.73, blue: 0.86, alpha: 1.0),
    shellDark: NSColor(calibratedRed: 0.56, green: 0.18, blue: 0.46, alpha: 1.0),
    shellLight: NSColor(calibratedRed: 1.00, green: 0.55, blue: 0.84, alpha: 1.0),
    jacket: NSColor(calibratedRed: 0.29, green: 0.82, blue: 0.69, alpha: 1.0),
    jacketShadow: NSColor(calibratedRed: 0.08, green: 0.49, blue: 0.39, alpha: 1.0),
    hoodie: NSColor(calibratedRed: 0.95, green: 0.95, blue: 0.98, alpha: 1.0),
    pants: NSColor(calibratedRed: 0.14, green: 0.15, blue: 0.28, alpha: 1.0),
    shoe: NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.15, alpha: 1.0),
    sole: NSColor(calibratedRed: 0.99, green: 0.89, blue: 0.40, alpha: 1.0),
    accent: NSColor(calibratedRed: 0.96, green: 0.34, blue: 0.58, alpha: 1.0),
    boardAccent: NSColor(calibratedRed: 0.98, green: 0.73, blue: 0.20, alpha: 1.0),
    isAxolotl: true
)

let mudbug = CharacterPalette(
    name: "Mudbug",
    outputMovie: appRoot.appendingPathComponent("walk-jazz-01.mov"),
    previewPNG: repoRoot.appendingPathComponent("generated-mudbug.png"),
    skin: NSColor(calibratedRed: 0.98, green: 0.50, blue: 0.38, alpha: 1.0),
    shellDark: NSColor(calibratedRed: 0.53, green: 0.12, blue: 0.08, alpha: 1.0),
    shellLight: NSColor(calibratedRed: 0.98, green: 0.36, blue: 0.20, alpha: 1.0),
    jacket: NSColor(calibratedRed: 0.96, green: 0.63, blue: 0.19, alpha: 1.0),
    jacketShadow: NSColor(calibratedRed: 0.66, green: 0.36, blue: 0.06, alpha: 1.0),
    hoodie: NSColor(calibratedRed: 0.93, green: 0.92, blue: 0.95, alpha: 1.0),
    pants: NSColor(calibratedRed: 0.18, green: 0.20, blue: 0.20, alpha: 1.0),
    shoe: NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1.0),
    sole: NSColor(calibratedRed: 0.97, green: 0.93, blue: 0.83, alpha: 1.0),
    accent: NSColor(calibratedRed: 0.88, green: 0.19, blue: 0.15, alpha: 1.0),
    boardAccent: NSColor(calibratedRed: 0.20, green: 0.59, blue: 0.92, alpha: 1.0),
    isAxolotl: false
)

extension NSColor {
    func mix(with other: NSColor, amount: CGFloat) -> NSColor {
        let a = usingColorSpace(.deviceRGB) ?? self
        let b = other.usingColorSpace(.deviceRGB) ?? other
        let clamped = max(0, min(1, amount))
        return NSColor(
            calibratedRed: a.redComponent + (b.redComponent - a.redComponent) * clamped,
            green: a.greenComponent + (b.greenComponent - a.greenComponent) * clamped,
            blue: a.blueComponent + (b.blueComponent - a.blueComponent) * clamped,
            alpha: a.alphaComponent + (b.alphaComponent - a.alphaComponent) * clamped
        )
    }

    func darkened(_ amount: CGFloat) -> NSColor {
        mix(with: .black, amount: amount)
    }

    func lightened(_ amount: CGFloat) -> NSColor {
        mix(with: .white, amount: amount)
    }
}

func smoothStep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    if edge0 == edge1 { return x < edge0 ? 0 : 1 }
    let t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)
}

func roundedRect(center: CGPoint, width: CGFloat, height: CGFloat, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: CGRect(
        x: center.x - width / 2,
        y: center.y - height / 2,
        width: width,
        height: height
    ), xRadius: radius, yRadius: radius)
}

func capsule(center: CGPoint, width: CGFloat, height: CGFloat) -> NSBezierPath {
    roundedRect(center: center, width: width, height: height, radius: min(width, height) / 2)
}

func ellipse(center: CGPoint, width: CGFloat, height: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height))
}

func fill(_ path: NSBezierPath, color: NSColor) {
    color.setFill()
    path.fill()
}

func stroke(_ path: NSBezierPath, color: NSColor, width: CGFloat) {
    color.setStroke()
    path.lineWidth = width
    path.stroke()
}

func withSavedGraphics(_ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    body()
    NSGraphicsContext.restoreGraphicsState()
}

func drawShadow(at center: CGPoint, width: CGFloat, height: CGFloat, alpha: CGFloat) {
    withSavedGraphics {
        let shadow = NSShadow()
        shadow.shadowOffset = .zero
        shadow.shadowBlurRadius = 36
        shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: alpha)
        shadow.set()
        fill(ellipse(center: center, width: width, height: height), color: NSColor(calibratedWhite: 0.10, alpha: alpha * 0.45))
    }
}

func drawSkateboard(center: CGPoint, boardTilt: CGFloat, wheelSpin: CGFloat, palette: CharacterPalette) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }

    let deckWidth: CGFloat = 560
    let deckHeight: CGFloat = 80
    let sideHeight: CGFloat = 26

    withSavedGraphics {
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: boardTilt)
        context.translateBy(x: -center.x, y: -center.y)

        let sidePath = NSBezierPath()
        sidePath.move(to: CGPoint(x: center.x - deckWidth / 2 + 32, y: center.y - deckHeight / 2))
        sidePath.line(to: CGPoint(x: center.x + deckWidth / 2 - 32, y: center.y - deckHeight / 2))
        sidePath.curve(to: CGPoint(x: center.x + deckWidth / 2 - 6, y: center.y + deckHeight / 2 - 18),
                       controlPoint1: CGPoint(x: center.x + deckWidth / 2 + 12, y: center.y - 8),
                       controlPoint2: CGPoint(x: center.x + deckWidth / 2 + 10, y: center.y + 8))
        sidePath.line(to: CGPoint(x: center.x + deckWidth / 2 - 48, y: center.y - deckHeight / 2 - sideHeight))
        sidePath.line(to: CGPoint(x: center.x - deckWidth / 2 + 48, y: center.y - deckHeight / 2 - sideHeight))
        sidePath.curve(to: CGPoint(x: center.x - deckWidth / 2 + 6, y: center.y + deckHeight / 2 - 18),
                       controlPoint1: CGPoint(x: center.x - deckWidth / 2 - 10, y: center.y + 8),
                       controlPoint2: CGPoint(x: center.x - deckWidth / 2 - 12, y: center.y - 8))
        sidePath.close()
        fill(sidePath, color: NSColor(calibratedRed: 0.72, green: 0.53, blue: 0.27, alpha: 1.0))

        let deckPath = capsule(center: center, width: deckWidth, height: deckHeight)
        fill(deckPath, color: NSColor(calibratedWhite: 0.08, alpha: 1.0))
        stroke(deckPath, color: palette.boardAccent.lightened(0.15), width: 5)

        let stripe = roundedRect(center: CGPoint(x: center.x, y: center.y + 4), width: deckWidth - 120, height: 10, radius: 5)
        fill(stripe, color: palette.boardAccent.withAlphaComponent(0.80))

        for x in [center.x - 150, center.x + 150] {
            fill(roundedRect(center: CGPoint(x: x, y: center.y - 22), width: 48, height: 20, radius: 10),
                 color: NSColor(calibratedWhite: 0.72, alpha: 1.0))

            let axle = NSBezierPath()
            axle.move(to: CGPoint(x: x, y: center.y - 30))
            axle.line(to: CGPoint(x: x, y: center.y - 70))
            stroke(axle, color: NSColor(calibratedWhite: 0.80, alpha: 1.0), width: 8)

            for wheelOffset in [-86.0, 86.0] {
                let wheelCenter = CGPoint(x: x + CGFloat(wheelOffset), y: center.y - 76)
                fill(ellipse(center: wheelCenter, width: 72, height: 72), color: palette.accent.darkened(0.1))
                fill(ellipse(center: wheelCenter, width: 48, height: 48), color: palette.accent.lightened(0.15))

                withSavedGraphics {
                    context.translateBy(x: wheelCenter.x, y: wheelCenter.y)
                    context.rotate(by: wheelSpin)
                    context.translateBy(x: -wheelCenter.x, y: -wheelCenter.y)
                    for spoke in stride(from: 0.0, to: Double.pi * 2.0, by: Double.pi / 2.0) {
                        let spokePath = NSBezierPath()
                        spokePath.move(to: wheelCenter)
                        spokePath.line(to: CGPoint(x: wheelCenter.x + cos(spoke) * 16, y: wheelCenter.y + sin(spoke) * 16))
                        stroke(spokePath, color: NSColor.white.withAlphaComponent(0.75), width: 3)
                    }
                }
                fill(ellipse(center: wheelCenter, width: 14, height: 14), color: .white)
            }
        }
    }
}

func drawSneaker(center: CGPoint, width: CGFloat, height: CGFloat, palette: CharacterPalette, lift: CGFloat) {
    let shoePath = roundedRect(center: CGPoint(x: center.x, y: center.y + lift), width: width, height: height, radius: 24)
    fill(shoePath, color: palette.shoe)
    let toe = ellipse(center: CGPoint(x: center.x + width * 0.16, y: center.y + lift - height * 0.06), width: width * 0.32, height: height * 0.42)
    fill(toe, color: palette.shoe.lightened(0.12))

    let sole = roundedRect(center: CGPoint(x: center.x, y: center.y + lift - height * 0.30), width: width + 12, height: height * 0.28, radius: 14)
    fill(sole, color: palette.sole)
}

func drawPants(waistCenter: CGPoint, legSpread: CGFloat, palette: CharacterPalette, bob: CGFloat) {
    let legWidth: CGFloat = 92
    let legHeight: CGFloat = 420

    for sign in [-1.0, 1.0] {
        let center = CGPoint(x: waistCenter.x + CGFloat(sign) * legSpread, y: waistCenter.y - legHeight / 2 - 28 + bob)
        let path = roundedRect(center: center, width: legWidth, height: legHeight, radius: 34)
        fill(path, color: palette.pants)

        let cuff = roundedRect(center: CGPoint(x: center.x, y: center.y - legHeight / 2 + 36), width: legWidth - 4, height: 42, radius: 14)
        fill(cuff, color: palette.pants.lightened(0.08))
    }

    let seat = roundedRect(center: CGPoint(x: waistCenter.x, y: waistCenter.y + bob), width: 250, height: 140, radius: 44)
    fill(seat, color: palette.pants.lightened(0.02))
}

func drawJacket(center: CGPoint, palette: CharacterPalette, bounce: CGFloat) {
    let torso = roundedRect(center: CGPoint(x: center.x, y: center.y + bounce), width: 340, height: 380, radius: 72)
    fill(torso, color: palette.jacket)

    let hem = roundedRect(center: CGPoint(x: center.x, y: center.y - 170 + bounce), width: 320, height: 60, radius: 22)
    fill(hem, color: palette.jacketShadow)

    let opening = roundedRect(center: CGPoint(x: center.x, y: center.y - 8 + bounce), width: 130, height: 300, radius: 44)
    fill(opening, color: palette.hoodie)

    let sleeveY = center.y + 20 + bounce
    let leftSleeve = roundedRect(center: CGPoint(x: center.x - 210, y: sleeveY), width: 118, height: 310, radius: 48)
    let rightSleeve = roundedRect(center: CGPoint(x: center.x + 210, y: sleeveY), width: 118, height: 310, radius: 48)
    fill(leftSleeve, color: palette.jacket)
    fill(rightSleeve, color: palette.jacket)

    let pocketLeft = roundedRect(center: CGPoint(x: center.x - 82, y: center.y - 80 + bounce), width: 92, height: 92, radius: 20)
    let pocketRight = roundedRect(center: CGPoint(x: center.x + 82, y: center.y - 80 + bounce), width: 92, height: 92, radius: 20)
    fill(pocketLeft, color: palette.jacketShadow.withAlphaComponent(0.45))
    fill(pocketRight, color: palette.jacketShadow.withAlphaComponent(0.45))

    let zipper = NSBezierPath()
    zipper.move(to: CGPoint(x: center.x, y: center.y + 150 + bounce))
    zipper.line(to: CGPoint(x: center.x, y: center.y - 160 + bounce))
    stroke(zipper, color: palette.jacketShadow.darkened(0.1), width: 5)
}

func drawChain(center: CGPoint) {
    let chain = NSBezierPath()
    chain.move(to: CGPoint(x: center.x - 56, y: center.y + 60))
    chain.curve(to: CGPoint(x: center.x + 56, y: center.y + 60),
                controlPoint1: CGPoint(x: center.x - 36, y: center.y + 14),
                controlPoint2: CGPoint(x: center.x + 36, y: center.y + 14))
    stroke(chain, color: NSColor(calibratedRed: 0.99, green: 0.81, blue: 0.30, alpha: 1.0), width: 10)
}

func drawAxolotlHead(center: CGPoint, palette: CharacterPalette, bounce: CGFloat) {
    fill(roundedRect(center: CGPoint(x: center.x, y: center.y + bounce), width: 240, height: 250, radius: 90), color: palette.skin)
    fill(capsule(center: CGPoint(x: center.x, y: center.y + 124 + bounce), width: 188, height: 70), color: palette.shellDark)

    for sign in [-1.0, 1.0] {
        for (index, width) in [92.0, 74.0, 56.0].enumerated() {
            let x = center.x + CGFloat(sign) * (136 + CGFloat(index) * 18)
            let y = center.y + bounce + 42 - CGFloat(index) * 24
            let gill = ellipse(center: CGPoint(x: x, y: y), width: CGFloat(width), height: 42)
            fill(gill, color: palette.shellLight.withAlphaComponent(0.96))
        }
    }

    fill(ellipse(center: CGPoint(x: center.x - 42, y: center.y + 18 + bounce), width: 18, height: 18), color: palette.shellDark)
    fill(ellipse(center: CGPoint(x: center.x + 42, y: center.y + 18 + bounce), width: 18, height: 18), color: palette.shellDark)

    let smile = NSBezierPath()
    smile.move(to: CGPoint(x: center.x - 34, y: center.y - 22 + bounce))
    smile.curve(to: CGPoint(x: center.x + 34, y: center.y - 22 + bounce),
                controlPoint1: CGPoint(x: center.x - 18, y: center.y - 56 + bounce),
                controlPoint2: CGPoint(x: center.x + 18, y: center.y - 56 + bounce))
    stroke(smile, color: palette.shellDark, width: 6)
}

func drawMudbugHead(center: CGPoint, palette: CharacterPalette, bounce: CGFloat) {
    fill(roundedRect(center: CGPoint(x: center.x, y: center.y + bounce), width: 230, height: 240, radius: 88), color: palette.shellLight)
    fill(ellipse(center: CGPoint(x: center.x, y: center.y + 36 + bounce), width: 210, height: 140), color: palette.shellLight.lightened(0.08))

    let crest = roundedRect(center: CGPoint(x: center.x, y: center.y + 124 + bounce), width: 170, height: 54, radius: 24)
    fill(crest, color: palette.shellDark)

    for sign in [-1.0, 1.0] {
        let start = CGPoint(x: center.x + CGFloat(sign) * 28, y: center.y + 104 + bounce)
        let end = CGPoint(x: center.x + CGFloat(sign) * 92, y: center.y + 184 + bounce)
        let antenna = NSBezierPath()
        antenna.move(to: start)
        antenna.curve(to: end,
                      controlPoint1: CGPoint(x: start.x + CGFloat(sign) * 12, y: start.y + 34),
                      controlPoint2: CGPoint(x: end.x - CGFloat(sign) * 18, y: end.y - 18))
        stroke(antenna, color: palette.shellDark, width: 5)
    }

    for sign in [-1.0, 1.0] {
        let eyeStalk = NSBezierPath()
        eyeStalk.move(to: CGPoint(x: center.x + CGFloat(sign) * 30, y: center.y + 66 + bounce))
        eyeStalk.line(to: CGPoint(x: center.x + CGFloat(sign) * 54, y: center.y + 114 + bounce))
        stroke(eyeStalk, color: palette.shellDark, width: 6)
        fill(ellipse(center: CGPoint(x: center.x + CGFloat(sign) * 54, y: center.y + 120 + bounce), width: 18, height: 18), color: palette.shellDark)
    }

    let mouth = NSBezierPath()
    mouth.move(to: CGPoint(x: center.x - 34, y: center.y - 24 + bounce))
    mouth.curve(to: CGPoint(x: center.x + 34, y: center.y - 24 + bounce),
                controlPoint1: CGPoint(x: center.x - 18, y: center.y - 46 + bounce),
                controlPoint2: CGPoint(x: center.x + 18, y: center.y - 46 + bounce))
    stroke(mouth, color: palette.shellDark, width: 5)
}

func drawHandsAndClaws(center: CGPoint, palette: CharacterPalette, bounce: CGFloat) {
    if palette.isAxolotl {
        fill(ellipse(center: CGPoint(x: center.x - 266, y: center.y + bounce - 118), width: 40, height: 86), color: palette.skin)
        fill(ellipse(center: CGPoint(x: center.x + 266, y: center.y + bounce - 118), width: 40, height: 86), color: palette.skin)
        return
    }

    for sign in [-1.0, 1.0] {
        let clawCenter = CGPoint(x: center.x + CGFloat(sign) * 262, y: center.y + bounce - 68)
        let claw = roundedRect(center: clawCenter, width: 94, height: 120, radius: 36)
        fill(claw, color: palette.shellLight)

        let pinchTop = roundedRect(center: CGPoint(x: clawCenter.x + CGFloat(sign) * 24, y: clawCenter.y + 44),
                                   width: 54, height: 66, radius: 26)
        let pinchBottom = roundedRect(center: CGPoint(x: clawCenter.x - CGFloat(sign) * 8, y: clawCenter.y + 8),
                                      width: 52, height: 58, radius: 24)
        fill(pinchTop, color: palette.shellDark)
        fill(pinchBottom, color: palette.shellDark)
    }
}

func drawCharacter(palette: CharacterPalette, time: Double, on canvas: CGSize) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }

    let movement = CGFloat(smoothStep(2.8, 4.2, time) * (1.0 - smoothStep(8.2, 9.8, time) * 0.42))
    let boardCenter = CGPoint(x: canvas.width / 2, y: 362 + sin(time * 3.1) * 2.5)
    let bodyCenter = CGPoint(x: canvas.width / 2, y: 884)
    let bounce = CGFloat(sin(time * .pi * 2.0 * 1.25) * Double(7 + movement * 14))
    let bodyLean = CGFloat((sin(time * .pi * 2.0 * 0.65) * 0.012) + Double(movement) * 0.032 - smoothStep(8.0, 10.0, time) * 0.014)
    let boardTilt = CGFloat(sin(time * .pi * 2.0 * 1.1) * 0.018 + Double(movement) * 0.012)
    let wheelSpin = CGFloat(time * (movement > 0.12 ? 8.4 : 2.4))

    drawShadow(at: CGPoint(x: boardCenter.x, y: boardCenter.y - 122), width: 520, height: 72, alpha: 0.26)
    drawSkateboard(center: boardCenter, boardTilt: boardTilt, wheelSpin: wheelSpin, palette: palette)

    withSavedGraphics {
        context.translateBy(x: canvas.width / 2, y: boardCenter.y + 132)
        context.rotate(by: bodyLean)
        context.translateBy(x: -canvas.width / 2, y: -(boardCenter.y + 132))

        let waistCenter = CGPoint(x: bodyCenter.x, y: bodyCenter.y - 120)
        drawPants(waistCenter: waistCenter, legSpread: 86, palette: palette, bob: bounce)
        drawSneaker(center: CGPoint(x: bodyCenter.x - 118, y: 454), width: 140, height: 82, palette: palette, lift: bounce * 0.3)
        drawSneaker(center: CGPoint(x: bodyCenter.x + 118, y: 454), width: 140, height: 82, palette: palette, lift: -bounce * 0.15)

        let torsoCenter = CGPoint(x: bodyCenter.x, y: bodyCenter.y + 194)
        drawJacket(center: torsoCenter, palette: palette, bounce: bounce)
        drawChain(center: CGPoint(x: bodyCenter.x, y: bodyCenter.y + 276 + bounce))
        drawHandsAndClaws(center: torsoCenter, palette: palette, bounce: bounce)

        if !palette.isAxolotl {
            let shell = roundedRect(center: CGPoint(x: bodyCenter.x, y: bodyCenter.y + 162 + bounce), width: 164, height: 188, radius: 54)
            fill(shell, color: palette.shellDark.withAlphaComponent(0.18))
        }

        let hoodie = roundedRect(center: CGPoint(x: bodyCenter.x, y: bodyCenter.y + 256 + bounce), width: 168, height: 134, radius: 48)
        fill(hoodie, color: palette.hoodie.darkened(0.04))

        if palette.isAxolotl {
            drawAxolotlHead(center: CGPoint(x: bodyCenter.x, y: bodyCenter.y + 546), palette: palette, bounce: bounce)
        } else {
            drawMudbugHead(center: CGPoint(x: bodyCenter.x, y: bodyCenter.y + 548), palette: palette, bounce: bounce)
        }
    }
}

func createBitmap(size: CGSize) -> NSBitmapImageRep? {
    NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )
}

func writePreview(for palette: CharacterPalette) throws {
    guard let rep = createBitmap(size: size) else {
        throw NSError(domain: "preview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create preview bitmap"])
    }

    NSGraphicsContext.saveGraphicsState()
    if let context = NSGraphicsContext(bitmapImageRep: rep) {
        NSGraphicsContext.current = context
        context.cgContext.clear(CGRect(origin: .zero, size: size))
        drawCharacter(palette: palette, time: 5.1, on: size)
    }
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "preview", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode preview PNG"])
    }
    try data.write(to: palette.previewPNG)
}

func pixelBufferPool(size: CGSize) throws -> CVPixelBufferPool {
    let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferWidthKey as String: Int(size.width),
        kCVPixelBufferHeightKey as String: Int(size.height),
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]
    var pool: CVPixelBufferPool?
    let status = CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool)
    guard status == kCVReturnSuccess, let createdPool = pool else {
        throw NSError(domain: "video", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffer pool"])
    }
    return createdPool
}

func renderPixelBuffer(pool: CVPixelBufferPool, palette: CharacterPalette, time: Double) throws -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
    guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
        throw NSError(domain: "video", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffer"])
    }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

    guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
        throw NSError(domain: "video", code: 12, userInfo: [NSLocalizedDescriptionKey: "Missing pixel buffer base address"])
    }

    let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    guard let cgContext = CGContext(
        data: baseAddress,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    ) else {
        throw NSError(domain: "video", code: 13, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGContext"])
    }

    cgContext.clear(CGRect(origin: .zero, size: size))

    NSGraphicsContext.saveGraphicsState()
    let graphics = NSGraphicsContext(cgContext: cgContext, flipped: false)
    NSGraphicsContext.current = graphics
    drawCharacter(palette: palette, time: time, on: size)
    NSGraphicsContext.restoreGraphicsState()

    return buffer
}

func writerSettings(codec: AVVideoCodecType) -> [String: Any] {
    [
        AVVideoCodecKey: codec,
        AVVideoWidthKey: Int(size.width),
        AVVideoHeightKey: Int(size.height)
    ]
}

func encodeMovie(for palette: CharacterPalette, codec: AVVideoCodecType) throws {
    if FileManager.default.fileExists(atPath: palette.outputMovie.path) {
        try FileManager.default.removeItem(at: palette.outputMovie)
    }

    let writer = try AVAssetWriter(outputURL: palette.outputMovie, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: writerSettings(codec: codec))
    input.expectsMediaDataInRealTime = false

    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]
    )

    guard writer.canAdd(input) else {
        throw NSError(domain: "video", code: 14, userInfo: [NSLocalizedDescriptionKey: "Writer cannot add video input"])
    }
    writer.add(input)

    guard writer.startWriting() else {
        throw writer.error ?? NSError(domain: "video", code: 15, userInfo: [NSLocalizedDescriptionKey: "Failed to start writer"])
    }
    writer.startSession(atSourceTime: .zero)

    let pool = try pixelBufferPool(size: size)

    for frame in 0..<frameCount {
        autoreleasepool {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.002)
            }

            let time = Double(frame) / Double(fps)
            do {
                let buffer = try renderPixelBuffer(pool: pool, palette: palette, time: time)
                let presentationTime = CMTime(value: CMTimeValue(frame), timescale: fps)
                if !adaptor.append(buffer, withPresentationTime: presentationTime) {
                    print("append failed for \(palette.name) frame \(frame): \(writer.error?.localizedDescription ?? "unknown error")")
                }
            } catch {
                print("render failed for \(palette.name) frame \(frame): \(error.localizedDescription)")
            }
        }
    }

    input.markAsFinished()

    let semaphore = DispatchSemaphore(value: 0)
    writer.finishWriting {
        semaphore.signal()
    }
    semaphore.wait()

    if writer.status != .completed {
        throw writer.error ?? NSError(domain: "video", code: 16, userInfo: [NSLocalizedDescriptionKey: "Writer finished with status \(writer.status.rawValue)"])
    }
}

func writeMovie(for palette: CharacterPalette) throws {
    let codecs: [AVVideoCodecType] = [
        .hevcWithAlpha,
        .proRes4444,
        AVVideoCodecType(rawValue: "png "),
        AVVideoCodecType(rawValue: "rle ")
    ]
    var lastError: Error?

    for codec in codecs {
        do {
            try encodeMovie(for: palette, codec: codec)
            return
        } catch {
            lastError = error
            try? FileManager.default.removeItem(at: palette.outputMovie)
            print("Codec \(codec.rawValue) failed for \(palette.name): \(error.localizedDescription)")
        }
    }

    throw lastError ?? NSError(domain: "video", code: 17, userInfo: [NSLocalizedDescriptionKey: "No compatible video codec found"])
}

do {
    try FileManager.default.createDirectory(at: repoRoot.appendingPathComponent("scripts", isDirectory: true), withIntermediateDirectories: true)

    for palette in [axo, mudbug] {
        print("Generating preview for \(palette.name)...")
        try writePreview(for: palette)
        print("Generating HEVC loop for \(palette.name)...")
        try writeMovie(for: palette)
    }

    print("Done.")
    print("Preview files:")
    print("  \(axo.previewPNG.path)")
    print("  \(mudbug.previewPNG.path)")
} catch {
    fputs("Generation failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
