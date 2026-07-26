@preconcurrency import AppKit
@preconcurrency import QuartzCore
@preconcurrency import Foundation

@_silgen_name("mfx_macos_overlay_timer_interval_ms_v1")
private func mfxOverlayTimerIntervalMs(_ x: Int32, _ y: Int32) -> Int32

private let mfxTrailPathNodeBytes = 28

private struct MfxTrailPathNodeRecord {
    var opcode: UInt8
    var x1: Float
    var y1: Float
    var x2: Float
    var y2: Float
    var x3: Float
    var y3: Float
}

private func mfxTrailClamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    if value < minValue { return minValue }
    if value > maxValue { return maxValue }
    return value
}

private func mfxTrailColorFromArgb(_ argb: UInt32, alphaScale: CGFloat) -> NSColor {
    let baseAlpha = CGFloat(Double((argb >> 24) & 0xFF) / 255.0)
    let alpha = mfxTrailClamp(baseAlpha * alphaScale, min: 0.0, max: 1.0)
    let red = CGFloat(Double((argb >> 16) & 0xFF) / 255.0)
    let green = CGFloat(Double((argb >> 8) & 0xFF) / 255.0)
    let blue = CGFloat(Double(argb & 0xFF) / 255.0)
    return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

private func mfxTrailUsesScreenBlend(_ blendMode: UInt32) -> Bool {
    return blendMode == 1 || blendMode == 2
}

private func mfxTrailResolveWindowLevel(sortKey: Int32) -> NSWindow.Level {
    let clamped = max(-256, min(256, Int(sortKey)))
    return NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + clamped)
}

private func mfxWasmClipMaskShapeKind(_ rawShapeKind: UInt32) -> UInt32 {
    return rawShapeKind <= 2 ? rawShapeKind : 0
}

