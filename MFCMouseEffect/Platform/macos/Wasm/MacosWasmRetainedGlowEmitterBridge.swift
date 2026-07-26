@preconcurrency import AppKit
@preconcurrency import QuartzCore
@preconcurrency import Foundation

@_silgen_name("mfx_macos_overlay_timer_interval_ms_v1")
private func mfxOverlayTimerIntervalMs(_ x: Int32, _ y: Int32) -> Int32

private func mfxWasmUsesScreenBlend(_ blendMode: UInt32) -> Bool {
    return blendMode == 1 || blendMode == 2
}

private func mfxWasmResolveWindowLevel(sortKey: Int32) -> NSWindow.Level {
    let clamped = max(-256, min(256, Int(sortKey)))
    return NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + clamped)
}

private func mfxWasmClipMaskShapeKind(_ rawShapeKind: UInt32) -> UInt32 {
    return rawShapeKind <= 2 ? rawShapeKind : 0
}

private func mfxRetainedGlowApplyClipMask(
    layer: CALayer?,
    frameLeftPx: Int32,
    frameTopPx: Int32,
    squareSizePx: Int32,
    clipLeftPx: CGFloat,
    clipTopPx: CGFloat,
    clipWidthPx: CGFloat,
    clipHeightPx: CGFloat,
    maskShapeKind: UInt32,
    cornerRadiusPx: CGFloat
) {
    guard let layer else {
        return
    }
    guard clipWidthPx > 0.0, clipHeightPx > 0.0 else {
        layer.mask = nil
        return
    }

    let bounds = CGRect(
        x: 0.0,
        y: 0.0,
        width: CGFloat(max(1, squareSizePx)),
        height: CGFloat(max(1, squareSizePx))
    )
    let localClip = CGRect(
        x: clipLeftPx - CGFloat(frameLeftPx),
        y: clipTopPx - CGFloat(frameTopPx),
        width: clipWidthPx,
        height: clipHeightPx
    )
    let clippedRect = bounds.intersection(localClip)
    guard !clippedRect.isNull, clippedRect.width > 0.0, clippedRect.height > 0.0 else {
        let mask = CALayer()
        mask.backgroundColor = NSColor.white.cgColor
        mask.frame = .zero
        layer.mask = mask
        return
    }

    let shapeKind = mfxWasmClipMaskShapeKind(maskShapeKind)
    if shapeKind == 0 {
        let mask = CALayer()
        mask.backgroundColor = NSColor.white.cgColor
        mask.frame = clippedRect
        layer.mask = mask
        return
    }

    let shapeMask = CAShapeLayer()
    shapeMask.fillColor = NSColor.white.cgColor
    shapeMask.frame = clippedRect
    let localBounds = CGRect(origin: .zero, size: clippedRect.size)
    if shapeKind == 2 {
        shapeMask.path = CGPath(ellipseIn: localBounds, transform: nil)
    } else {
        let radius = min(max(0.0, cornerRadiusPx), min(clippedRect.width, clippedRect.height) * 0.5)
        shapeMask.path = CGPath(
            roundedRect: localBounds,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil)
    }
    layer.mask = shapeMask
}

private final class MfxWasmGlowEmitterView: NSView {
    static let particleStyleSoftGlow: UInt32 = 0
    static let particleStyleSolidDisc: UInt32 = 1

    struct Particle {
        var x: CGFloat
        var y: CGFloat
        var radius: CGFloat
        var alpha: CGFloat
        var colorArgb: UInt32
        var life: CGFloat
        var useLegacyFade: Bool
    }

    var particles: [Particle] = []
    var particleStyle: UInt32 = particleStyleSoftGlow

