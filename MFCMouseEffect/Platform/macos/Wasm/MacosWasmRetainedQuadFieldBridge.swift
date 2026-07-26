@preconcurrency import AppKit
@preconcurrency import QuartzCore
@preconcurrency import Foundation

@_silgen_name("mfx_macos_overlay_timer_interval_ms_v1")
private func mfxOverlayTimerIntervalMs(_ x: Int32, _ y: Int32) -> Int32

private struct MfxRetainedQuadFieldSpriteRecord {
    var localX: Float
    var localY: Float
    var widthPx: Float
    var heightPx: Float
    var alpha: Float
    var rotationRad: Float
    var tintArgb: UInt32
    var applyTint: UInt32
    var srcU0: Float
    var srcV0: Float
    var srcU1: Float
    var srcV1: Float
    var velocityX: Float
    var velocityY: Float
    var accelerationX: Float
    var accelerationY: Float
    var imagePathUtf8: String
}

private let mfxRetainedQuadFieldSpriteBytes = 64

private func mfxQuadFieldClamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    if value < minValue {
        return minValue
    }
    if value > maxValue {
        return maxValue
    }
    return value
}

private func mfxQuadFieldUsesScreenBlend(_ blendMode: UInt32) -> Bool {
    return blendMode == 1 || blendMode == 2
}

private func mfxQuadFieldResolveWindowLevel(sortKey: Int32) -> NSWindow.Level {
    let clamped = max(-256, min(256, Int(sortKey)))
    return NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + clamped)
}

private func mfxWasmClipMaskShapeKind(_ rawShapeKind: UInt32) -> UInt32 {
    return rawShapeKind <= 2 ? rawShapeKind : 0
}

private func mfxQuadFieldColorFromArgb(_ argb: UInt32, alphaScale: CGFloat) -> NSColor {
    let baseAlpha = CGFloat(Double((argb >> 24) & 0xFF) / 255.0)
    let alpha = mfxQuadFieldClamp(baseAlpha * alphaScale, min: 0.0, max: 1.0)
    let red = CGFloat(Double((argb >> 16) & 0xFF) / 255.0)
    let green = CGFloat(Double((argb >> 8) & 0xFF) / 255.0)
    let blue = CGFloat(Double(argb & 0xFF) / 255.0)
    return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

private func mfxQuadFieldCreateTintedImage(_ image: NSImage, tintColor: NSColor) -> NSImage? {
    let size = image.size
    guard size.width > 0.0, size.height > 0.0 else {
        return nil
    }
    let rect = NSRect(origin: .zero, size: size)
    let tinted = NSImage(size: size)
    tinted.lockFocus()
    defer { tinted.unlockFocus() }
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
    tintColor.set()
    rect.fill(using: .sourceAtop)
    return tinted
}

private func mfxQuadFieldApplyClipMask(
    layer: CALayer?,
    frameLeftPx: Int32,
    frameTopPx: Int32,
    squareSizePx: Int32,
    clipLeftPx: Float,
    clipTopPx: Float,
    clipWidthPx: Float,
    clipHeightPx: Float,
    maskShapeKind: UInt32,
    cornerRadiusPx: Float
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
        x: CGFloat(clipLeftPx) - CGFloat(frameLeftPx),
        y: CGFloat(clipTopPx) - CGFloat(frameTopPx),
        width: CGFloat(clipWidthPx),
        height: CGFloat(clipHeightPx)
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
        let radius = min(max(0.0, CGFloat(cornerRadiusPx)), min(clippedRect.width, clippedRect.height) * 0.5)
        shapeMask.path = CGPath(
            roundedRect: localBounds,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil)
    }
    layer.mask = shapeMask
}