private func mfxTrailApplyClipMask(
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
    guard let layer else { return }
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

private func mfxTrailLoadPathNodes(_ nodesPtr: UnsafeRawPointer, count: Int) -> [MfxTrailPathNodeRecord] {
    guard count > 0 else { return [] }
    var nodes: [MfxTrailPathNodeRecord] = []
    nodes.reserveCapacity(count)
    for index in 0..<count {
        let base = nodesPtr.advanced(by: index * mfxTrailPathNodeBytes)
        nodes.append(MfxTrailPathNodeRecord(
            opcode: base.load(fromByteOffset: 0, as: UInt8.self),
            x1: base.load(fromByteOffset: 4, as: Float.self),
            y1: base.load(fromByteOffset: 8, as: Float.self),
            x2: base.load(fromByteOffset: 12, as: Float.self),
            y2: base.load(fromByteOffset: 16, as: Float.self),
            x3: base.load(fromByteOffset: 20, as: Float.self),
            y3: base.load(fromByteOffset: 24, as: Float.self)
        ))
    }
    return nodes
}

private func mfxTrailBuildPath(nodes: [MfxTrailPathNodeRecord]) -> CGPath? {
    guard !nodes.isEmpty else { return nil }
    let path = CGMutablePath()
    var haveCurrent = false
    var drewAnySegment = false
    for node in nodes {
        switch node.opcode {
        case 0:
            path.move(to: CGPoint(x: CGFloat(node.x1), y: CGFloat(node.y1)))
            haveCurrent = true
        case 1:
            guard haveCurrent else { return nil }
            path.addLine(to: CGPoint(x: CGFloat(node.x1), y: CGFloat(node.y1)))
            drewAnySegment = true
        case 2:
            guard haveCurrent else { return nil }
            path.addQuadCurve(
                to: CGPoint(x: CGFloat(node.x2), y: CGFloat(node.y2)),
                control: CGPoint(x: CGFloat(node.x1), y: CGFloat(node.y1))
            )
            drewAnySegment = true
        case 3:
            guard haveCurrent else { return nil }
            path.addCurve(
                to: CGPoint(x: CGFloat(node.x3), y: CGFloat(node.y3)),
                control1: CGPoint(x: CGFloat(node.x1), y: CGFloat(node.y1)),
                control2: CGPoint(x: CGFloat(node.x2), y: CGFloat(node.y2))
            )
            drewAnySegment = true
        case 4:
            guard haveCurrent else { return nil }
            path.closeSubpath()
        default:
            return nil
        }
    }
    return drewAnySegment ? path : nil
}

@MainActor
private final class MfxWasmRetainedRibbonTrailState: NSObject {
    private var window: NSWindow?
    private var contentView: NSView?
    private var timer: DispatchSourceTimer?
    private var frameLeftPx: Int32 = 0
    private var frameTopPx: Int32 = 0
    private var squareSizePx: Int32 = 64
    private var ttlMs: UInt64 = 640
    private var expireTickMs: UInt64 = 0
    private var alphaScale: CGFloat = 1.0
    private var active = false
    private var clipLeftPx: CGFloat = 0.0
    private var clipTopPx: CGFloat = 0.0
    private var clipWidthPx: CGFloat = 0.0
    private var clipHeightPx: CGFloat = 0.0
    private var clipMaskShapeKind: UInt32 = 0
    private var clipCornerRadiusPx: CGFloat = 0.0
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

    private func destroyOnMain() {
        timer?.cancel()
        timer = nil
        if let window {
            window.orderOut(nil)
            window.close()
        }
        window = nil
        contentView = nil
        active = false
        expireTickMs = 0
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
            let createdContent = NSView(frame: NSRect(x: 0.0, y: 0.0, width: size, height: size))
            createdContent.wantsLayer = true
            createdWindow.contentView = createdContent
            window = createdWindow
            contentView = createdContent
        }
        window?.setFrame(frame, display: true)
        window?.level = mfxTrailResolveWindowLevel(sortKey: sortKey)
        contentView?.frame = NSRect(x: 0.0, y: 0.0, width: size, height: size)
        contentView?.layer?.frame = contentView?.bounds ?? .zero
        contentView?.layer?.compositingFilter = mfxTrailUsesScreenBlend(blendMode) ? "screenBlendMode" : nil
        mfxTrailApplyClipMask(
            layer: contentView?.layer,
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

    private func rebuildLayersOnMain(path: CGPath, glowWidthPx: CGFloat, fillArgb: UInt32, glowArgb: UInt32) {
        guard let contentView else { return }
        contentView.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        for glowPass in 0..<3 {
            let glow = CAShapeLayer()
            glow.frame = contentView.bounds
            glow.path = path
            glow.fillColor = nil
            glow.strokeColor = mfxTrailColorFromArgb(
                glowArgb,
                alphaScale: glowPass == 0 ? 0.30 : (glowPass == 1 ? 0.22 : 0.14)
            ).cgColor
            glow.lineWidth = max(1.0, glowWidthPx + CGFloat(glowPass * 5))
            glow.lineJoin = .round
            glow.lineCap = .round
            contentView.layer?.addSublayer(glow)
        }
        let fill = CAShapeLayer()
        fill.frame = contentView.bounds
        fill.path = path
        fill.fillColor = mfxTrailColorFromArgb(fillArgb, alphaScale: 1.0).cgColor
        contentView.layer?.addSublayer(fill)
    }

    private func ensureTimerOnMain() {
        if timer != nil { return }
        let centerX = frameLeftPx + (squareSizePx / 2)
        let centerY = frameTopPx + (squareSizePx / 2)
        let intervalMs = max(4, min(1000, Int(mfxOverlayTimerIntervalMs(centerX, centerY))))
        let source = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        source.schedule(deadline: .now() + .milliseconds(intervalMs), repeating: .milliseconds(intervalMs))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.tickOnMain()
            }
        }
        source.resume()
        timer = source
    }

    private func tickOnMain() {
        guard active else {
            destroyOnMain()
            return
        }
        let now = Self.nowMs()
        if now >= expireTickMs {
            destroyOnMain()
            return
        }
        let remaining = CGFloat(expireTickMs - now)
        let total = CGFloat(max(UInt64(1), ttlMs))
        let progress = 1.0 - remaining / total
        let opacity = mfxTrailClamp(1.0 - progress * progress, min: 0.0, max: 1.0) * alphaScale
        contentView?.layer?.opacity = Float(opacity)
    }

    func upsertOnMain(
        frameLeftPx: Int32,
        frameTopPx: Int32,
        squareSizePx: Int32,
        nodes: [MfxTrailPathNodeRecord],
        alpha: CGFloat,
        glowWidthPx: CGFloat,
        fillArgb: UInt32,
        glowArgb: UInt32,
        ttlMs: UInt64,
        blendMode: UInt32,
        sortKey: Int32,
        groupId: UInt32,
        clipLeftPx: CGFloat,
        clipTopPx: CGFloat,
        clipWidthPx: CGFloat,
        clipHeightPx: CGFloat
    ) {
        guard let path = mfxTrailBuildPath(nodes: nodes) else {
            destroyOnMain()
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
        self.ttlMs = max(UInt64(40), ttlMs)
        self.expireTickMs = Self.nowMs() + self.ttlMs
        self.alphaScale = mfxTrailClamp(alpha, min: 0.0, max: 1.0)
        self.clipLeftPx = clipLeftPx
        self.clipTopPx = clipTopPx
        self.clipWidthPx = max(0.0, clipWidthPx)
        self.clipHeightPx = max(0.0, clipHeightPx)
        self.effectiveBlendMode = blendMode
        self.effectiveSortKey = sortKey
        self.active = true

        ensureWindowOnMain(blendMode: blendMode, sortKey: sortKey)
        rebuildLayersOnMain(
            path: path,
            glowWidthPx: mfxTrailClamp(glowWidthPx, min: 0.0, max: 64.0),
            fillArgb: fillArgb,
            glowArgb: glowArgb
        )
        ensureTimerOnMain()
        tickOnMain()
    }

    func releaseOnMain() {
        destroyOnMain()
    }

    func setGroupPresentationOnMain(alphaMultiplier: CGFloat, visible: Bool) {
        presentationAlphaMultiplier = mfxTrailClamp(alphaMultiplier, min: 0.0, max: 1.0)
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
        self.clipLeftPx = clipLeftPx
        self.clipTopPx = clipTopPx
        self.clipWidthPx = max(0.0, clipWidthPx)
        self.clipHeightPx = max(0.0, clipHeightPx)
        self.clipMaskShapeKind = mfxWasmClipMaskShapeKind(maskShapeKind)
        self.clipCornerRadiusPx = max(0.0, cornerRadiusPx)
        mfxTrailApplyClipMask(
            layer: contentView?.layer,
            frameLeftPx: frameLeftPx,
            frameTopPx: frameTopPx,
            squareSizePx: squareSizePx,
            clipLeftPx: self.clipLeftPx,
            clipTopPx: self.clipTopPx,
            clipWidthPx: self.clipWidthPx,
            clipHeightPx: self.clipHeightPx,
            maskShapeKind: self.clipMaskShapeKind,
            cornerRadiusPx: self.clipCornerRadiusPx
        )
    }

    func setEffectiveLayerOnMain(blendMode: UInt32, sortKey: Int32) {
        effectiveBlendMode = blendMode
        effectiveSortKey = sortKey
        window?.level = mfxTrailResolveWindowLevel(sortKey: sortKey)
        contentView?.layer?.compositingFilter = mfxTrailUsesScreenBlend(blendMode) ? "screenBlendMode" : nil
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
        tickOnMain()
    }

    func isActive() -> Bool {
        return active && window != nil && Self.nowMs() < expireTickMs
    }
}

private func mfxRetainedRibbonTrailState(from handle: UnsafeMutableRawPointer?) -> MfxWasmRetainedRibbonTrailState? {
    guard let handle else { return nil }
    return Unmanaged<MfxWasmRetainedRibbonTrailState>.fromOpaque(handle).takeUnretainedValue()
}

@_cdecl("mfx_macos_wasm_retained_ribbon_trail_create_v1")
public func mfx_macos_wasm_retained_ribbon_trail_create_v1() -> UnsafeMutableRawPointer? {
    var bits: UInt = 0
    if Thread.isMainThread {
        bits = MainActor.assumeIsolated {
            UInt(bitPattern: Unmanaged.passRetained(MfxWasmRetainedRibbonTrailState()).toOpaque())
        }
    } else {
        DispatchQueue.main.sync {
            bits = MainActor.assumeIsolated {
                UInt(bitPattern: Unmanaged.passRetained(MfxWasmRetainedRibbonTrailState()).toOpaque())
            }
        }
    }
    return UnsafeMutableRawPointer(bitPattern: bits)
}

@_cdecl("mfx_macos_wasm_retained_ribbon_trail_release_v1")
public func mfx_macos_wasm_retained_ribbon_trail_release_v1(_ handle: UnsafeMutableRawPointer?) {
    let bits = UInt(bitPattern: handle)
    if bits == 0 {
        return
    }
    guard let ptr = UnsafeMutableRawPointer(bitPattern: bits) else {
        return
    }
    let state = Unmanaged<MfxWasmRetainedRibbonTrailState>.fromOpaque(ptr).takeRetainedValue()
    if Thread.isMainThread {
        MainActor.assumeIsolated {
            state.releaseOnMain()
        }
        return
    }
    DispatchQueue.main.sync {
        MainActor.assumeIsolated {
            state.releaseOnMain()
        }
    }
}

@_cdecl("mfx_macos_wasm_retained_ribbon_trail_upsert_v1")
public func mfx_macos_wasm_retained_ribbon_trail_upsert_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ frameLeftPx: Int32,
    _ frameTopPx: Int32,
    _ squareSizePx: Int32,
    _ nodesPtr: UnsafeRawPointer?,
    _ nodeCount: UInt32,
    _ alpha: Float,
    _ glowWidthPx: Float,
    _ fillArgb: UInt32,
    _ glowArgb: UInt32,
    _ ttlMs: UInt32,
    _ blendMode: UInt32,
    _ sortKey: Int32,
    _ groupId: UInt32,
    _ clipLeftPx: Float,
    _ clipTopPx: Float,
    _ clipWidthPx: Float,
    _ clipHeightPx: Float
) {
    guard let state = mfxRetainedRibbonTrailState(from: handle),
          let nodesPtr,
          nodeCount > 0 else { return }
    let copiedNodes = mfxTrailLoadPathNodes(nodesPtr, count: Int(nodeCount))
    let updateBlock = {
        MainActor.assumeIsolated {
            state.upsertOnMain(
                frameLeftPx: frameLeftPx,
                frameTopPx: frameTopPx,
                squareSizePx: squareSizePx,
                nodes: copiedNodes,
                alpha: CGFloat(alpha),
                glowWidthPx: CGFloat(glowWidthPx),
                fillArgb: fillArgb,
                glowArgb: glowArgb,
                ttlMs: UInt64(ttlMs),
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

@_cdecl("mfx_macos_wasm_retained_ribbon_trail_is_active_v1")
public func mfx_macos_wasm_retained_ribbon_trail_is_active_v1(_ handle: UnsafeMutableRawPointer?) -> Int32 {
    guard let state = mfxRetainedRibbonTrailState(from: handle) else { return 0 }
    if Thread.isMainThread {
        return MainActor.assumeIsolated { state.isActive() ? 1 : 0 }
    }
    var active: Int32 = 0
    DispatchQueue.main.sync {
        active = MainActor.assumeIsolated { state.isActive() ? 1 : 0 }
    }
    return active
}

@_cdecl("mfx_macos_wasm_retained_ribbon_trail_set_group_presentation_v1")
public func mfx_macos_wasm_retained_ribbon_trail_set_group_presentation_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ alphaMultiplier: Float,
    _ visible: UInt32
) {
    guard let state = mfxRetainedRibbonTrailState(from: handle) else { return }
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

@_cdecl("mfx_macos_wasm_retained_ribbon_trail_set_effective_clip_rect_v1")
public func mfx_macos_wasm_retained_ribbon_trail_set_effective_clip_rect_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ clipLeftPx: Float,
    _ clipTopPx: Float,
    _ clipWidthPx: Float,
    _ clipHeightPx: Float
) {
    mfx_macos_wasm_retained_ribbon_trail_set_effective_clip_rect_v2(
        handle,
        clipLeftPx,
        clipTopPx,
        clipWidthPx,
        clipHeightPx,
        0,
        0.0)
}

@_cdecl("mfx_macos_wasm_retained_ribbon_trail_set_effective_clip_rect_v2")
public func mfx_macos_wasm_retained_ribbon_trail_set_effective_clip_rect_v2(
    _ handle: UnsafeMutableRawPointer?,
    _ clipLeftPx: Float,
    _ clipTopPx: Float,
    _ clipWidthPx: Float,
    _ clipHeightPx: Float,
    _ maskShapeKind: UInt32,
    _ cornerRadiusPx: Float
) {
    guard let state = mfxRetainedRibbonTrailState(from: handle) else { return }
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

@_cdecl("mfx_macos_wasm_retained_ribbon_trail_set_effective_layer_v1")
public func mfx_macos_wasm_retained_ribbon_trail_set_effective_layer_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ blendMode: UInt32,
    _ sortKey: Int32
) {
    guard let state = mfxRetainedRibbonTrailState(from: handle) else { return }
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

@_cdecl("mfx_macos_wasm_retained_ribbon_trail_set_effective_translation_v1")
public func mfx_macos_wasm_retained_ribbon_trail_set_effective_translation_v1(
    _ handle: UnsafeMutableRawPointer?,
    _ offsetXPx: Float,
    _ offsetYPx: Float
) {
    guard let state = mfxRetainedRibbonTrailState(from: handle) else { return }
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