    override var isOpaque: Bool {
        return false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }
        context.clear(bounds)
        for particle in particles {
            let life = max(0.0, min(1.0, particle.life))
            let fadeFactor = particle.useLegacyFade ? pow(life, 0.62) : 1.0
            let alpha = max(0.0, min(1.0, particle.alpha * fadeFactor))
            if alpha <= 0.001 {
                continue
            }

            if particleStyle == Self.particleStyleSolidDisc {
                drawSolidDiscParticle(in: context, particle: particle, alpha: alpha)
            } else {
                drawSoftGlowParticle(in: context, particle: particle, alpha: alpha)
            }
        }
    }

    private static func colorFromArgb(_ argb: UInt32, alphaScale: CGFloat) -> NSColor {
        let baseAlpha = CGFloat(Double((argb >> 24) & 0xFF) / 255.0)
        let alpha = max(0.0, min(1.0, baseAlpha * alphaScale))
        let red = CGFloat(Double((argb >> 16) & 0xFF) / 255.0)
        let green = CGFloat(Double((argb >> 8) & 0xFF) / 255.0)
        let blue = CGFloat(Double(argb & 0xFF) / 255.0)
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    fileprivate static func lerpArgb(_ startArgb: UInt32, _ endArgb: UInt32, t: CGFloat) -> UInt32 {
        func lerpChannel(_ start: UInt32, _ end: UInt32, _ t: CGFloat) -> UInt32 {
            let value = CGFloat(start) + (CGFloat(end) - CGFloat(start)) * t
            return UInt32(max(0.0, min(255.0, value.rounded())))
        }

        let a = lerpChannel((startArgb >> 24) & 0xFF, (endArgb >> 24) & 0xFF, t)
        let r = lerpChannel((startArgb >> 16) & 0xFF, (endArgb >> 16) & 0xFF, t)
        let g = lerpChannel((startArgb >> 8) & 0xFF, (endArgb >> 8) & 0xFF, t)
        let b = lerpChannel(startArgb & 0xFF, endArgb & 0xFF, t)
        return (a << 24) | (r << 16) | (g << 8) | b
    }

    fileprivate static func applyVelocityDrag(_ velocity: CGFloat, dragPerSecond: CGFloat, dtSec: CGFloat) -> CGFloat {
        if dragPerSecond <= 0.0 || dtSec <= 0.0 {
            return velocity
        }
        return velocity * exp(-dragPerSecond * dtSec)
    }

    fileprivate static func particleTurbulence(
        ageSec: CGFloat,
        phaseSeed: CGFloat,
        turbulenceAccel: CGFloat,
        turbulenceFrequencyHz: CGFloat,
        turbulencePhaseJitter: CGFloat
    ) -> CGPoint {
        if turbulenceAccel <= 0.0 || turbulenceFrequencyHz <= 0.0 {
            return .zero
        }
        let tau = CGFloat.pi * 2.0
        let jitter = max(0.0, turbulencePhaseJitter)
        let phase = ageSec * turbulenceFrequencyHz * tau + phaseSeed * max(1.0, jitter) * tau
        let secondaryPhase = phase * 1.6180339 + phaseSeed * 0.5 * tau
        return CGPoint(
            x: turbulenceAccel * sin(phase),
            y: turbulenceAccel * cos(secondaryPhase)
        )
    }

    private func drawSoftGlowParticle(in context: CGContext, particle: Particle, alpha: CGFloat) {
        let baseColor = Self.colorFromArgb(particle.colorArgb, alphaScale: alpha)
        let glowRadius = max(1.0, particle.radius * 2.4)
        let glowRect = CGRect(
            x: particle.x - glowRadius,
            y: particle.y - glowRadius,
            width: glowRadius * 2.0,
            height: glowRadius * 2.0
        )
        context.setFillColor(Self.colorFromArgb(particle.colorArgb, alphaScale: alpha * 0.16).cgColor)
        context.fillEllipse(in: glowRect)

        let midRadius = max(0.8, particle.radius * 1.35)
        let midRect = CGRect(
            x: particle.x - midRadius,
            y: particle.y - midRadius,
            width: midRadius * 2.0,
            height: midRadius * 2.0
        )
        context.setFillColor(Self.colorFromArgb(particle.colorArgb, alphaScale: alpha * 0.34).cgColor)
        context.fillEllipse(in: midRect)

        let coreRect = CGRect(
            x: particle.x - particle.radius,
            y: particle.y - particle.radius,
            width: particle.radius * 2.0,
            height: particle.radius * 2.0
        )
        context.setFillColor(baseColor.cgColor)
        context.fillEllipse(in: coreRect)
    }

    private func drawSolidDiscParticle(in context: CGContext, particle: Particle, alpha: CGFloat) {
        let glowRadius = max(1.0, particle.radius * 1.6)
        let glowRect = CGRect(
            x: particle.x - glowRadius,
            y: particle.y - glowRadius,
            width: glowRadius * 2.0,
            height: glowRadius * 2.0
        )
        context.setFillColor(Self.colorFromArgb(particle.colorArgb, alphaScale: alpha * 0.14).cgColor)
        context.fillEllipse(in: glowRect)

        let coreRect = CGRect(
            x: particle.x - particle.radius,
            y: particle.y - particle.radius,
            width: particle.radius * 2.0,
            height: particle.radius * 2.0
        )
        context.setFillColor(Self.colorFromArgb(particle.colorArgb, alphaScale: alpha).cgColor)
        context.fillEllipse(in: coreRect)
    }
}

@MainActor
private final class MfxWasmRetainedGlowEmitterState: NSObject {
    private struct Config {
        var emissionRatePerSec: CGFloat = 96.0
        var directionRad: CGFloat = 0.0
        var spreadRad: CGFloat = 1.0471976
        var speedMin: CGFloat = 140.0
        var speedMax: CGFloat = 260.0
        var radiusMinPx: CGFloat = 3.0
        var radiusMaxPx: CGFloat = 9.0
        var alphaMin: CGFloat = 0.18
        var alphaMax: CGFloat = 0.90
        var colorArgb: UInt32 = 0xFFFFD54F
        var accelerationX: CGFloat = 0.0
        var accelerationY: CGFloat = 220.0
        var emitterTtlMs: UInt64 = 420
        var particleLifeMs: UInt64 = 900
        var maxParticles: Int = 160
        var particleStyle: UInt32 = 0
        var emissionMode: UInt32 = 0
        var spawnShape: UInt32 = 0
        var spawnRadiusX: CGFloat = 0.0
        var spawnRadiusY: CGFloat = 0.0
        var spawnInnerRatio: CGFloat = 0.0
        var dragPerSecond: CGFloat = 0.0
        var turbulenceAccel: CGFloat = 0.0
        var turbulenceFrequencyHz: CGFloat = 0.0
        var turbulencePhaseJitter: CGFloat = 1.0
        var hasLifeTail: Bool = false
        var sizeStartScale: CGFloat = 1.0
        var sizeEndScale: CGFloat = 1.0
        var alphaStartScale: CGFloat = 1.0
        var alphaEndScale: CGFloat = 1.0
        var colorStartArgb: UInt32 = 0xFFFFFFFF
        var colorEndArgb: UInt32 = 0xFFFFFFFF
        var blendMode: UInt32 = 0
        var sortKey: Int32 = 0
        var groupId: UInt32 = 0
        var clipLeftPx: CGFloat = 0.0
        var clipTopPx: CGFloat = 0.0
        var clipWidthPx: CGFloat = 0.0
        var clipHeightPx: CGFloat = 0.0
        var clipMaskShapeKind: UInt32 = 0
        var clipCornerRadiusPx: CGFloat = 0.0
    }

    private struct Particle {
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var baseRadius: CGFloat
        var baseAlpha: CGFloat
        var colorArgb: UInt32
        var phaseSeed: CGFloat
        var ageSec: CGFloat
        var lifeSec: CGFloat
    }

