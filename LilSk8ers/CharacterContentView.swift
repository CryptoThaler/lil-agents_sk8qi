import AppKit

class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class CharacterContentView: NSView {
    weak var character: WalkerCharacter?

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        guard bounds.contains(localPoint) else { return nil }

        // AVPlayerLayer is GPU-rendered so layer.render(in:) won't capture video pixels.
        // Use CGWindowListCreateImage to sample actual on-screen alpha at click point.
        let screenPoint = window?.convertPoint(toScreen: convert(localPoint, to: nil)) ?? .zero
        // Use the full virtual display height for the CG coordinate flip, not just
        // the main screen. NSScreen coordinates have origin at bottom-left of the
        // primary display, while CG uses top-left. The primary screen's height is
        // the correct basis for the flip across all monitors.
        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let flippedY = primaryScreen.frame.height - screenPoint.y

        let captureRect = CGRect(x: screenPoint.x - 0.5, y: flippedY - 0.5, width: 1, height: 1)
        guard let windowID = window?.windowNumber, windowID > 0 else { return nil }

        if let image = CGWindowListCreateImage(
            captureRect,
            .optionIncludingWindow,
            CGWindowID(windowID),
            [.boundsIgnoreFraming, .bestResolution]
        ) {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var pixel: [UInt8] = [0, 0, 0, 0]
            if let ctx = CGContext(
                data: &pixel, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                if pixel[3] > 30 {
                    return self
                }
                return nil
            }
        }

        // Fallback: accept click if within center 60% of the view
        let insetX = bounds.width * 0.2
        let insetY = bounds.height * 0.15
        let hitRect = bounds.insetBy(dx: insetX, dy: insetY)
        return hitRect.contains(localPoint) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        character?.handleClick()
    }
}

final class CharacterAccessoryView: NSView {
    weak var character: WalkerCharacter?

    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let character = character else { return }

        if character.overlayGameMode == .fullGame && character.isPlayerControlled {
            drawSelectionHalo(color: character.skaterIdentity.accentColor)
        }

        switch character.skaterIdentity {
        case .axo:
            drawAxoAccents(buildPulse: character.buildPulse)
        case .mudbug:
            drawMudbugAccents(buildPulse: character.buildPulse)
        }