private func mfxQuadFieldLoadSprites(
    _ spriteBytes: UnsafeRawPointer,
    _ spriteCount: Int,
    _ imagePathUtf8: UnsafePointer<UnsafePointer<CChar>?>?
) -> [MfxRetainedQuadFieldSpriteRecord] {
    guard spriteCount > 0 else {
        return []
    }
    var sprites: [MfxRetainedQuadFieldSpriteRecord] = []
    sprites.reserveCapacity(spriteCount)
    for index in 0..<spriteCount {
        let base = spriteBytes.advanced(by: index * mfxRetainedQuadFieldSpriteBytes)
        let pathUtf8: String
        if let imagePathUtf8 {
            let ptr = imagePathUtf8[index]
            pathUtf8 = ptr.map { String(cString: $0) } ?? ""
        } else {
            pathUtf8 = ""
        }
        sprites.append(MfxRetainedQuadFieldSpriteRecord(
            localX: base.load(fromByteOffset: 0, as: Float.self),
            localY: base.load(fromByteOffset: 4, as: Float.self),
            widthPx: base.load(fromByteOffset: 8, as: Float.self),
            heightPx: base.load(fromByteOffset: 12, as: Float.self),
            alpha: base.load(fromByteOffset: 16, as: Float.self),
            rotationRad: base.load(fromByteOffset: 20, as: Float.self),
            tintArgb: base.load(fromByteOffset: 24, as: UInt32.self),
            applyTint: base.load(fromByteOffset: 28, as: UInt32.self),
            srcU0: base.load(fromByteOffset: 32, as: Float.self),
            srcV0: base.load(fromByteOffset: 36, as: Float.self),
            srcU1: base.load(fromByteOffset: 40, as: Float.self),
            srcV1: base.load(fromByteOffset: 44, as: Float.self),
            velocityX: base.load(fromByteOffset: 48, as: Float.self),
            velocityY: base.load(fromByteOffset: 52, as: Float.self),
            accelerationX: base.load(fromByteOffset: 56, as: Float.self),
            accelerationY: base.load(fromByteOffset: 60, as: Float.self),
            imagePathUtf8: pathUtf8
        ))
    }
    return sprites
}

private final class MfxWasmRetainedQuadFieldView: NSView {
    struct Sprite {
        var x: CGFloat
        var y: CGFloat
        var widthPx: CGFloat
        var heightPx: CGFloat
        var alpha: CGFloat
        var rotationRad: CGFloat
        var tintArgb: UInt32
        var applyTint: Bool
        var srcU0: CGFloat
        var srcV0: CGFloat
        var srcU1: CGFloat
        var srcV1: CGFloat
        var imagePathUtf8: String
    }

    var sprites: [Sprite] = []
    var imageCache: [String: NSImage] = [:]
    var tintedCache: [String: NSImage] = [:]

    override var isOpaque: Bool {
        return false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }
        context.clear(bounds)
        for sprite in sprites {
            if sprite.alpha <= 0.001 || sprite.widthPx <= 0.5 || sprite.heightPx <= 0.5 {
                continue
            }

            let drawRect = CGRect(
                x: sprite.x - sprite.widthPx * 0.5,
                y: sprite.y - sprite.heightPx * 0.5,
                width: sprite.widthPx,
                height: sprite.heightPx
            )

            context.saveGState()
            context.translateBy(x: sprite.x, y: sprite.y)
            if abs(sprite.rotationRad) > 0.001 {
                context.rotate(by: sprite.rotationRad)
            }
            context.translateBy(x: -sprite.x, y: -sprite.y)

            if let image = resolvedImage(
                pathUtf8: sprite.imagePathUtf8,
                tintArgb: sprite.tintArgb,
                applyTint: sprite.applyTint
            ) {
                let minU = mfxQuadFieldClamp(min(sprite.srcU0, sprite.srcU1), min: 0.0, max: 1.0)
                let minV = mfxQuadFieldClamp(min(sprite.srcV0, sprite.srcV1), min: 0.0, max: 1.0)
                let maxU = mfxQuadFieldClamp(max(sprite.srcU0, sprite.srcU1), min: 0.0, max: 1.0)
                let maxV = mfxQuadFieldClamp(max(sprite.srcV0, sprite.srcV1), min: 0.0, max: 1.0)
                let imageSize = image.size
                let sourceRect = NSRect(
                    x: minU * imageSize.width,
                    y: minV * imageSize.height,
                    width: max(1.0, (maxU - minU) * imageSize.width),
                    height: max(1.0, (maxV - minV) * imageSize.height)
                )
                image.draw(in: drawRect, from: sourceRect, operation: .sourceOver, fraction: sprite.alpha)
            } else {
                drawFallback(
                    in: context,
                    rect: drawRect,
                    tintArgb: sprite.tintArgb,
                    alpha: sprite.alpha
                )
            }

            context.restoreGState()
        }
    }

    private func resolvedImage(pathUtf8: String, tintArgb: UInt32, applyTint: Bool) -> NSImage? {
        guard !pathUtf8.isEmpty else {
            return nil
        }
        let baseImage: NSImage
        if let cached = imageCache[pathUtf8] {
            baseImage = cached
        } else {
            guard let loaded = NSImage(contentsOfFile: pathUtf8) else {
                return nil
            }
            imageCache[pathUtf8] = loaded
            baseImage = loaded
        }
        if !applyTint {
            return baseImage
        }
        let tintKey = "\(pathUtf8)#\(tintArgb)"
        if let cached = tintedCache[tintKey] {
            return cached
        }
        let tinted = mfxQuadFieldCreateTintedImage(
            baseImage,
            tintColor: mfxQuadFieldColorFromArgb(tintArgb, alphaScale: 1.0)
        ) ?? baseImage
        tintedCache[tintKey] = tinted
        return tinted
    }

    private func drawFallback(
        in context: CGContext,
        rect: CGRect,
        tintArgb: UInt32,
        alpha: CGFloat
    ) {
        let glowRadius = max(rect.width, rect.height) * 0.65
        let glowRect = CGRect(
            x: rect.midX - glowRadius,
            y: rect.midY - glowRadius,
            width: glowRadius * 2.0,
            height: glowRadius * 2.0
        )
        context.setFillColor(mfxQuadFieldColorFromArgb(tintArgb, alphaScale: alpha * 0.22).cgColor)
        context.fillEllipse(in: glowRect)

        let cornerRadius = min(rect.width, rect.height) * 0.18
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        context.addPath(path)
        context.setFillColor(mfxQuadFieldColorFromArgb(tintArgb, alphaScale: alpha).cgColor)
        context.fillPath()
    }
}