    private var window: NSWindow?
    private var view: MfxWasmGlowEmitterView?
    private var timer: DispatchSourceTimer?
    private var timerIntervalMs: Int = 16
    private var frameLeftPx: Int32 = 0
    private var frameTopPx: Int32 = 0
    private var squareSizePx: Int32 = 64
    private var localX: CGFloat = 32.0
    private var localY: CGFloat = 32.0
    private var config = Config()
    private var particles: [Particle] = []
    private var emitAccumulator: CGFloat = 0.0
    private var lastTickMs: UInt64 = 0
    private var emitterExpireTickMs: UInt64 = 0
    private var rngState: UInt32 = 0xC4A91F27
    private var presentationAlphaMultiplier: CGFloat = 1.0
    private var presentationVisible = true
    private var appliedGroupOffsetXPx: CGFloat = 0.0
    private var appliedGroupOffsetYPx: CGFloat = 0.0

    private static func nowMs() -> UInt64 {
        let ms = ProcessInfo.processInfo.systemUptime * 1000.0
        return UInt64(ms.rounded(.down))
    }

    private func nextRandom01() -> CGFloat {
        var x = rngState
        x ^= x << 13
        x ^= x >> 17
        x ^= x << 5
        rngState = x
        return CGFloat(Double(x) / Double(UInt32.max))
    }

    private func random(in range: ClosedRange<CGFloat>) -> CGFloat {
        return range.lowerBound + (range.upperBound - range.lowerBound) * nextRandom01()
    }

    private func resolveTargetFps() -> Int {
        let centerX = frameLeftPx + (squareSizePx / 2)
        let centerY = frameTopPx + (squareSizePx / 2)
        let intervalMs = max(4, min(1000, Int(mfxOverlayTimerIntervalMs(centerX, centerY))))
        return max(1, min(240, Int((1000.0 / Double(intervalMs)).rounded())))
    }