        if character.overlaySkaterState == .airborne {
            drawAirSpark(color: character.skaterIdentity.accentColor)
        } else if character.overlaySkaterState == .building {
            drawBuildDust(color: character.skaterIdentity.accentColor, intensity: character.buildPulse)
        }
    }

    private func drawSelectionHalo(color: NSColor) {
        let haloRect = bounds.insetBy(dx: bounds.width * 0.24, dy: bounds.height * 0.24).offsetBy(dx: 0, dy: -bounds.height * 0.04)
        let halo = NSBezierPath(ovalIn: haloRect)
        color.withAlphaComponent(0.10).setFill()
        halo.fill()
        halo.lineWidth = 3
        color.withAlphaComponent(0.7).setStroke()
        halo.stroke()
    }

    private func drawAxoAccents(buildPulse: CGFloat) {
        let headRect = CGRect(x: bounds.width * 0.46, y: bounds.height * 0.60, width: bounds.width * 0.22, height: bounds.height * 0.18)
        let skin = NSColor(red: 0.99, green: 0.72, blue: 0.86, alpha: 0.95)
        let gillColor = NSColor(red: 0.92, green: 0.24, blue: 0.42, alpha: 0.9)
        let tailMask = NSColor(red: 0.31, green: 0.78, blue: 0.72, alpha: 0.92)

        let face = NSBezierPath(roundedRect: headRect, xRadius: headRect.width * 0.24, yRadius: headRect.width * 0.24)
        skin.setFill()
        face.fill()

        let pulse = 1 + buildPulse * 0.35
        for side in [-1.0, 1.0] {
            for index in 0..<3 {
                let offsetY = CGFloat(index - 1) * headRect.height * 0.18
                let base = CGPoint(
                    x: side < 0 ? headRect.minX + 2 : headRect.maxX - 2,
                    y: headRect.midY + offsetY
                )
                let petal = NSBezierPath()
                petal.move(to: base)
                petal.curve(
                    to: CGPoint(x: base.x + CGFloat(side) * (headRect.width * 0.18 * pulse), y: base.y + headRect.height * 0.16),
                    controlPoint1: CGPoint(x: base.x + CGFloat(side) * headRect.width * 0.08, y: base.y + headRect.height * 0.08),
                    controlPoint2: CGPoint(x: base.x + CGFloat(side) * headRect.width * 0.14, y: base.y + headRect.height * 0.18)
                )
                petal.curve(
                    to: CGPoint(x: base.x, y: base.y - headRect.height * 0.05),
                    controlPoint1: CGPoint(x: base.x + CGFloat(side) * headRect.width * 0.10, y: base.y + headRect.height * 0.12),
                    controlPoint2: CGPoint(x: base.x + CGFloat(side) * headRect.width * 0.03, y: base.y - headRect.height * 0.02)
                )
                petal.close()
                gillColor.setFill()
                petal.fill()
            }
        }

        let coverRect = CGRect(x: bounds.width * 0.58, y: bounds.height * 0.37, width: bounds.width * 0.13, height: bounds.height * 0.20)
        let cover = NSBezierPath(roundedRect: coverRect, xRadius: 10, yRadius: 10)
        tailMask.setFill()
        cover.fill()
    }

    private func drawMudbugAccents(buildPulse: CGFloat) {
        let bodyMidY = bounds.height * 0.48
        let clawColor = NSColor(red: 0.69, green: 0.14, blue: 0.08, alpha: 0.94)
        let pulse = 1 + buildPulse * 0.25

        for side in [-1.0, 1.0] {
            let center = CGPoint(
                x: side < 0 ? bounds.width * 0.34 : bounds.width * 0.76,
                y: bodyMidY + bounds.height * 0.04
            )
            let claw = NSBezierPath()
            claw.move(to: center)
            claw.curve(
                to: CGPoint(x: center.x + CGFloat(side) * bounds.width * 0.11 * pulse, y: center.y + bounds.height * 0.07),
                controlPoint1: CGPoint(x: center.x + CGFloat(side) * bounds.width * 0.05, y: center.y + bounds.height * 0.07),
                controlPoint2: CGPoint(x: center.x + CGFloat(side) * bounds.width * 0.09, y: center.y + bounds.height * 0.10)
            )
            claw.curve(
                to: CGPoint(x: center.x + CGFloat(side) * bounds.width * 0.05, y: center.y - bounds.height * 0.08),
                controlPoint1: CGPoint(x: center.x + CGFloat(side) * bounds.width * 0.08, y: center.y + bounds.height * 0.03),
                controlPoint2: CGPoint(x: center.x + CGFloat(side) * bounds.width * 0.08, y: center.y - bounds.height * 0.07)
            )
            claw.close()
            clawColor.setFill()
            claw.fill()
        }
    }

    private func drawAirSpark(color: NSColor) {
        let spark = NSBezierPath()
        spark.move(to: CGPoint(x: bounds.width * 0.18, y: bounds.height * 0.76))
        spark.line(to: CGPoint(x: bounds.width * 0.10, y: bounds.height * 0.86))
        spark.move(to: CGPoint(x: bounds.width * 0.22, y: bounds.height * 0.82))
        spark.line(to: CGPoint(x: bounds.width * 0.12, y: bounds.height * 0.92))
        spark.move(to: CGPoint(x: bounds.width * 0.82, y: bounds.height * 0.74))
        spark.line(to: CGPoint(x: bounds.width * 0.90, y: bounds.height * 0.86))
        spark.lineWidth = 2.2
        color.withAlphaComponent(0.72).setStroke()
        spark.stroke()
    }

    private func drawBuildDust(color: NSColor, intensity: CGFloat) {
        guard intensity > 0.05 else { return }
        let dustColor = color.withAlphaComponent(0.18 + intensity * 0.3)
        let dots = [
            CGRect(x: bounds.width * 0.30, y: bounds.height * 0.28, width: 6, height: 6),
            CGRect(x: bounds.width * 0.36, y: bounds.height * 0.25, width: 4, height: 4),
            CGRect(x: bounds.width * 0.70, y: bounds.height * 0.30, width: 5, height: 5)
        ]
        dustColor.setFill()
        dots.forEach { NSBezierPath(ovalIn: $0).fill() }
    }
}
