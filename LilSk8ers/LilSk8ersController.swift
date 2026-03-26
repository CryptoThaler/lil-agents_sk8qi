import AppKit

enum GameMode {
    case normal
    case busyBuild
    case fullGame
}

enum SkaterIdentity: String, CaseIterable {
    case axo
    case mudbug

    var title: String {
        switch self {
        case .axo:
            return "AXO"
        case .mudbug:
            return "Mudbug"
        }
    }

    var accentColor: NSColor {
        switch self {
        case .axo:
            return NSColor(red: 1.0, green: 0.49, blue: 0.78, alpha: 1.0)
        case .mudbug:
            return NSColor(red: 0.97, green: 0.47, blue: 0.23, alpha: 1.0)
        }
    }
}

enum RampCorner: CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var builder: SkaterIdentity {
        switch self {
        case .topLeft, .bottomLeft:
            return .axo
        case .topRight, .bottomRight:
            return .mudbug
        }
    }

    var isTop: Bool {
        switch self {
        case .topLeft, .topRight:
            return true
        case .bottomLeft, .bottomRight:
            return false
        }
    }

    var isLeft: Bool {
        switch self {
        case .topLeft, .bottomLeft:
            return true
        case .topRight, .bottomRight:
            return false
        }
    }

    func frame(in bounds: CGRect) -> CGRect {
        let width = min(180, bounds.width * 0.18)
        let height = width * 0.82
        let horizontalInset = max(28, bounds.width * 0.03)
        let verticalInset = max(24, bounds.height * 0.03)

        let x = isLeft ? horizontalInset : bounds.width - horizontalInset - width
        let y = isTop ? bounds.height - verticalInset - height : verticalInset
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

struct RampPiece {
    let size: CGSize
    let offset: CGPoint
    let rotationDegrees: CGFloat
}

struct RampState {
    let corner: RampCorner
    let builder: SkaterIdentity
    let pieces: [RampPiece]
    var builtPieceCount: Int
    var nextBuildTime: CFTimeInterval
    var restUntil: CFTimeInterval
    var pulse: CGFloat
    var isVisible: Bool

    var isComplete: Bool {
        builtPieceCount >= pieces.count
    }
}

enum SkaterState {
    case roaming
    case building
    case controlled
    case supporting
    case airborne
}

struct PhysicsState {
    var position: CGPoint
    var velocity: CGVector
    var rotationDegrees: CGFloat
    var spinVelocity: CGFloat
    var isAirborne: Bool
    var facingRight: Bool
    var trailIntensity: CGFloat
    var celebrationUntil: CFTimeInterval
    var lastInteractionAt: CFTimeInterval
}

struct HUDState {
    let title: String
    let subtitle: String
    let usageLine: String
    let detailLine: String
    let controlHint: String
    let timeString: String
    let accentColor: NSColor
    let meterFraction: CGFloat
    let isBusy: Bool
}

private struct DockLayout {
    let dockX: CGFloat
    let dockWidth: CGFloat
    let dockTopY: CGFloat
}

private struct OverlayPresentation {
    let mode: GameMode
    let ramps: [RampState]
    let hud: HUDState
    let activeSkater: SkaterIdentity
    let celebrationText: String?
    let celebrationSkater: SkaterIdentity?
}

class LilSk8ersController {
    var characters: [WalkerCharacter] = []
    private var displayLink: CVDisplayLink?
    var debugWindow: NSWindow?
    var pinnedScreenIndex: Int = -1
    private static let onboardingKey = "hasCompletedOnboarding"

    var gameMode: GameMode = .normal
    var buildOverlayEnabled = true
    var fullGameModeEnabled = false

    private var overlayWindow: NSWindow?
    private var overlayView: GameOverlayView?
    private var rampStates: [RampCorner: RampState] = [:]
    private var physicsStates: [SkaterIdentity: PhysicsState] = [:]
    private var activeSkater: SkaterIdentity = .axo
    private var celebrationText: String?
    private var celebrationSkater: SkaterIdentity?
    private var celebrationExpiry: CFTimeInterval = 0
    private var lastTickTime: CFTimeInterval = CACurrentMediaTime()
    private var lastGameScreenFrame: CGRect = .zero

    private static let hudTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    func start() {
        let axo = WalkerCharacter(videoName: "walk-bruce-01")
        axo.skaterIdentity = .axo
        axo.accelStart = 3.0
        axo.fullSpeedStart = 3.75
        axo.decelStart = 8.0
        axo.walkStop = 8.5
        axo.walkAmountRange = 0.4...0.65
        axo.yOffset = -3
        axo.flipXOffset = 0
        axo.positionProgress = 0.28
        axo.characterColor = NSColor(red: 0.98, green: 0.60, blue: 0.82, alpha: 1.0)
        axo.pauseEndTime = CACurrentMediaTime() + Double.random(in: 0.5...2.0)

        let mudbug = WalkerCharacter(videoName: "walk-jazz-01")
        mudbug.skaterIdentity = .mudbug
        mudbug.accelStart = 3.9
        mudbug.fullSpeedStart = 4.5
        mudbug.decelStart = 8.0
        mudbug.walkStop = 8.75
        mudbug.walkAmountRange = 0.35...0.6
        mudbug.yOffset = -7
        mudbug.flipXOffset = -9
        mudbug.positionProgress = 0.72
        mudbug.characterColor = NSColor(red: 0.96, green: 0.48, blue: 0.24, alpha: 1.0)
        mudbug.pauseEndTime = CACurrentMediaTime() + Double.random(in: 8.0...14.0)

        axo.setup()
        mudbug.setup()

        characters = [axo, mudbug]
        characters.forEach { $0.controller = self }

        resetRamps()
        setupDebugLine()
        startDisplayLink()

        if !UserDefaults.standard.bool(forKey: Self.onboardingKey) {
            triggerOnboarding()
        }
    }

    private func triggerOnboarding() {
        guard let axo = characters.first else { return }
        axo.isOnboarding = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            axo.currentPhrase = "hi!"
            axo.showingCompletion = true
            axo.completionBubbleExpiry = CACurrentMediaTime() + 600
            axo.showBubble(text: "hi!", isCompletion: true)
            axo.playCompletionSound()
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        characters.forEach { $0.isOnboarding = false }
    }

    func setBuildOverlayEnabled(_ enabled: Bool) {
        buildOverlayEnabled = enabled
        if !enabled && !fullGameModeEnabled {
            gameMode = .normal
            overlayWindow?.orderOut(nil)
        }
    }

    func setFullGameMode(_ enabled: Bool) {
        guard fullGameModeEnabled != enabled else { return }
        fullGameModeEnabled = enabled

        if enabled {
            characters.forEach { character in
                if character.isIdleForPopover {
                    character.closePopover()
                }
            }

            guard let screen = activeScreen else { return }
            let layout = dockLayout(for: screen)
            resetGamePhysics(for: screen, layout: layout)
            celebrationText = "\(activeSkater.title.uppercased()) DROPS IN"
            celebrationSkater = activeSkater
            celebrationExpiry = CACurrentMediaTime() + 1.1
        } else {
            lastGameScreenFrame = .zero
            celebrationText = nil
            celebrationSkater = nil
            celebrationExpiry = 0
            physicsStates.removeAll()
            characters.forEach { $0.resetForAmbientMode() }
        }
    }

    func resetRamps() {
        let now = CACurrentMediaTime()
        var states: [RampCorner: RampState] = [:]
        for (index, corner) in RampCorner.allCases.enumerated() {
            states[corner] = RampState(
                corner: corner,
                builder: corner.builder,
                pieces: Self.defaultRampPieces(),
                builtPieceCount: 0,
                nextBuildTime: now + 0.35 + Double(index) * 0.18,
                restUntil: now,
                pulse: 0,
                isVisible: false
            )
        }
        rampStates = states
    }

    func openChat(for identity: SkaterIdentity) {
        if fullGameModeEnabled {
            setFullGameMode(false)
        }

        guard let character = character(for: identity) else { return }
        if character.isIdleForPopover {
            character.popoverWindow?.orderFrontRegardless()
        } else {
            character.openPopover()
        }
    }

    func handleCharacterClick(_ character: WalkerCharacter) -> Bool {
        guard fullGameModeEnabled else { return false }
        handleGameClick(for: character.skaterIdentity)
        return true
    }

    // MARK: - Debug

    private func setupDebugLine() {
        let win = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 100, height: 2),
                           styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = NSColor.red
        win.hasShadow = false
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 10)
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.orderOut(nil)
        debugWindow = win
    }

    private func updateDebugLine(dockX: CGFloat, dockWidth: CGFloat, dockTopY: CGFloat) {
        guard let win = debugWindow, win.isVisible else { return }
        win.setFrame(CGRect(x: dockX, y: dockTopY, width: dockWidth, height: 2), display: true)
    }

    // MARK: - Dock Geometry

    private func getDockIconArea(screenWidth: CGFloat) -> (x: CGFloat, width: CGFloat) {
        let dockDefaults = UserDefaults(suiteName: "com.apple.dock")
        let tileSize = CGFloat(dockDefaults?.double(forKey: "tilesize") ?? 48)
        let slotWidth = tileSize * 1.25

        let persistentApps = dockDefaults?.array(forKey: "persistent-apps")?.count ?? 0
        let persistentOthers = dockDefaults?.array(forKey: "persistent-others")?.count ?? 0
        let showRecents = dockDefaults?.bool(forKey: "show-recents") ?? true
        let recentApps = showRecents ? (dockDefaults?.array(forKey: "recent-apps")?.count ?? 0) : 0
        let totalIcons = persistentApps + persistentOthers + recentApps

        var dividers = 0
        if persistentApps > 0 && (persistentOthers > 0 || recentApps > 0) { dividers += 1 }
        if persistentOthers > 0 && recentApps > 0 { dividers += 1 }
        if showRecents && recentApps > 0 { dividers += 1 }

        let dividerWidth: CGFloat = 12.0
        var dockWidth = slotWidth * CGFloat(totalIcons) + CGFloat(dividers) * dividerWidth
        dockWidth *= 1.1
        let dockX = (screenWidth - dockWidth) / 2.0
        return (dockX, dockWidth)
    }

    private func dockLayout(for screen: NSScreen) -> DockLayout {
        let screenWidth = screen.frame.width
        let dockX: CGFloat
        let dockWidth: CGFloat
        let dockTopY: CGFloat

        if screenHasDock(screen) {
            (dockX, dockWidth) = getDockIconArea(screenWidth: screenWidth)
            dockTopY = screen.visibleFrame.origin.y
        } else {
            let margin: CGFloat = 40.0
            dockX = screen.frame.origin.x + margin
            dockWidth = screenWidth - margin * 2
            dockTopY = screen.frame.origin.y
        }

        return DockLayout(dockX: dockX, dockWidth: dockWidth, dockTopY: dockTopY)
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink = displayLink else { return }

        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            let controller = Unmanaged<LilSk8ersController>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async {
                controller.tick()
            }
            return kCVReturnSuccess
        }

        CVDisplayLinkSetOutputCallback(displayLink, callback,
                                       Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(displayLink)
    }

    var activeScreen: NSScreen? {
        if pinnedScreenIndex >= 0, pinnedScreenIndex < NSScreen.screens.count {
            return NSScreen.screens[pinnedScreenIndex]
        }
        return NSScreen.main
    }

    private func screenHasDock(_ screen: NSScreen) -> Bool {
        screen.visibleFrame.origin.y > screen.frame.origin.y
    }

    func tick() {
        guard let screen = activeScreen else { return }

        let layout = dockLayout(for: screen)
        updateDebugLine(dockX: layout.dockX, dockWidth: layout.dockWidth, dockTopY: layout.dockTopY)

        let now = CACurrentMediaTime()
        let dt = max(1.0 / 120.0, min(now - lastTickTime, 1.0 / 20.0))
        lastTickTime = now

        let visibleCharacters = characters.filter { $0.window.isVisible }
        let anyBusy = characters.contains { $0.claudeSession?.isBusy ?? false }

        if fullGameModeEnabled {
            gameMode = .fullGame
        } else if buildOverlayEnabled && anyBusy {
            gameMode = .busyBuild
        } else {
            gameMode = .normal
        }

        updateRampStates(now: now, dt: dt, isBusy: anyBusy)

        if gameMode == .fullGame {
            if lastGameScreenFrame != screen.frame || physicsStates.isEmpty {
                resetGamePhysics(for: screen, layout: layout)
            }
            updateGamePhysics(now: now, dt: dt, screen: screen, layout: layout)
        } else {
            lastGameScreenFrame = .zero
        }

        let anyWalking = visibleCharacters.contains { $0.isWalking }
        if gameMode != .fullGame {
            for character in visibleCharacters {
                if character.isIdleForPopover { continue }
                if character.isPaused && now >= character.pauseEndTime && anyWalking {
                    character.pauseEndTime = now + Double.random(in: 5.0...10.0)
                }
            }
        }

        for character in visibleCharacters {
            character.overlayGameMode = gameMode
            character.overlaySkaterState = skaterState(for: character.skaterIdentity)
            character.overlayPhysicsState = physicsStates[character.skaterIdentity]
            character.isPlayerControlled = fullGameModeEnabled && activeSkater == character.skaterIdentity
            character.buildPulse = buildPulse(for: character.skaterIdentity)
            character.refreshOverlayArt()
            character.update(dockX: layout.dockX, dockWidth: layout.dockWidth, dockTopY: layout.dockTopY)
        }

        updateOverlayWindow(for: screen)

        if gameMode == .fullGame {
            for (index, character) in visibleCharacters.sorted(by: { self.overlayZSort(lhs: $0, rhs: $1) }).enumerated() {
                character.window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + index)
            }
        } else {
            let sorted = visibleCharacters.sorted { $0.positionProgress < $1.positionProgress }
            for (index, character) in sorted.enumerated() {
                character.window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + index)
            }
        }
    }

    private func overlayZSort(lhs: WalkerCharacter, rhs: WalkerCharacter) -> Bool {
        if lhs.skaterIdentity == activeSkater { return false }
        if rhs.skaterIdentity == activeSkater { return true }
        return lhs.overlayPhysicsState?.position.y ?? 0 < rhs.overlayPhysicsState?.position.y ?? 0
    }

    // MARK: - Overlay State

    private func buildPulse(for identity: SkaterIdentity) -> CGFloat {
        guard gameMode == .busyBuild else { return 0 }
        let sideCorners = RampCorner.allCases.filter { $0.builder == identity }
        let pulses = sideCorners.compactMap { rampStates[$0]?.pulse }
        return pulses.max() ?? 0
    }

    private func updateRampStates(now: CFTimeInterval, dt: CFTimeInterval, isBusy: Bool) {
        for corner in RampCorner.allCases {
            guard var state = rampStates[corner] else { continue }

            switch gameMode {
            case .normal:
                state.isVisible = false
                state.pulse = max(0, state.pulse - CGFloat(dt) * 1.8)

            case .busyBuild:
                state.isVisible = true
                if isBusy && !state.isComplete && now >= state.nextBuildTime {
                    state.builtPieceCount += 1
                    state.pulse = 1
                    state.restUntil = now + Double.random(in: 0.45...0.9)
                    state.nextBuildTime = state.restUntil + Double.random(in: 0.7...1.6)
                } else {
                    state.pulse = max(0, state.pulse - CGFloat(dt) * 1.4)
                }

            case .fullGame:
                state.isVisible = true
                state.builtPieceCount = state.pieces.count
                state.pulse = max(0.1, state.pulse - CGFloat(dt) * 0.6)
            }

            rampStates[corner] = state
        }
    }

    private func updateOverlayWindow(for screen: NSScreen) {
        guard let presentation = overlayPresentation() else {
            overlayWindow?.orderOut(nil)
            return
        }

        let window = ensureOverlayWindow(for: screen)
        if window.frame != screen.frame {
            window.setFrame(screen.frame, display: true)
        }

        overlayView?.presentation = presentation
        window.orderFrontRegardless()
    }

    private func ensureOverlayWindow(for screen: NSScreen) -> NSWindow {
        if let overlayWindow = overlayWindow {
            return overlayWindow
        }

        let win = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let view = GameOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.autoresizingMask = [.width, .height]
        win.contentView = view

        overlayWindow = win
        overlayView = view
        return win
    }

    private func overlayPresentation() -> OverlayPresentation? {
        guard gameMode != .normal else { return nil }
        let hud = makeHUDState()
        let ramps = RampCorner.allCases.compactMap { rampStates[$0] }
        let now = CACurrentMediaTime()
        let text = now < celebrationExpiry ? celebrationText : nil
        let skater = now < celebrationExpiry ? celebrationSkater : nil

        return OverlayPresentation(
            mode: gameMode,
            ramps: ramps,
            hud: hud,
            activeSkater: activeSkater,
            celebrationText: text,
            celebrationSkater: skater
        )
    }

    private func makeHUDState() -> HUDState {
        let source = preferredUsageSource()
        let timeString = Self.hudTimeFormatter.string(from: Date())

        guard let (identity, snapshot) = source else {
            let idleProvider = AgentProvider.current
            return HUDState(
                title: gameMode == .fullGame ? "Lil Sk8ers Free Session" : "Quarter Pipe Build Watch",
                subtitle: "\(idleProvider.badgeTitle) READY • \(activeSkater.title.uppercased())",
                usageLine: "CTX 0% • IO 0 / 0",
                detailLine: "LIVE 0s • RESET 0s • PENDING 0",
                controlHint: gameMode == .fullGame
                    ? "CLICK THE ACTIVE SKATER TO BOOST. CLICK THE OTHER TO SWITCH."
                    : "RAMPS APPEAR ONLY WHILE CLAUDE OR CODEX IS BUSY.",
                timeString: timeString,
                accentColor: idleProvider == .openAICodex ? NSColor.systemBlue : NSColor.systemOrange,
                meterFraction: 0,
                isBusy: false
            )
        }

        let inputTokens = snapshot.isBusy ? snapshot.currentTurnInputTokens : snapshot.lastTurnInputTokens
        let outputTokens = snapshot.isBusy ? snapshot.currentTurnOutputTokens : snapshot.lastTurnOutputTokens
        let liveDuration = snapshot.isBusy ? (snapshot.liveTurnDuration ?? 0) : (snapshot.lastTurnDuration ?? 0)
        let ctxPercent = max(0, min(snapshot.estimatedContextPercent, 1))
        let usageLine = "CTX \(Int((ctxPercent * 100).rounded()))% • IO \(formatTokens(inputTokens)) / \(formatTokens(outputTokens))"
        let detailLine = "LIVE \(formatDuration(liveDuration)) • RESET \(formatDuration(snapshot.sessionAge)) • PENDING \(snapshot.pendingMessages)"
        let accent = snapshot.provider == .openAICodex ? NSColor.systemBlue : identity.accentColor
        let title: String
        switch gameMode {
        case .busyBuild:
            title = snapshot.provider == .openAICodex ? "Codex Build Flow" : "Claude Build Flow"
        case .fullGame:
            title = "\(identity.title) Skate Session"
        case .normal:
            title = "Lil Sk8ers"
        }

        return HUDState(
            title: title,
            subtitle: "\(snapshot.provider.badgeTitle) \(snapshot.isBusy ? "LIVE" : "READY") • \(identity.title.uppercased())",
            usageLine: usageLine,
            detailLine: detailLine,
            controlHint: gameMode == .fullGame
                ? "CLICK THE ACTIVE SKATER TO BOOST. CLICK THE OTHER TO SWITCH."
                : "LEFT RAMPS ARE AXO. RIGHT RAMPS ARE MUDBUG.",
            timeString: timeString,
            accentColor: accent,
            meterFraction: CGFloat(ctxPercent),
            isBusy: snapshot.isBusy
        )
    }

    private func preferredUsageSource() -> (SkaterIdentity, ClaudeSession.UsageSnapshot)? {
        let snapshots = characters.compactMap { character -> (SkaterIdentity, ClaudeSession.UsageSnapshot)? in
            guard let session = character.claudeSession else { return nil }
            return (character.skaterIdentity, session.usageSnapshot)
        }

        if let match = snapshots.first(where: { $0.1.provider == .openAICodex && $0.1.isBusy }) { return match }
        if let match = snapshots.first(where: { $0.1.isBusy }) { return match }
        if let match = snapshots.first(where: { $0.0 == activeSkater && $0.1.provider == .openAICodex }) { return match }
        if let match = snapshots.first(where: { $0.1.provider == .openAICodex }) { return match }
        if let match = snapshots.first(where: { $0.0 == activeSkater }) { return match }
        return snapshots.first
    }

    // MARK: - Game Physics

    private func resetGamePhysics(for screen: NSScreen, layout: DockLayout) {
        let now = CACurrentMediaTime()
        let groundY = layout.dockTopY + 12
        let axoWidth = character(for: .axo)?.displayWidth ?? 112
        let mudbugWidth = character(for: .mudbug)?.displayWidth ?? 112
        let leftX = screen.frame.minX + screen.frame.width * 0.28 - axoWidth / 2
        let rightX = screen.frame.minX + screen.frame.width * 0.64 - mudbugWidth / 2

        physicsStates[.axo] = PhysicsState(
            position: CGPoint(x: leftX, y: groundY),
            velocity: CGVector(dx: 180, dy: 0),
            rotationDegrees: 0,
            spinVelocity: 0,
            isAirborne: false,
            facingRight: true,
            trailIntensity: 0,
            celebrationUntil: 0,
            lastInteractionAt: now
        )

        physicsStates[.mudbug] = PhysicsState(
            position: CGPoint(x: rightX, y: groundY),
            velocity: CGVector(dx: -150, dy: 0),
            rotationDegrees: 0,
            spinVelocity: 0,
            isAirborne: false,
            facingRight: false,
            trailIntensity: 0,
            celebrationUntil: 0,
            lastInteractionAt: now
        )

        lastGameScreenFrame = screen.frame
    }

    private func updateGamePhysics(now: CFTimeInterval, dt: CFTimeInterval, screen: NSScreen, layout: DockLayout) {
        let groundY = layout.dockTopY + 12
        let gravity: CGFloat = 1280

        for identity in SkaterIdentity.allCases {
            guard var state = physicsStates[identity] else { continue }
            let charWidth = character(for: identity)?.displayWidth ?? 112
            let minX = screen.frame.minX + 22
            let maxX = screen.frame.maxX - charWidth - 22
            let launchInset: CGFloat = 32

            if state.isAirborne {
                state.position.x += state.velocity.dx * CGFloat(dt)
                state.position.y += state.velocity.dy * CGFloat(dt)
                state.velocity.dy -= gravity * CGFloat(dt)
                state.rotationDegrees += state.spinVelocity * CGFloat(dt)

                if state.position.y <= groundY {
                    state.position.y = groundY
                    state.isAirborne = false
                    let landed360 = abs(state.rotationDegrees) >= 300
                    state.rotationDegrees = 0
                    state.spinVelocity = 0
                    state.velocity.dy = 0
                    state.trailIntensity = landed360 ? 1 : 0.45
                    state.celebrationUntil = landed360 ? now + 1.2 : 0
                    if landed360 {
                        celebrationText = "\(identity.title.uppercased()) 360"
                        celebrationSkater = identity
                        celebrationExpiry = now + 1.2
                    }
                }
            } else {
                let direction: CGFloat = state.velocity.dx >= 0 ? 1 : -1
                let cruiseSpeed: CGFloat = identity == activeSkater ? 180 : 120
                let decayed = max(cruiseSpeed, abs(state.velocity.dx) - CGFloat(dt) * (identity == activeSkater ? 38 : 52))
                state.velocity.dx = decayed * direction
                state.position.x += state.velocity.dx * CGFloat(dt)
                state.position.y = groundY

                if state.position.x <= minX {
                    state.position.x = minX
                    if abs(state.velocity.dx) >= 190 {
                        launch(&state, from: .bottomLeft, speed: abs(state.velocity.dx), now: now)
                    } else {
                        state.velocity.dx = abs(state.velocity.dx) * 0.9
                    }
                } else if state.position.x >= maxX {
                    state.position.x = maxX
                    if abs(state.velocity.dx) >= 190 {
                        launch(&state, from: .bottomRight, speed: abs(state.velocity.dx), now: now)
                    } else {
                        state.velocity.dx = -abs(state.velocity.dx) * 0.9
                    }
                } else if state.position.x <= minX + launchInset && state.velocity.dx < 0 && abs(state.velocity.dx) >= 220 {
                    launch(&state, from: .bottomLeft, speed: abs(state.velocity.dx), now: now)
                } else if state.position.x >= maxX - launchInset && state.velocity.dx > 0 && abs(state.velocity.dx) >= 220 {
                    launch(&state, from: .bottomRight, speed: abs(state.velocity.dx), now: now)
                }
            }

            state.facingRight = state.velocity.dx >= 0
            state.position.x = max(minX, min(state.position.x, maxX))
            state.trailIntensity = max(0, state.trailIntensity - CGFloat(dt) * 1.15)
            physicsStates[identity] = state
        }
    }

    private func launch(_ state: inout PhysicsState, from corner: RampCorner, speed: CGFloat, now: CFTimeInterval) {
        let direction: CGFloat = corner.isLeft ? 1 : -1
        let launchSpeed = max(170, speed * 0.72)
        let verticalSpeed = min(770, 560 + speed * 0.5)
        let airtime = (2 * verticalSpeed) / 1280
        let totalRotation = 300 + min(120, speed * 0.24)

        state.isAirborne = true
        state.velocity.dx = launchSpeed * direction
        state.velocity.dy = verticalSpeed
        state.rotationDegrees = 0
        state.spinVelocity = (totalRotation / max(airtime, 0.7)) * direction
        state.trailIntensity = 1
        state.celebrationUntil = now + 0.45
    }

    private func handleGameClick(for identity: SkaterIdentity) {
        activeSkater = identity
        let now = CACurrentMediaTime()
        guard var state = physicsStates[identity] else { return }

        if state.isAirborne {
            state.spinVelocity *= 1.08
        } else {
            let direction: CGFloat = state.facingRight ? 1 : -1
            let boosted = min(max(abs(state.velocity.dx), 150) + 72, 430)
            state.velocity.dx = boosted * direction
        }

        state.trailIntensity = 1
        state.lastInteractionAt = now
        physicsStates[identity] = state

        celebrationText = identity == .axo ? "AXO PUSHES HARDER" : "MUDBUG CLAW BOOST"
        celebrationSkater = identity
        celebrationExpiry = now + 0.85
    }

    private func skaterState(for identity: SkaterIdentity) -> SkaterState {
        switch gameMode {
        case .normal:
            return .roaming
        case .busyBuild:
            return .building
        case .fullGame:
            if let physics = physicsStates[identity], physics.isAirborne {
                return .airborne
            }
            return identity == activeSkater ? .controlled : .supporting
        }
    }

    private func character(for identity: SkaterIdentity) -> WalkerCharacter? {
        characters.first { $0.skaterIdentity == identity }
    }

    private func formatTokens(_ value: Int) -> String {
        guard value > 0 else { return "0" }
        if value >= 1_000_000 {
            return String(format: "%.1fm", Double(value) / 1_000_000.0)
        }
        if value >= 1_000 {
            return String(format: "%.1fk", Double(value) / 1_000.0)
        }
        return "\(value)"
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let seconds = max(Int(interval.rounded()), 0)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if minutes < 60 {
            return remainingSeconds == 0 ? "\(minutes)m" : "\(minutes)m\(remainingSeconds)s"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return remainingMinutes == 0 ? "\(hours)h" : "\(hours)h\(remainingMinutes)m"
    }

    deinit {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
}

extension LilSk8ersController {
    fileprivate static func defaultRampPieces() -> [RampPiece] {
        [
            RampPiece(size: CGSize(width: 70, height: 11), offset: CGPoint(x: 10, y: 10), rotationDegrees: 0),
            RampPiece(size: CGSize(width: 11, height: 56), offset: CGPoint(x: 88, y: 16), rotationDegrees: 0),
            RampPiece(size: CGSize(width: 42, height: 10), offset: CGPoint(x: 52, y: 26), rotationDegrees: 20),
            RampPiece(size: CGSize(width: 40, height: 10), offset: CGPoint(x: 28, y: 45), rotationDegrees: 42),
            RampPiece(size: CGSize(width: 30, height: 9), offset: CGPoint(x: 74, y: 72), rotationDegrees: 0)
        ]
    }
}

private final class GameOverlayView: NSView {
    var presentation: OverlayPresentation? {
        didSet { needsDisplay = true }
    }

    override var isOpaque: Bool { false }

    private var graffitiFont: NSFont {
        NSFont(name: "MarkerFelt-Wide", size: 24) ?? .boldSystemFont(ofSize: 24)
    }

    private var graffitiSubFont: NSFont {
        NSFont(name: "MarkerFelt-Thin", size: 13) ?? .systemFont(ofSize: 13, weight: .heavy)
    }

    private var monoFont: NSFont {
        .monospacedSystemFont(ofSize: 11, weight: .semibold)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let presentation = presentation else { return }

        for ramp in presentation.ramps where ramp.isVisible {
            drawRamp(ramp)
        }

        if presentation.mode == .busyBuild {
            for ramp in presentation.ramps where ramp.isVisible {
                drawBuilder(for: ramp)
            }
        }

        drawHUD(presentation.hud, activeSkater: presentation.activeSkater, mode: presentation.mode)

        if let text = presentation.celebrationText {
            drawCelebration(text: text, skater: presentation.celebrationSkater)
        }
    }

    private func drawRamp(_ ramp: RampState) {
        let frame = ramp.corner.frame(in: bounds)
        let shadow = NSBezierPath(ovalIn: frame.insetBy(dx: frame.width * 0.18, dy: frame.height * 0.32).offsetBy(dx: 0, dy: -frame.height * 0.05))
        NSColor.black.withAlphaComponent(0.14).setFill()
        shadow.fill()

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: frame.minX, yBy: frame.minY)
        transform.scaleX(by: frame.width / 112.0, yBy: frame.height / 92.0)
        if !ramp.corner.isLeft {
            transform.translateX(by: 112, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
        }
        if ramp.corner.isTop {
            transform.translateX(by: 0, yBy: 92)
            transform.scaleX(by: 1, yBy: -1)
        }
        transform.concat()

        let wood = NSColor(red: 0.56, green: 0.35, blue: 0.18, alpha: 0.98)
        let woodHighlight = NSColor(red: 0.72, green: 0.47, blue: 0.25, alpha: 0.92)
        let outline = NSColor(red: 0.12, green: 0.10, blue: 0.09, alpha: 0.65)

        for (index, piece) in ramp.pieces.enumerated() {
            let pieceFrame = CGRect(origin: piece.offset, size: piece.size)
            let built = index < ramp.builtPieceCount
            drawPiece(
                frame: pieceFrame,
                rotationDegrees: piece.rotationDegrees,
                fillColor: built ? wood : wood.withAlphaComponent(0.16),
                highlightColor: built ? woodHighlight : woodHighlight.withAlphaComponent(0.10),
                outlineColor: built ? outline : outline.withAlphaComponent(0.18),
                pulse: built ? ramp.pulse : 0
            )
        }

        let line = NSBezierPath()
        line.move(to: CGPoint(x: 8, y: 6))
        line.line(to: CGPoint(x: 102, y: 6))
        line.lineWidth = 2
        NSColor.black.withAlphaComponent(0.16).setStroke()
        line.stroke()

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawPiece(frame: CGRect, rotationDegrees: CGFloat, fillColor: NSColor, highlightColor: NSColor, outlineColor: NSColor, pulse: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: frame.midX, yBy: frame.midY)
        transform.rotate(byDegrees: rotationDegrees)
        transform.translateX(by: -frame.width / 2, yBy: -frame.height / 2)
        transform.concat()

        let rect = CGRect(origin: .zero, size: frame.size)
        let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
        fillColor.setFill()
        path.fill()

        let highlight = NSBezierPath(roundedRect: CGRect(x: 1.5, y: rect.height * 0.58, width: rect.width - 3, height: rect.height * 0.22), xRadius: 2, yRadius: 2)
        highlightColor.withAlphaComponent(0.55 + pulse * 0.15).setFill()
        highlight.fill()

        path.lineWidth = 1.2
        outlineColor.setStroke()
        path.stroke()

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawBuilder(for ramp: RampState) {
        let frame = ramp.corner.frame(in: bounds)
        let pulse = max(ramp.pulse, 0.12)
        let bodySize = CGSize(width: frame.width * 0.27, height: frame.height * 0.48)
        let x = ramp.corner.isLeft ? frame.midX + frame.width * 0.02 : frame.midX - frame.width * 0.30
        let y = ramp.corner.isTop ? frame.minY + frame.height * 0.12 : frame.minY + frame.height * 0.34
        let rect = CGRect(origin: CGPoint(x: x, y: y), size: bodySize)

        NSGraphicsContext.saveGraphicsState()
        let bodyTransform = NSAffineTransform()
        if !ramp.corner.isLeft {
            bodyTransform.translateX(by: rect.midX * 2, yBy: 0)
            bodyTransform.scaleX(by: -1, yBy: 1)
        }
        bodyTransform.concat()

        let hoodie = ramp.builder == .axo
            ? NSColor(red: 0.29, green: 0.78, blue: 0.72, alpha: 0.95)
            : NSColor(red: 0.80, green: 0.56, blue: 0.12, alpha: 0.95)
        let skin = ramp.builder == .axo
            ? NSColor(red: 0.98, green: 0.69, blue: 0.84, alpha: 1.0)
            : NSColor(red: 0.98, green: 0.48, blue: 0.27, alpha: 1.0)

        let bodyRect = CGRect(x: rect.minX + rect.width * 0.17, y: rect.minY, width: rect.width * 0.62, height: rect.height * 0.48)
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 7, yRadius: 7)
        hoodie.setFill()
        bodyPath.fill()

        let headRect = CGRect(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.42, width: rect.width * 0.36, height: rect.height * 0.28)
        let headPath = NSBezierPath(roundedRect: headRect, xRadius: 7, yRadius: 7)
        skin.setFill()
        headPath.fill()

        if ramp.builder == .axo {
            drawAxoGills(around: headRect, intensity: pulse)
        } else {
            drawMudbugClaws(around: bodyRect, intensity: pulse)
        }

        let limbPath = NSBezierPath()
        let swing = CGFloat(sin(CACurrentMediaTime() * 7 + Double(pulse) * 3)) * 4 * pulse
        limbPath.move(to: CGPoint(x: bodyRect.minX + 6, y: bodyRect.maxY - 2))
        limbPath.line(to: CGPoint(x: bodyRect.minX - 6, y: bodyRect.midY + swing))
        limbPath.move(to: CGPoint(x: bodyRect.maxX - 4, y: bodyRect.maxY - 4))
        limbPath.line(to: CGPoint(x: bodyRect.maxX + 10, y: bodyRect.midY - swing))
        limbPath.lineWidth = 4
        skin.setStroke()
        limbPath.stroke()

        let sparks = NSBezierPath()
        sparks.move(to: CGPoint(x: bodyRect.maxX + 14, y: bodyRect.midY + 2))
        sparks.line(to: CGPoint(x: bodyRect.maxX + 22, y: bodyRect.midY + 10))
        sparks.move(to: CGPoint(x: bodyRect.maxX + 10, y: bodyRect.midY - 3))
        sparks.line(to: CGPoint(x: bodyRect.maxX + 20, y: bodyRect.midY - 6))
        sparks.lineWidth = 1.4
        NSColor.white.withAlphaComponent(0.65 * pulse).setStroke()
        sparks.stroke()

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawAxoGills(around headRect: CGRect, intensity: CGFloat) {
        let gillColor = NSColor(red: 0.91, green: 0.29, blue: 0.46, alpha: 0.92)
        for side in [-1.0, 1.0] {
            for index in 0..<3 {
                let y = headRect.midY + CGFloat(index - 1) * 5
                let x = side < 0 ? headRect.minX - 3 : headRect.maxX + 3
                let petal = NSBezierPath()
                petal.move(to: CGPoint(x: x, y: y))
                petal.curve(to: CGPoint(x: x + CGFloat(side) * (7 + intensity * 2), y: y + 5),
                            controlPoint1: CGPoint(x: x + CGFloat(side) * 3, y: y + 2),
                            controlPoint2: CGPoint(x: x + CGFloat(side) * 5, y: y + 5))
                petal.curve(to: CGPoint(x: x, y: y - 2),
                            controlPoint1: CGPoint(x: x + CGFloat(side) * 3, y: y + 4),
                            controlPoint2: CGPoint(x: x + CGFloat(side), y: y - 1))
                petal.close()
                gillColor.setFill()
                petal.fill()
            }
        }
    }

    private func drawMudbugClaws(around bodyRect: CGRect, intensity: CGFloat) {
        let clawColor = NSColor(red: 0.66, green: 0.15, blue: 0.08, alpha: 0.96)
        for side in [-1.0, 1.0] {
            let center = CGPoint(x: side < 0 ? bodyRect.minX - 12 : bodyRect.maxX + 12, y: bodyRect.midY + 3)
            let claw = NSBezierPath()
            claw.move(to: CGPoint(x: center.x, y: center.y))
            claw.curve(to: CGPoint(x: center.x + CGFloat(side) * (14 + intensity * 4), y: center.y + 8),
                       controlPoint1: CGPoint(x: center.x + CGFloat(side) * 4, y: center.y + 7),
                       controlPoint2: CGPoint(x: center.x + CGFloat(side) * 9, y: center.y + 11))
            claw.curve(to: CGPoint(x: center.x + CGFloat(side) * 6, y: center.y - 8),
                       controlPoint1: CGPoint(x: center.x + CGFloat(side) * 11, y: center.y + 2),
                       controlPoint2: CGPoint(x: center.x + CGFloat(side) * 10, y: center.y - 7))
            claw.close()
            clawColor.setFill()
            claw.fill()
        }
    }

    private func drawHUD(_ hud: HUDState, activeSkater: SkaterIdentity, mode: GameMode) {
        let panelWidth = min(bounds.width * 0.44, 520)
        let panelHeight: CGFloat = 112
        let panelRect = CGRect(
            x: bounds.midX - panelWidth / 2,
            y: bounds.height - panelHeight - max(22, bounds.height * 0.035),
            width: panelWidth,
            height: panelHeight
        )

        let bg = NSColor.black.withAlphaComponent(0.70)
        let border = hud.accentColor.withAlphaComponent(0.9)
        let panel = NSBezierPath(roundedRect: panelRect, xRadius: 22, yRadius: 22)
        bg.setFill()
        panel.fill()
        panel.lineWidth = 2
        border.setStroke()
        panel.stroke()

        let sprayRect = CGRect(x: panelRect.minX + 18, y: panelRect.maxY - 38, width: panelRect.width - 36, height: 24)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: graffitiFont,
            .foregroundColor: border
        ]
        (hud.title as NSString).draw(in: sprayRect, withAttributes: titleAttrs)

        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: graffitiSubFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
        ]
        (hud.subtitle as NSString).draw(in: CGRect(x: panelRect.minX + 22, y: panelRect.maxY - 58, width: panelRect.width * 0.5, height: 18), withAttributes: subtitleAttrs)
        (hud.timeString as NSString).draw(in: CGRect(x: panelRect.maxX - 120, y: panelRect.maxY - 56, width: 98, height: 18), withAttributes: subtitleAttrs)

        let monoAttrs: [NSAttributedString.Key: Any] = [
            .font: monoFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.88)
        ]
        (hud.usageLine as NSString).draw(in: CGRect(x: panelRect.minX + 22, y: panelRect.minY + 44, width: panelRect.width - 44, height: 14), withAttributes: monoAttrs)
        (hud.detailLine as NSString).draw(in: CGRect(x: panelRect.minX + 22, y: panelRect.minY + 28, width: panelRect.width - 44, height: 14), withAttributes: monoAttrs)

        let hintColor = mode == .fullGame ? activeSkater.accentColor : NSColor.white.withAlphaComponent(0.75)
        let hintAttrs: [NSAttributedString.Key: Any] = [
            .font: monoFont,
            .foregroundColor: hintColor
        ]
        (hud.controlHint as NSString).draw(in: CGRect(x: panelRect.minX + 22, y: panelRect.minY + 10, width: panelRect.width - 44, height: 14), withAttributes: hintAttrs)

        let barRect = CGRect(x: panelRect.minX + 22, y: panelRect.minY + 64, width: panelRect.width - 44, height: 10)
        let barPath = NSBezierPath(roundedRect: barRect, xRadius: 5, yRadius: 5)
        NSColor.white.withAlphaComponent(0.12).setFill()
        barPath.fill()

        let fillRect = CGRect(x: barRect.minX, y: barRect.minY, width: barRect.width * max(0.02, hud.meterFraction), height: barRect.height)
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 5, yRadius: 5)
        let fillColor: NSColor = hud.meterFraction >= 0.7 ? NSColor.systemOrange : hud.accentColor
        fillColor.withAlphaComponent(hud.isBusy ? 0.95 : 0.6).setFill()
        fillPath.fill()
    }

    private func drawCelebration(text: String, skater: SkaterIdentity?) {
        let width = min(bounds.width * 0.26, 280)
        let rect = CGRect(x: bounds.midX - width / 2, y: bounds.midY + bounds.height * 0.1, width: width, height: 44)
        let path = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
        NSColor.black.withAlphaComponent(0.55).setFill()
        path.fill()

        let color = (skater ?? .axo).accentColor
        path.lineWidth = 2
        color.withAlphaComponent(0.8).setStroke()
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: graffitiSubFont,
            .foregroundColor: color
        ]
        (text as NSString).draw(
            in: CGRect(x: rect.minX + 16, y: rect.minY + 12, width: rect.width - 32, height: 20),
            withAttributes: attrs
        )
    }
}