    private func ensureWindowOnMain() {
        let size = CGFloat(max(1, squareSizePx))
        let frame = NSRect(x: Double(frameLeftPx), y: Double(frameTopPx), width: size, height: size)

        if window == nil {
            let createdWindow = NSWindow(
                contentRect: frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            createdWindow.isReleasedWhenClosed = false
            createdWindow.isOpaque = false
            createdWindow.backgroundColor = .clear
            createdWindow.hasShadow = false
            createdWindow.ignoresMouseEvents = true
            createdWindow.collectionBehavior = [.canJoinAllSpaces, .transient]

            let contentView = MfxWasmGlowEmitterView(frame: NSRect(x: 0.0, y: 0.0, width: size, height: size))
            contentView.wantsLayer = true
            createdWindow.contentView = contentView
            window = createdWindow
            view = contentView
            createdWindow.orderFrontRegardless()
        } else {
            window?.setFrame(frame, display: false)
            view?.frame = NSRect(x: 0.0, y: 0.0, width: size, height: size)
        }

        window?.level = mfxWasmResolveWindowLevel(sortKey: config.sortKey)
        view?.particleStyle = config.particleStyle
        if mfxWasmUsesScreenBlend(config.blendMode) {
            view?.layer?.compositingFilter = "screenBlendMode"
        } else {
            view?.layer?.compositingFilter = nil
        }
        mfxRetainedGlowApplyClipMask(
            layer: view?.layer,
            frameLeftPx: frameLeftPx,
            frameTopPx: frameTopPx,
            squareSizePx: squareSizePx,
            clipLeftPx: config.clipLeftPx,
            clipTopPx: config.clipTopPx,
            clipWidthPx: config.clipWidthPx,
            clipHeightPx: config.clipHeightPx,
            maskShapeKind: config.clipMaskShapeKind,
            cornerRadiusPx: config.clipCornerRadiusPx
        )
        window?.alphaValue = presentationAlphaMultiplier
        if presentationVisible {
            window?.orderFrontRegardless()
        } else {
            window?.orderOut(nil)
        }
    }

    private func stopTimerOnMain() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    private func ensureTimerOnMain() {
        if timer != nil {
            return
        }
        timerIntervalMs = max(4, min(1000, Int((1000.0 / Double(resolveTargetFps())).rounded())))
        let source = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        source.schedule(deadline: .now(), repeating: .milliseconds(timerIntervalMs))
        source.setEventHandler { [weak self] in
            guard let self else {
                return
            }
            MainActor.assumeIsolated {
                self.tickOnMain()
            }
        }
        timer = source
        source.resume()
    }

    private func spawnParticle() {
        var spawnOffsetX: CGFloat = 0.0
        var spawnOffsetY: CGFloat = 0.0
        if config.spawnShape == 1 || config.spawnShape == 2 {
            let spawnAngle = random(in: 0.0...(CGFloat.pi * 2.0))
            let innerRatio = config.spawnShape == 2 ? max(0.0, min(0.98, config.spawnInnerRatio)) : 0.0
            let minRadiusSq = innerRatio * innerRatio
            let radialScale = sqrt(minRadiusSq + (1.0 - minRadiusSq) * nextRandom01())
            spawnOffsetX = cos(spawnAngle) * config.spawnRadiusX * radialScale
            spawnOffsetY = sin(spawnAngle) * config.spawnRadiusY * radialScale
        }

        let halfSpread = config.spreadRad * 0.5
        var angle = config.directionRad + random(in: (-halfSpread)...halfSpread)
        if config.emissionMode == 1 && (abs(spawnOffsetX) > 0.001 || abs(spawnOffsetY) > 0.001) {
            angle = atan2(spawnOffsetY, spawnOffsetX) + random(in: (-halfSpread)...halfSpread)
        }
        let speed = random(in: config.speedMin...config.speedMax)
        let radius = random(in: config.radiusMinPx...config.radiusMaxPx)
        let alpha = random(in: config.alphaMin...config.alphaMax)
        let particle = Particle(
            x: localX + spawnOffsetX,
            y: localY + spawnOffsetY,
            vx: cos(angle) * speed,
            vy: sin(angle) * speed,
            baseRadius: radius,
            baseAlpha: alpha,
            colorArgb: config.colorArgb,
            phaseSeed: nextRandom01(),
            ageSec: 0.0,
            lifeSec: max(0.06, CGFloat(Double(config.particleLifeMs) / 1000.0))
        )
        particles.append(particle)
    }

    private func updateParticles(dtSec: CGFloat, nowMs: UInt64) {
        if nowMs < emitterExpireTickMs {
            emitAccumulator += config.emissionRatePerSec * dtSec
            var emitCount = Int(floor(emitAccumulator))
            emitAccumulator -= CGFloat(emitCount)
            if particles.count >= config.maxParticles {
                emitCount = 0
            }
            let available = max(0, config.maxParticles - particles.count)
            emitCount = min(emitCount, available)
            if emitCount > 0 {
                particles.reserveCapacity(particles.count + emitCount)
                for _ in 0..<emitCount {
                    spawnParticle()
                }
            }
        }

        guard !particles.isEmpty else {
            return
        }

        var updated: [Particle] = []
        updated.reserveCapacity(particles.count)
        for var particle in particles {
            let turbulence = MfxWasmGlowEmitterView.particleTurbulence(
                ageSec: particle.ageSec,
                phaseSeed: particle.phaseSeed,
                turbulenceAccel: config.turbulenceAccel,
                turbulenceFrequencyHz: config.turbulenceFrequencyHz,
                turbulencePhaseJitter: config.turbulencePhaseJitter
            )
            let totalAx = config.accelerationX + turbulence.x
            let totalAy = config.accelerationY + turbulence.y
            particle.x += particle.vx * dtSec + 0.5 * totalAx * dtSec * dtSec
            particle.y += particle.vy * dtSec + 0.5 * totalAy * dtSec * dtSec
            particle.vx += totalAx * dtSec
            particle.vy += totalAy * dtSec
            particle.vx = MfxWasmGlowEmitterView.applyVelocityDrag(particle.vx, dragPerSecond: config.dragPerSecond, dtSec: dtSec)
            particle.vy = MfxWasmGlowEmitterView.applyVelocityDrag(particle.vy, dragPerSecond: config.dragPerSecond, dtSec: dtSec)
            particle.ageSec += dtSec
            if particle.ageSec >= particle.lifeSec {
                continue
            }
            updated.append(particle)
        }
        particles = updated
    }

    private func publishParticlesToView() {
        guard let view else {
            return
        }
        view.particles = particles.map { particle in
            let progress = max(0.0, min(1.0, particle.ageSec / max(0.01, particle.lifeSec)))
            let life = 1.0 - progress
            var radius = particle.baseRadius
            var alpha = particle.baseAlpha
            var colorArgb = particle.colorArgb
            var useLegacyFade = true
            if config.hasLifeTail {
                radius = particle.baseRadius * (config.sizeStartScale + (config.sizeEndScale - config.sizeStartScale) * progress)
                alpha = particle.baseAlpha * (config.alphaStartScale + (config.alphaEndScale - config.alphaStartScale) * progress)
                colorArgb = MfxWasmGlowEmitterView.lerpArgb(config.colorStartArgb, config.colorEndArgb, t: progress)
                useLegacyFade = false
            }
            return MfxWasmGlowEmitterView.Particle(
                x: particle.x,
                y: particle.y,
                radius: radius,
                alpha: alpha,
                colorArgb: colorArgb,
                life: life,
                useLegacyFade: useLegacyFade
            )
        }
        view.needsDisplay = true
    }

    private func closeWindowOnMain() {
        stopTimerOnMain()
        particles.removeAll(keepingCapacity: false)
        emitAccumulator = 0.0
        view?.particles = []
        view?.needsDisplay = true
        window?.orderOut(nil)
        window?.close()
        window = nil
        view = nil
    }

    private func tickOnMain() {
        let nowMs = Self.nowMs()
        if lastTickMs == 0 {
            lastTickMs = nowMs
            publishParticlesToView()
            return
        }
        let deltaMs = max(UInt64(1), min(UInt64(100), nowMs - lastTickMs))
        lastTickMs = nowMs
        updateParticles(dtSec: CGFloat(Double(deltaMs) / 1000.0), nowMs: nowMs)
        if nowMs >= emitterExpireTickMs && particles.isEmpty {
            closeWindowOnMain()
            return
        }
        publishParticlesToView()
    }

    func upsertOnMain(
        frameLeftPx: Int32,
        frameTopPx: Int32,
        squareSizePx: Int32,
        localX: CGFloat,
        localY: CGFloat,
        emissionRatePerSec: CGFloat,
        directionRad: CGFloat,
        spreadRad: CGFloat,
        speedMin: CGFloat,
        speedMax: CGFloat,
        radiusMinPx: CGFloat,
        radiusMaxPx: CGFloat,
        alphaMin: CGFloat,
        alphaMax: CGFloat,
        colorArgb: UInt32,
        accelerationX: CGFloat,
        accelerationY: CGFloat,
        emitterTtlMs: UInt64,
        particleLifeMs: UInt64,
        maxParticles: Int,
        particleStyle: UInt32,
        emissionMode: UInt32,
        spawnShape: UInt32,
        spawnRadiusX: CGFloat,
        spawnRadiusY: CGFloat,
        spawnInnerRatio: CGFloat,
        dragPerSecond: CGFloat,
        turbulenceAccel: CGFloat,
        turbulenceFrequencyHz: CGFloat,
        turbulencePhaseJitter: CGFloat,
        hasLifeTail: Bool,
        sizeStartScale: CGFloat,
        sizeEndScale: CGFloat,
        alphaStartScale: CGFloat,
        alphaEndScale: CGFloat,
        colorStartArgb: UInt32,
        colorEndArgb: UInt32,
        blendMode: UInt32,
        sortKey: Int32,
        groupId: UInt32,
        clipLeftPx: CGFloat,
        clipTopPx: CGFloat,
        clipWidthPx: CGFloat,
        clipHeightPx: CGFloat
    ) {
        let oldLeft = self.frameLeftPx
        let oldTop = self.frameTopPx
        self.frameLeftPx = frameLeftPx
        self.frameTopPx = frameTopPx
        if appliedGroupOffsetXPx != 0.0 || appliedGroupOffsetYPx != 0.0 {
            self.frameLeftPx += Int32(appliedGroupOffsetXPx.rounded())
            self.frameTopPx += Int32(appliedGroupOffsetYPx.rounded())
        }
        self.squareSizePx = max(64, squareSizePx)
        self.localX = localX
        self.localY = localY
        self.config.emissionRatePerSec = max(1.0, emissionRatePerSec)
        self.config.directionRad = directionRad
        self.config.spreadRad = max(0.0, spreadRad)
        self.config.speedMin = max(1.0, speedMin)
        self.config.speedMax = max(self.config.speedMin, speedMax)
        self.config.radiusMinPx = max(0.4, radiusMinPx)
        self.config.radiusMaxPx = max(self.config.radiusMinPx, radiusMaxPx)
        self.config.alphaMin = max(0.01, min(1.0, alphaMin))
        self.config.alphaMax = max(self.config.alphaMin, min(1.0, alphaMax))
        self.config.colorArgb = colorArgb
        self.config.accelerationX = accelerationX
        self.config.accelerationY = accelerationY
        self.config.emitterTtlMs = max(40, emitterTtlMs)
        self.config.particleLifeMs = max(60, particleLifeMs)
        self.config.maxParticles = max(1, maxParticles)
        self.config.particleStyle =
            particleStyle == MfxWasmGlowEmitterView.particleStyleSolidDisc
            ? MfxWasmGlowEmitterView.particleStyleSolidDisc
            : MfxWasmGlowEmitterView.particleStyleSoftGlow
        self.config.emissionMode = emissionMode == 1 ? 1 : 0
        self.config.spawnShape = min(2, spawnShape)
        self.config.spawnRadiusX = max(0.0, min(192.0, spawnRadiusX))
        self.config.spawnRadiusY = max(0.0, min(192.0, spawnRadiusY))
        self.config.spawnInnerRatio = self.config.spawnShape == 2
            ? max(0.0, min(0.98, spawnInnerRatio))
            : 0.0
        self.config.dragPerSecond = max(0.0, min(12.0, dragPerSecond))
        self.config.turbulenceAccel = max(0.0, min(4800.0, turbulenceAccel))
        self.config.turbulenceFrequencyHz = max(0.0, min(24.0, turbulenceFrequencyHz))
        self.config.turbulencePhaseJitter = max(0.0, min(8.0, turbulencePhaseJitter))
        self.config.hasLifeTail = hasLifeTail
        self.config.sizeStartScale = max(0.05, min(6.0, sizeStartScale))
        self.config.sizeEndScale = max(0.05, min(6.0, sizeEndScale))
        self.config.alphaStartScale = max(0.0, min(2.0, alphaStartScale))
        self.config.alphaEndScale = max(0.0, min(2.0, alphaEndScale))
        self.config.colorStartArgb = colorStartArgb
        self.config.colorEndArgb = colorEndArgb
        self.config.blendMode = blendMode
        self.config.sortKey = sortKey
        self.config.groupId = groupId
        self.config.clipLeftPx = clipLeftPx
        self.config.clipTopPx = clipTopPx
        self.config.clipWidthPx = max(0.0, clipWidthPx)
        self.config.clipHeightPx = max(0.0, clipHeightPx)
        self.emitterExpireTickMs = Self.nowMs() + self.config.emitterTtlMs

        let deltaX = CGFloat(oldLeft - frameLeftPx)
        let deltaY = CGFloat(oldTop - frameTopPx)
        if deltaX != 0.0 || deltaY != 0.0 {
            for index in particles.indices {
                particles[index].x += deltaX
                particles[index].y += deltaY
            }
        }

        ensureWindowOnMain()
        ensureTimerOnMain()
        if lastTickMs == 0 {
            lastTickMs = Self.nowMs()
        }
        publishParticlesToView()
    }

    func releaseHandle() {
        closeWindowOnMain()
    }

    func setGroupPresentationOnMain(alphaMultiplier: CGFloat, visible: Bool) {
        presentationAlphaMultiplier = max(0.0, min(1.0, alphaMultiplier))
        presentationVisible = visible
        window?.alphaValue = presentationAlphaMultiplier
        if visible {
            window?.orderFrontRegardless()
        } else {
            window?.orderOut(nil)
        }
    }

    func setEffectiveClipRectOnMain(
        clipLeftPx: CGFloat,
        clipTopPx: CGFloat,
        clipWidthPx: CGFloat,
        clipHeightPx: CGFloat,
        maskShapeKind: UInt32 = 0,
        cornerRadiusPx: CGFloat = 0.0
    ) {
        config.clipLeftPx = clipLeftPx
        config.clipTopPx = clipTopPx
        config.clipWidthPx = max(0.0, clipWidthPx)
        config.clipHeightPx = max(0.0, clipHeightPx)
        config.clipMaskShapeKind = mfxWasmClipMaskShapeKind(maskShapeKind)
        config.clipCornerRadiusPx = max(0.0, cornerRadiusPx)
        publishParticlesToView()
    }

    func setEffectiveLayerOnMain(blendMode: UInt32, sortKey: Int32) {
        config.blendMode = blendMode
        config.sortKey = sortKey
        window?.level = mfxWasmResolveWindowLevel(sortKey: sortKey)
        view?.layer?.compositingFilter = mfxWasmUsesScreenBlend(blendMode) ? "screenBlendMode" : nil
    }

    func setEffectiveTranslationOnMain(offsetXPx: CGFloat, offsetYPx: CGFloat) {
        let deltaX = offsetXPx - appliedGroupOffsetXPx
        let deltaY = offsetYPx - appliedGroupOffsetYPx
        appliedGroupOffsetXPx = offsetXPx
        appliedGroupOffsetYPx = offsetYPx
        if deltaX == 0.0 && deltaY == 0.0 {
            return
        }
        frameLeftPx += Int32(deltaX.rounded())
        frameTopPx += Int32(deltaY.rounded())
        ensureWindowOnMain()
        publishParticlesToView()
    }

    func isActive() -> Bool {
        return window != nil || !particles.isEmpty
    }
}

private func mfxRetainedGlowEmitterState(from handle: UnsafeMutableRawPointer?) -> MfxWasmRetainedGlowEmitterState? {
    let bits = UInt(bitPattern: handle)
    if bits == 0 {
        return nil
    }
    guard let ptr = UnsafeMutableRawPointer(bitPattern: bits) else {
        return nil
    }
    return Unmanaged<MfxWasmRetainedGlowEmitterState>.fromOpaque(ptr).takeUnretainedValue()
}

@_cdecl("mfx_macos_wasm_retained_glow_emitter_create_v1")
public func mfx_macos_wasm_retained_glow_emitter_create_v1() -> UnsafeMutableRawPointer? {
    if Thread.isMainThread {
        let bits = MainActor.assumeIsolated {
            UInt(bitPattern: Unmanaged.passRetained(MfxWasmRetainedGlowEmitterState()).toOpaque())
        }
        return UnsafeMutableRawPointer(bitPattern: bits)
    }
    var bits: UInt = 0
    DispatchQueue.main.sync {
        bits = MainActor.assumeIsolated {
            UInt(bitPattern: Unmanaged.passRetained(MfxWasmRetainedGlowEmitterState()).toOpaque())
        }
    }
    return UnsafeMutableRawPointer(bitPattern: bits)
}

@_cdecl("mfx_macos_wasm_retained_glow_emitter_release_v1")
public func mfx_macos_wasm_retained_glow_emitter_release_v1(_ handle: UnsafeMutableRawPointer?) {
    let bits = UInt(bitPattern: handle)
    if bits == 0 {
        return
    }
    guard let ptr = UnsafeMutableRawPointer(bitPattern: bits) else {
        return
    }
    let state = Unmanaged<MfxWasmRetainedGlowEmitterState>.fromOpaque(ptr).takeRetainedValue()
    if Thread.isMainThread {
        MainActor.assumeIsolated {
            state.releaseHandle()
        }
        return
    }
    DispatchQueue.main.sync {
        MainActor.assumeIsolated {
            state.releaseHandle()
        }
    }
}

@_cdecl("mfx_macos_wasm_retained_glow_emitter_upsert_v1")
public func mfx_macos_wasm_retained_glow_emitter_upsert_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ frameLeftPx: Int32,
    _ frameTopPx: Int32,
    _ squareSizePx: Int32,
    _ localX: Float,
    _ localY: Float,
    _ emissionRatePerSec: Float,
    _ directionRad: Float,
    _ spreadRad: Float,
    _ speedMin: Float,
    _ speedMax: Float,
    _ radiusMinPx: Float,
    _ radiusMaxPx: Float,
    _ alphaMin: Float,
    _ alphaMax: Float,
    _ colorArgb: UInt32,
    _ accelerationX: Float,
    _ accelerationY: Float,
    _ emitterTtlMs: UInt32,
    _ particleLifeMs: UInt32,
    _ maxParticles: UInt16,
    _ blendMode: UInt32,
    _ sortKey: Int32,
    _ groupId: UInt32,
    _ clipLeftPx: Float,
    _ clipTopPx: Float,
    _ clipWidthPx: Float,
    _ clipHeightPx: Float
) {
    guard let state = mfxRetainedGlowEmitterState(from: handle) else {
        return
    }
    let updateBlock = {
        MainActor.assumeIsolated {
            state.upsertOnMain(
                frameLeftPx: frameLeftPx,
                frameTopPx: frameTopPx,
                squareSizePx: squareSizePx,
                localX: CGFloat(localX),
                localY: CGFloat(localY),
                emissionRatePerSec: CGFloat(emissionRatePerSec),
                directionRad: CGFloat(directionRad),
                spreadRad: CGFloat(spreadRad),
                speedMin: CGFloat(speedMin),
                speedMax: CGFloat(speedMax),
                radiusMinPx: CGFloat(radiusMinPx),
                radiusMaxPx: CGFloat(radiusMaxPx),
                alphaMin: CGFloat(alphaMin),
                alphaMax: CGFloat(alphaMax),
                colorArgb: colorArgb,
                accelerationX: CGFloat(accelerationX),
                accelerationY: CGFloat(accelerationY),
                emitterTtlMs: UInt64(emitterTtlMs),
                particleLifeMs: UInt64(particleLifeMs),
                maxParticles: Int(maxParticles),
                particleStyle: MfxWasmGlowEmitterView.particleStyleSoftGlow,
                emissionMode: 0,
                spawnShape: 0,
                spawnRadiusX: 0.0,
                spawnRadiusY: 0.0,
                spawnInnerRatio: 0.0,
                dragPerSecond: 0.0,
                turbulenceAccel: 0.0,
                turbulenceFrequencyHz: 0.0,
                turbulencePhaseJitter: 1.0,
                hasLifeTail: false,
                sizeStartScale: 1.0,
                sizeEndScale: 1.0,
                alphaStartScale: 1.0,
                alphaEndScale: 1.0,
                colorStartArgb: colorArgb,
                colorEndArgb: colorArgb,
                blendMode: blendMode,
                sortKey: sortKey,
                groupId: groupId,
                clipLeftPx: CGFloat(clipLeftPx),
                clipTopPx: CGFloat(clipTopPx),
                clipWidthPx: CGFloat(clipWidthPx),
                clipHeightPx: CGFloat(clipHeightPx)
            )
        }
    }
    if Thread.isMainThread {
        updateBlock()
    } else {
        DispatchQueue.main.async {
            updateBlock()
        }
    }
}