@MainActor
private final class MfxWasmRetainedQuadFieldState: NSObject {
    private var window: NSWindow?
    private var view: MfxWasmRetainedQuadFieldView?
    private var timer: DispatchSourceTimer?
    private var timerIntervalMs: Int = 16
    private var frameLeftPx: Int32 = 0
    private var frameTopPx: Int32 = 0
    private var squareSizePx: Int32 = 64
    private var clipLeftPx: Float = 0.0
    private var clipTopPx: Float = 0.0
    private var clipWidthPx: Float = 0.0
    private var clipHeightPx: Float = 0.0
    private var clipMaskShapeKind: UInt32 = 0
    private var clipCornerRadiusPx: Float = 0.0
    private var sprites: [MfxRetainedQuadFieldSpriteRecord] = []
    private var ttlMs: UInt64 = 640
    private var startTickMs: UInt64 = 0
    private var expireTickMs: UInt64 = 0
    private var active = false
    private var presentationAlphaMultiplier: CGFloat = 1.0
    private var presentationVisible = true
    private var effectiveBlendMode: UInt32 = 0
    private var effectiveSortKey: Int32 = 0
    private var appliedGroupOffsetXPx: CGFloat = 0.0
    private var appliedGroupOffsetYPx: CGFloat = 0.0

    private static func nowMs() -> UInt64 {
        let ms = ProcessInfo.processInfo.systemUptime * 1000.0
        return UInt64(ms.rounded(.down))
    }

    private func resolveTargetFps() -> Int {
        let centerX = frameLeftPx + (squareSizePx / 2)
        let centerY = frameTopPx + (squareSizePx / 2)
        let intervalMs = max(4, min(1000, Int(mfxOverlayTimerIntervalMs(centerX, centerY))))
        return max(1, min(240, Int((1000.0 / Double(intervalMs)).rounded())))
    }

    private func ensureWindowOnMain(blendMode: UInt32, sortKey: Int32) {
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

            let contentView = MfxWasmRetainedQuadFieldView(
                frame: NSRect(x: 0.0, y: 0.0, width: size, height: size)
            )
            contentView.wantsLayer = true
            createdWindow.contentView = contentView
            window = createdWindow
            view = contentView
            createdWindow.orderFrontRegardless()
        } else {
            window?.setFrame(frame, display: false)
            view?.frame = NSRect(x: 0.0, y: 0.0, width: size, height: size)
        }