@_cdecl("mfx_macos_wasm_retained_particle_emitter_create_v1")
public func mfx_macos_wasm_retained_particle_emitter_create_v1() -> UnsafeMutableRawPointer? {
    return mfx_macos_wasm_retained_glow_emitter_create_v1()
}

@_cdecl("mfx_macos_wasm_retained_particle_emitter_release_v1")
public func mfx_macos_wasm_retained_particle_emitter_release_v1(_ handle: UnsafeMutableRawPointer?) {
    mfx_macos_wasm_retained_glow_emitter_release_v1(handle)
}

@_cdecl("mfx_macos_wasm_retained_particle_emitter_upsert_v1")
public func mfx_macos_wasm_retained_particle_emitter_upsert_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ frameLeftPx: Int32,
    _ frameTopPx: Int32,
    _ squareSizePx: Int32,
    _ localX: Float,
    _ localY: Float,
    _ emissionRatePerSec: Float,
    _ directionRad: Float,
    _ spreadRad: Float,
    _ speedMin: Float,
    _ speedMax: Float,
    _ radiusMinPx: Float,
    _ radiusMaxPx: Float,
    _ alphaMin: Float,
    _ alphaMax: Float,
    _ colorArgb: UInt32,
    _ accelerationX: Float,
    _ accelerationY: Float,
    _ emitterTtlMs: UInt32,
    _ particleLifeMs: UInt32,
    _ maxParticles: UInt16,
    _ particleStyle: UInt8,
    _ emissionMode: UInt8,
    _ spawnShape: UInt8,
    _ spawnRadiusX: Float,
    _ spawnRadiusY: Float,
    _ spawnInnerRatio: Float,
    _ dragPerSecond: Float,
    _ turbulenceAccel: Float,
    _ turbulenceFrequencyHz: Float,
    _ turbulencePhaseJitter: Float,
    _ sizeStartScale: Float,
    _ sizeEndScale: Float,
    _ alphaStartScale: Float,
    _ alphaEndScale: Float,
    _ colorStartArgb: UInt32,
    _ colorEndArgb: UInt32,
    _ blendMode: UInt32,
    _ sortKey: Int32,
    _ groupId: UInt32,
    _ clipLeftPx: Float,
    _ clipTopPx: Float,
    _ clipWidthPx: Float,
    _ clipHeightPx: Float
) {
    guard let state = mfxRetainedGlowEmitterState(from: handle) else {
        return
    }
    let updateBlock = {
        MainActor.assumeIsolated {
            state.upsertOnMain(
                frameLeftPx: frameLeftPx,
                frameTopPx: frameTopPx,
                squareSizePx: squareSizePx,
                localX: CGFloat(localX),
                localY: CGFloat(localY),
                emissionRatePerSec: CGFloat(emissionRatePerSec),
                directionRad: CGFloat(directionRad),
                spreadRad: CGFloat(spreadRad),
                speedMin: CGFloat(speedMin),
                speedMax: CGFloat(speedMax),
                radiusMinPx: CGFloat(radiusMinPx),
                radiusMaxPx: CGFloat(radiusMaxPx),
                alphaMin: CGFloat(alphaMin),
                alphaMax: CGFloat(alphaMax),
                colorArgb: colorArgb,
                accelerationX: CGFloat(accelerationX),
                accelerationY: CGFloat(accelerationY),
                emitterTtlMs: UInt64(emitterTtlMs),
                particleLifeMs: UInt64(particleLifeMs),
                maxParticles: Int(maxParticles),
                particleStyle: UInt32(particleStyle),
                emissionMode: UInt32(emissionMode),
                spawnShape: UInt32(spawnShape),
                spawnRadiusX: CGFloat(spawnRadiusX),
                spawnRadiusY: CGFloat(spawnRadiusY),
                spawnInnerRatio: CGFloat(spawnInnerRatio),
                dragPerSecond: CGFloat(dragPerSecond),
                turbulenceAccel: CGFloat(turbulenceAccel),
                turbulenceFrequencyHz: CGFloat(turbulenceFrequencyHz),
                turbulencePhaseJitter: CGFloat(turbulencePhaseJitter),
                hasLifeTail: true,
                sizeStartScale: CGFloat(sizeStartScale),
                sizeEndScale: CGFloat(sizeEndScale),
                alphaStartScale: CGFloat(alphaStartScale),
                alphaEndScale: CGFloat(alphaEndScale),
                colorStartArgb: colorStartArgb,
                colorEndArgb: colorEndArgb,
                blendMode: blendMode,
                sortKey: sortKey,
                groupId: groupId,
                clipLeftPx: CGFloat(clipLeftPx),
                clipTopPx: CGFloat(clipTopPx),
                clipWidthPx: CGFloat(clipWidthPx),
                clipHeightPx: CGFloat(clipHeightPx)
            )
        }
    }
    if Thread.isMainThread {
        updateBlock()
    } else {
        DispatchQueue.main.async {
            updateBlock()
        }
    }
}

@_cdecl("mfx_macos_wasm_retained_particle_emitter_is_active_v1")
public func mfx_macos_wasm_retained_particle_emitter_is_active_v1(_ handle: UnsafeMutableRawPointer?) -> Int32 {
    return mfx_macos_wasm_retained_glow_emitter_is_active_v1(handle)
}

@_cdecl("mfx_macos_wasm_retained_particle_emitter_set_group_presentation_v1")
public func mfx_macos_wasm_retained_particle_emitter_set_group_presentation_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ alphaMultiplier: Float,
    _ visible: UInt32
) {
    mfx_macos_wasm_retained_glow_emitter_set_group_presentation_v1(handle, alphaMultiplier, visible)
}

@_cdecl("mfx_macos_wasm_retained_particle_emitter_set_effective_clip_rect_v1")
public func mfx_macos_wasm_retained_particle_emitter_set_effective_clip_rect_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ clipLeftPx: Float,
    _ clipTopPx: Float,
    _ clipWidthPx: Float,
    _ clipHeightPx: Float
) {
    mfx_macos_wasm_retained_particle_emitter_set_effective_clip_rect_v2(
        handle,
        clipLeftPx,
        clipTopPx,
        clipWidthPx,
        clipHeightPx,
        0,
        0.0)
}

@_cdecl("mfx_macos_wasm_retained_particle_emitter_set_effective_clip_rect_v2")
public func mfx_macos_wasm_retained_particle_emitter_set_effective_clip_rect_v2(
    _ handle: UnsafeMutableRawPointer?,
    _ clipLeftPx: Float,
    _ clipTopPx: Float,
    _ clipWidthPx: Float,
    _ clipHeightPx: Float,
    _ maskShapeKind: UInt32,
    _ cornerRadiusPx: Float
) {
    mfx_macos_wasm_retained_glow_emitter_set_effective_clip_rect_v2(
        handle,
        clipLeftPx,
        clipTopPx,
        clipWidthPx,
        clipHeightPx,
        maskShapeKind,
        cornerRadiusPx)
}