        window?.level = mfxQuadFieldResolveWindowLevel(sortKey: sortKey)
        if mfxQuadFieldUsesScreenBlend(blendMode) {
            view?.layer?.compositingFilter = "screenBlendMode"
        } else {
            view?.layer?.compositingFilter = nil
        }
        mfxQuadFieldApplyClipMask(
            layer: view?.layer,
            frameLeftPx: frameLeftPx,
            frameTopPx: frameTopPx,
            squareSizePx: squareSizePx,
            clipLeftPx: clipLeftPx,
            clipTopPx: clipTopPx,
            clipWidthPx: clipWidthPx,
            clipHeightPx: clipHeightPx,
            maskShapeKind: clipMaskShapeKind,
            cornerRadiusPx: clipCornerRadiusPx
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

    private func updateViewOnMain(nowMs: UInt64) {
        let elapsedMs = nowMs >= startTickMs ? (nowMs - startTickMs) : 0
        let elapsedSec = CGFloat(Double(elapsedMs) / 1000.0)
        let progress = CGFloat(min(1.0, max(0.0, Double(elapsedMs) / Double(max(UInt64(1), ttlMs)))))
        let fade = mfxQuadFieldClamp(1.0 - progress * progress, min: 0.0, max: 1.0)

        view?.sprites = sprites.compactMap { sprite in
            let widthPx = mfxQuadFieldClamp(CGFloat(sprite.widthPx), min: 2.0, max: 420.0)
            let heightPx = mfxQuadFieldClamp(CGFloat(sprite.heightPx), min: 2.0, max: 420.0)
            let alpha = mfxQuadFieldClamp(CGFloat(sprite.alpha), min: 0.0, max: 1.0) * fade
            if alpha <= 0.001 {
                return nil
            }
            return MfxWasmRetainedQuadFieldView.Sprite(
                x: CGFloat(sprite.localX)
                    + CGFloat(sprite.velocityX) * elapsedSec
                    + 0.5 * CGFloat(sprite.accelerationX) * elapsedSec * elapsedSec,
                y: CGFloat(sprite.localY)
                    + CGFloat(sprite.velocityY) * elapsedSec
                    + 0.5 * CGFloat(sprite.accelerationY) * elapsedSec * elapsedSec,
                widthPx: widthPx,
                heightPx: heightPx,
                alpha: alpha,
                rotationRad: CGFloat(sprite.rotationRad),
                tintArgb: sprite.tintArgb,
                applyTint: sprite.applyTint != 0,
                srcU0: CGFloat(sprite.srcU0),
                srcV0: CGFloat(sprite.srcV0),
                srcU1: CGFloat(sprite.srcU1),
                srcV1: CGFloat(sprite.srcV1),
                imagePathUtf8: sprite.imagePathUtf8
            )
        }
        view?.needsDisplay = true
    }

    private func shutdownOnMain() {
        stopTimerOnMain()
        view?.sprites = []
        view?.needsDisplay = true
        if let window {
            window.orderOut(nil)
            window.close()
        }
        window = nil
        view = nil
        sprites.removeAll(keepingCapacity: false)
        ttlMs = 0
        startTickMs = 0
        expireTickMs = 0
        clipLeftPx = 0.0
        clipTopPx = 0.0
        clipWidthPx = 0.0
        clipHeightPx = 0.0
        active = false
    }

    private func tickOnMain() {
        guard active, window != nil else {
            shutdownOnMain()
            return
        }
        let nowMs = Self.nowMs()
        if nowMs >= expireTickMs {
            shutdownOnMain()
            return
        }
        updateViewOnMain(nowMs: nowMs)
    }

    func upsertOnMain(
        frameLeftPx: Int32,
        frameTopPx: Int32,
        squareSizePx: Int32,
        sprites: [MfxRetainedQuadFieldSpriteRecord],
        ttlMs: UInt32,
        blendMode: UInt32,
        sortKey: Int32,
        groupId: UInt32,
        clipLeftPx: Float,
        clipTopPx: Float,
        clipWidthPx: Float,
        clipHeightPx: Float
    ) {
        guard !sprites.isEmpty else {
            shutdownOnMain()
            return
        }
        _ = groupId
        self.frameLeftPx = frameLeftPx
        self.frameTopPx = frameTopPx
        if appliedGroupOffsetXPx != 0.0 || appliedGroupOffsetYPx != 0.0 {
            self.frameLeftPx += Int32(appliedGroupOffsetXPx.rounded())
            self.frameTopPx += Int32(appliedGroupOffsetYPx.rounded())
        }
        self.squareSizePx = max(1, squareSizePx)
        self.clipLeftPx = clipLeftPx
        self.clipTopPx = clipTopPx
        self.clipWidthPx = clipWidthPx
        self.clipHeightPx = clipHeightPx
        self.sprites = sprites
        self.ttlMs = UInt64(max(40, min(10_000, Int(ttlMs))))
        self.startTickMs = Self.nowMs()
        self.expireTickMs = startTickMs + self.ttlMs
        self.active = true
        self.effectiveBlendMode = blendMode
        self.effectiveSortKey = sortKey

        ensureWindowOnMain(blendMode: blendMode, sortKey: sortKey)
        updateViewOnMain(nowMs: startTickMs)
        ensureTimerOnMain()
    }

    func releaseOnMain() {
        shutdownOnMain()
    }

    func setGroupPresentationOnMain(alphaMultiplier: CGFloat, visible: Bool) {
        presentationAlphaMultiplier = mfxQuadFieldClamp(alphaMultiplier, min: 0.0, max: 1.0)
        presentationVisible = visible
        window?.alphaValue = presentationAlphaMultiplier
        if visible {
            window?.orderFrontRegardless()
        } else {
            window?.orderOut(nil)
        }
    }

    func setEffectiveClipRectOnMain(
        clipLeftPx: Float,
        clipTopPx: Float,
        clipWidthPx: Float,
        clipHeightPx: Float,
        maskShapeKind: UInt32 = 0,
        cornerRadiusPx: Float = 0.0
    ) {
        self.clipLeftPx = clipLeftPx
        self.clipTopPx = clipTopPx
        self.clipWidthPx = max(0.0, clipWidthPx)
        self.clipHeightPx = max(0.0, clipHeightPx)
        self.clipMaskShapeKind = mfxWasmClipMaskShapeKind(maskShapeKind)
        self.clipCornerRadiusPx = max(0.0, cornerRadiusPx)
        updateViewOnMain(nowMs: Self.nowMs())
    }

    func setEffectiveLayerOnMain(blendMode: UInt32, sortKey: Int32) {
        effectiveBlendMode = blendMode
        effectiveSortKey = sortKey
        window?.level = mfxQuadFieldResolveWindowLevel(sortKey: sortKey)
        view?.layer?.compositingFilter = mfxQuadFieldUsesScreenBlend(blendMode) ? "screenBlendMode" : nil
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
        ensureWindowOnMain(blendMode: effectiveBlendMode, sortKey: effectiveSortKey)
        updateViewOnMain(nowMs: Self.nowMs())
    }

    func isActive() -> Bool {
        return active && window != nil && Self.nowMs() < expireTickMs
    }
}

private func mfxRetainedQuadFieldState(from handle: UnsafeMutableRawPointer?) -> MfxWasmRetainedQuadFieldState? {
    let bits = UInt(bitPattern: handle)
    if bits == 0 {
        return nil
    }
    guard let ptr = UnsafeMutableRawPointer(bitPattern: bits) else {
        return nil
    }
    return Unmanaged<MfxWasmRetainedQuadFieldState>.fromOpaque(ptr).takeUnretainedValue()
}

@_cdecl("mfx_macos_wasm_retained_quad_field_create_v1")
public func mfx_macos_wasm_retained_quad_field_create_v1() -> UnsafeMutableRawPointer? {
    if Thread.isMainThread {
        let bits = MainActor.assumeIsolated {
            UInt(bitPattern: Unmanaged.passRetained(MfxWasmRetainedQuadFieldState()).toOpaque())
        }
        return UnsafeMutableRawPointer(bitPattern: bits)
    }
    var bits: UInt = 0
    DispatchQueue.main.sync {
        bits = MainActor.assumeIsolated {
            UInt(bitPattern: Unmanaged.passRetained(MfxWasmRetainedQuadFieldState()).toOpaque())
        }
    }
    return UnsafeMutableRawPointer(bitPattern: bits)
}

@_cdecl("mfx_macos_wasm_retained_quad_field_release_v1")
public func mfx_macos_wasm_retained_quad_field_release_v1(_ handle: UnsafeMutableRawPointer?) {
    let bits = UInt(bitPattern: handle)
    if bits == 0 {
        return
    }
    guard let ptr = UnsafeMutableRawPointer(bitPattern: bits) else {
        return
    }
    let state = Unmanaged<MfxWasmRetainedQuadFieldState>.fromOpaque(ptr).takeRetainedValue()
    let releaseBlock = {
        MainActor.assumeIsolated {
            state.releaseOnMain()
        }
    }
    if Thread.isMainThread {
        releaseBlock()
    } else {
        DispatchQueue.main.sync(execute: releaseBlock)
    }
}

@_cdecl("mfx_macos_wasm_retained_quad_field_upsert_v1")
public func mfx_macos_wasm_retained_quad_field_upsert_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ frameLeftPx: Int32,
    _ frameTopPx: Int32,
    _ squareSizePx: Int32,
    _ spriteBytes: UnsafeRawPointer?,
    _ spriteCount: UInt32,
    _ imagePathUtf8: UnsafePointer<UnsafePointer<CChar>?>?,
    _ ttlMs: UInt32,
    _ blendMode: UInt32,
    _ sortKey: Int32,
    _ groupId: UInt32,
    _ clipLeftPx: Float,
    _ clipTopPx: Float,
    _ clipWidthPx: Float,
    _ clipHeightPx: Float
) {
    guard
        let state = mfxRetainedQuadFieldState(from: handle),
        let spriteBytes,
        spriteCount > 0
    else {
        return
    }
    let sprites = mfxQuadFieldLoadSprites(spriteBytes, Int(spriteCount), imagePathUtf8)
    let updateBlock = {
        MainActor.assumeIsolated {
            state.upsertOnMain(
                frameLeftPx: frameLeftPx,
                frameTopPx: frameTopPx,
                squareSizePx: squareSizePx,
                sprites: sprites,
                ttlMs: ttlMs,
                blendMode: blendMode,
                sortKey: sortKey,
                groupId: groupId,
                clipLeftPx: clipLeftPx,
                clipTopPx: clipTopPx,
                clipWidthPx: clipWidthPx,
                clipHeightPx: clipHeightPx
            )
        }
    }
    if Thread.isMainThread {
        updateBlock()
    } else {
        DispatchQueue.main.sync(execute: updateBlock)
    }
}