@_cdecl("mfx_macos_wasm_retained_particle_emitter_set_effective_layer_v1")
public func mfx_macos_wasm_retained_particle_emitter_set_effective_layer_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ blendMode: UInt32,
    _ sortKey: Int32
) {
    mfx_macos_wasm_retained_glow_emitter_set_effective_layer_v1(handle, blendMode, sortKey)
}

@_cdecl("mfx_macos_wasm_retained_particle_emitter_set_effective_translation_v1")
public func mfx_macos_wasm_retained_particle_emitter_set_effective_translation_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ offsetXPx: Float,
    _ offsetYPx: Float
) {
    mfx_macos_wasm_retained_glow_emitter_set_effective_translation_v1(handle, offsetXPx, offsetYPx)
}

@_cdecl("mfx_macos_wasm_retained_glow_emitter_set_group_presentation_v1")
public func mfx_macos_wasm_retained_glow_emitter_set_group_presentation_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ alphaMultiplier: Float,
    _ visible: UInt32
) {
    guard let state = mfxRetainedGlowEmitterState(from: handle) else {
        return
    }
    let updateBlock = {
        MainActor.assumeIsolated {
            state.setGroupPresentationOnMain(
                alphaMultiplier: CGFloat(alphaMultiplier),
                visible: visible != 0
            )
        }
    }
    if Thread.isMainThread {
        updateBlock()
    } else {
        DispatchQueue.main.async {
            updateBlock()
        }
    }
}

@_cdecl("mfx_macos_wasm_retained_glow_emitter_set_effective_clip_rect_v1")
public func mfx_macos_wasm_retained_glow_emitter_set_effective_clip_rect_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ clipLeftPx: Float,
    _ clipTopPx: Float,
    _ clipWidthPx: Float,
    _ clipHeightPx: Float
) {
    mfx_macos_wasm_retained_glow_emitter_set_effective_clip_rect_v2(
        handle,
        clipLeftPx,
        clipTopPx,
        clipWidthPx,
        clipHeightPx,
        0,
        0.0)
}

@_cdecl("mfx_macos_wasm_retained_glow_emitter_set_effective_clip_rect_v2")
public func mfx_macos_wasm_retained_glow_emitter_set_effective_clip_rect_v2(
    _ handle: UnsafeMutableRawPointer?,
    _ clipLeftPx: Float,
    _ clipTopPx: Float,
    _ clipWidthPx: Float,
    _ clipHeightPx: Float,
    _ maskShapeKind: UInt32,
    _ cornerRadiusPx: Float
) {
    guard let state = mfxRetainedGlowEmitterState(from: handle) else {
        return
    }
    let updateBlock = {
        MainActor.assumeIsolated {
            state.setEffectiveClipRectOnMain(
                clipLeftPx: CGFloat(clipLeftPx),
                clipTopPx: CGFloat(clipTopPx),
                clipWidthPx: CGFloat(clipWidthPx),
                clipHeightPx: CGFloat(clipHeightPx),
                maskShapeKind: maskShapeKind,
                cornerRadiusPx: CGFloat(cornerRadiusPx)
            )
        }
    }
    if Thread.isMainThread {
        updateBlock()
    } else {
        DispatchQueue.main.async {
            updateBlock()
        }
    }
}

@_cdecl("mfx_macos_wasm_retained_glow_emitter_set_effective_layer_v1")
public func mfx_macos_wasm_retained_glow_emitter_set_effective_layer_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ blendMode: UInt32,
    _ sortKey: Int32
) {
    guard let state = mfxRetainedGlowEmitterState(from: handle) else {
        return
    }
    let updateBlock = {
        MainActor.assumeIsolated {
            state.setEffectiveLayerOnMain(blendMode: blendMode, sortKey: sortKey)
        }
    }
    if Thread.isMainThread {
        updateBlock()
    } else {
        DispatchQueue.main.async {
            updateBlock()
        }
    }
}

@_cdecl("mfx_macos_wasm_retained_glow_emitter_set_effective_translation_v1")
public func mfx_macos_wasm_retained_glow_emitter_set_effective_translation_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ offsetXPx: Float,
    _ offsetYPx: Float
) {
    guard let state = mfxRetainedGlowEmitterState(from: handle) else {
        return
    }
    let updateBlock = {
        MainActor.assumeIsolated {
            state.setEffectiveTranslationOnMain(
                offsetXPx: CGFloat(offsetXPx),
                offsetYPx: CGFloat(offsetYPx)
            )
        }
    }
    if Thread.isMainThread {
        updateBlock()
    } else {
        DispatchQueue.main.async {
            updateBlock()
        }
    }
}

@_cdecl("mfx_macos_wasm_retained_glow_emitter_is_active_v1")
public func mfx_macos_wasm_retained_glow_emitter_is_active_v1(_ handle: UnsafeMutableRawPointer?) -> Int32 {
    guard let state = mfxRetainedGlowEmitterState(from: handle) else {
        return 0
    }
    if Thread.isMainThread {
        return MainActor.assumeIsolated {
            state.isActive() ? 1 : 0
        }
    }
    var active: Int32 = 0
    DispatchQueue.main.sync {
        active = MainActor.assumeIsolated {
            state.isActive() ? 1 : 0
        }
    }
    return active
}