@_cdecl("mfx_macos_wasm_retained_quad_field_is_active_v1")
public func mfx_macos_wasm_retained_quad_field_is_active_v1(_ handle: UnsafeMutableRawPointer?) -> UInt32 {
    guard let state = mfxRetainedQuadFieldState(from: handle) else {
        return 0
    }
    if Thread.isMainThread {
        return MainActor.assumeIsolated {
            state.isActive() ? 1 : 0
        }
    }
    var active: UInt32 = 0
    DispatchQueue.main.sync {
        active = MainActor.assumeIsolated {
            state.isActive() ? 1 : 0
        }
    }
    return active
}

@_cdecl("mfx_macos_wasm_retained_quad_field_set_group_presentation_v1")
public func mfx_macos_wasm_retained_quad_field_set_group_presentation_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ alphaMultiplier: Float,
    _ visible: UInt32
) {
    guard let state = mfxRetainedQuadFieldState(from: handle) else {
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

@_cdecl("mfx_macos_wasm_retained_quad_field_set_effective_clip_rect_v1")
public func mfx_macos_wasm_retained_quad_field_set_effective_clip_rect_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ clipLeftPx: Float,
    _ clipTopPx: Float,
    _ clipWidthPx: Float,
    _ clipHeightPx: Float
) {
    mfx_macos_wasm_retained_quad_field_set_effective_clip_rect_v2(
        handle,
        clipLeftPx,
        clipTopPx,
        clipWidthPx,
        clipHeightPx,
        0,
        0.0)
}

@_cdecl("mfx_macos_wasm_retained_quad_field_set_effective_clip_rect_v2")
public func mfx_macos_wasm_retained_quad_field_set_effective_clip_rect_v2(
    _ handle: UnsafeMutableRawPointer?,
    _ clipLeftPx: Float,
    _ clipTopPx: Float,
    _ clipWidthPx: Float,
    _ clipHeightPx: Float,
    _ maskShapeKind: UInt32,
    _ cornerRadiusPx: Float
) {
    guard let state = mfxRetainedQuadFieldState(from: handle) else {
        return
    }
    let updateBlock = {
        MainActor.assumeIsolated {
            state.setEffectiveClipRectOnMain(
                clipLeftPx: clipLeftPx,
                clipTopPx: clipTopPx,
                clipWidthPx: clipWidthPx,
                clipHeightPx: clipHeightPx,
                maskShapeKind: maskShapeKind,
                cornerRadiusPx: cornerRadiusPx
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

@_cdecl("mfx_macos_wasm_retained_quad_field_set_effective_layer_v1")
public func mfx_macos_wasm_retained_quad_field_set_effective_layer_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ blendMode: UInt32,
    _ sortKey: Int32
) {
    guard let state = mfxRetainedQuadFieldState(from: handle) else {
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

@_cdecl("mfx_macos_wasm_retained_quad_field_set_effective_translation_v1")
public func mfx_macos_wasm_retained_quad_field_set_effective_translation_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ offsetXPx: Float,
    _ offsetYPx: Float
) {
    guard let state = mfxRetainedQuadFieldState(from: handle) else {
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
