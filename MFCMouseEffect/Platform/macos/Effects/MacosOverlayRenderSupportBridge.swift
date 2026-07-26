@preconcurrency import AppKit
@preconcurrency import Foundation

@MainActor
private var mfxOverlayTargetFpsState: Int32 = 0

private func mfxSanitizeOverlayTargetFps(_ value: Int32) -> Int32 {
    if value <= 0 {
        return 0
    }
    if value > 360 {
        return 360
    }
    return value
}

@MainActor
private func mfxReadOverlayTargetFpsOnMainThread() -> Int32 {
    mfxOverlayTargetFpsState
}

@MainActor
private func mfxWriteOverlayTargetFpsOnMainThread(_ value: Int32) {
    mfxOverlayTargetFpsState = mfxSanitizeOverlayTargetFps(value)
}

private func mfxClampScale(_ value: CGFloat) -> CGFloat {
    if value < 1.0 {
        return 1.0
    }
    if value > 4.0 {
        return 4.0
    }
    return value
}

@MainActor
private func mfxResolveTargetScreenOnMainThread(_ x: Int32, _ y: Int32) -> NSScreen? {
    let screens = NSScreen.screens
    if screens.isEmpty {
        return nil
    }

    let point = NSPoint(x: CGFloat(x), y: CGFloat(y))
    for screen in screens where screen.frame.contains(point) {
        return screen
    }

    return NSScreen.main ?? screens.first
}

@MainActor
private func mfxResolveMaxFramesPerSecondOnMainThread(_ screen: NSScreen?) -> Int32 {
    let fallback: Int32 = 60
    guard let value = screen?.maximumFramesPerSecond else {
        return fallback
    }
    return max(fallback, Int32(value))
}

@MainActor
private func mfxResolveOverlayTimerIntervalMsOnMainThread(_ x: Int32, _ y: Int32) -> Int32 {
    let targetFps = mfxReadOverlayTargetFpsOnMainThread()
    let targetScreen = mfxResolveTargetScreenOnMainThread(x, y)
    let screenMaxFps = mfxResolveMaxFramesPerSecondOnMainThread(targetScreen)
    let effectiveFps = targetFps <= 0 ? screenMaxFps : max(1, min(targetFps, screenMaxFps))
    let intervalMs = Int((1000.0 / Double(max(1, effectiveFps))).rounded())
    return Int32(max(4, min(intervalMs, 1000)))
}

@MainActor
private func mfxCreateOverlayWindowOnMainThread(
    _ x: Double,
    _ y: Double,
    _ width: Double,
    _ height: Double
) -> UnsafeMutableRawPointer? {
    let frame = NSRect(x: x, y: y, width: width, height: height)
    let window = NSWindow(
        contentRect: frame,
        styleMask: .borderless,
        backing: .buffered,
        defer: false
    )
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.ignoresMouseEvents = true
    window.level = .statusBar
    window.collectionBehavior = [.canJoinAllSpaces, .transient]
    return Unmanaged.passRetained(window).toOpaque()
}

@MainActor
private func mfxResolveContentScaleOnMainThread(_ x: Int32, _ y: Int32) -> Double {
    guard let screen = mfxResolveTargetScreenOnMainThread(x, y) else {
        return 1.0
    }
    return Double(mfxClampScale(screen.backingScaleFactor))
}

@MainActor
private func mfxReleaseOverlayWindowOnMainThread(_ windowHandleBits: UInt) {
    guard windowHandleBits != 0 else {
        return
    }
    guard let ptr = UnsafeMutableRawPointer(bitPattern: windowHandleBits) else {
        return
    }
    let window = Unmanaged<NSWindow>.fromOpaque(ptr).takeRetainedValue()
    window.orderOut(nil)
}

@MainActor
private func mfxApplyContentScaleOnMainThread(_ contentHandleBits: UInt, _ x: Int32, _ y: Int32) {
    guard contentHandleBits != 0 else {
        return
    }
    guard let ptr = UnsafeMutableRawPointer(bitPattern: contentHandleBits) else {
        return
    }
    let content = Unmanaged<NSView>.fromOpaque(ptr).takeUnretainedValue()
    content.wantsLayer = true
    guard let root = content.layer else {
        return
    }
    let scale = CGFloat(mfxResolveContentScaleOnMainThread(x, y))
    root.contentsScale = scale
    root.sublayers?.forEach { layer in
        layer.contentsScale = scale
    }
}

@_cdecl("mfx_macos_overlay_create_window_v1")
public func mfx_macos_overlay_create_window_v1(
    _ x: Double,
    _ y: Double,
    _ width: Double,
    _ height: Double
) -> UnsafeMutableRawPointer? {
    if Thread.isMainThread {
        let bits = MainActor.assumeIsolated {
            UInt(bitPattern: mfxCreateOverlayWindowOnMainThread(x, y, width, height))
        }
        return UnsafeMutableRawPointer(bitPattern: bits)
    }

    var bits: UInt = 0
    DispatchQueue.main.sync {
        bits = MainActor.assumeIsolated {
            UInt(bitPattern: mfxCreateOverlayWindowOnMainThread(x, y, width, height))
        }
    }
    return UnsafeMutableRawPointer(bitPattern: bits)
}

@MainActor
private func mfxShowOverlayWindowOnMainThread(_ windowHandleBits: UInt) {
    guard windowHandleBits != 0 else {
        return
    }
    guard let ptr = UnsafeMutableRawPointer(bitPattern: windowHandleBits) else {
        return
    }
    let window = Unmanaged<NSWindow>.fromOpaque(ptr).takeUnretainedValue()
    window.orderFrontRegardless()
}

@_cdecl("mfx_macos_overlay_release_window_v1")
public func mfx_macos_overlay_release_window_v1(_ windowHandle: UnsafeMutableRawPointer?) {
    let windowHandleBits = UInt(bitPattern: windowHandle)
    if windowHandleBits == 0 {
        return
    }

    if Thread.isMainThread {
        MainActor.assumeIsolated {
            mfxReleaseOverlayWindowOnMainThread(windowHandleBits)
        }
        return
    }

    DispatchQueue.main.sync {
        MainActor.assumeIsolated {
            mfxReleaseOverlayWindowOnMainThread(windowHandleBits)
        }
    }
}

@_cdecl("mfx_macos_overlay_show_window_v1")
public func mfx_macos_overlay_show_window_v1(_ windowHandle: UnsafeMutableRawPointer?) {
    let windowHandleBits = UInt(bitPattern: windowHandle)
    if windowHandleBits == 0 {
        return
    }

    if Thread.isMainThread {
        MainActor.assumeIsolated {
            mfxShowOverlayWindowOnMainThread(windowHandleBits)
        }
        return
    }

    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            mfxShowOverlayWindowOnMainThread(windowHandleBits)
        }
    }
}

@_cdecl("mfx_macos_overlay_set_target_fps_v1")
public func mfx_macos_overlay_set_target_fps_v1(_ targetFps: Int32) {
    if Thread.isMainThread {
        MainActor.assumeIsolated {
            mfxWriteOverlayTargetFpsOnMainThread(targetFps)
        }
        return
    }

    DispatchQueue.main.sync {
        MainActor.assumeIsolated {
            mfxWriteOverlayTargetFpsOnMainThread(targetFps)
        }
    }
}

@_cdecl("mfx_macos_overlay_timer_interval_ms_v1")
public func mfx_macos_overlay_timer_interval_ms_v1(_ x: Int32, _ y: Int32) -> Int32 {
    if Thread.isMainThread {
        return MainActor.assumeIsolated {
            mfxResolveOverlayTimerIntervalMsOnMainThread(x, y)
        }
    }

    var interval: Int32 = 16
    DispatchQueue.main.sync {
        interval = MainActor.assumeIsolated {
            mfxResolveOverlayTimerIntervalMsOnMainThread(x, y)
        }
    }
    return interval
}

@_cdecl("mfx_macos_overlay_resolve_screen_frame_v1")
public func mfx_macos_overlay_resolve_screen_frame_v1(
    _ x: Int32,
    _ y: Int32,
    _ outX: UnsafeMutablePointer<Double>?,
    _ outY: UnsafeMutablePointer<Double>?,
    _ outWidth: UnsafeMutablePointer<Double>?,
    _ outHeight: UnsafeMutablePointer<Double>?
) -> Int32 {
    // Swift 6 strict concurrency: return a value from the main-actor hop
    // instead of mutating captured locals across isolation domains.
    @MainActor
    func resolveOnMain() -> NSRect? {
        let screens = NSScreen.screens
        if screens.isEmpty {
            return nil
        }

        let point = NSPoint(x: CGFloat(x), y: CGFloat(y))
        for screen in screens where screen.frame.contains(point) {
            let candidate = screen.frame
            if candidate.width > 0.0 && candidate.height > 0.0 {
                return candidate
            }
            return nil
        }

        if let fallback = NSScreen.main ?? screens.first {
            let candidate = fallback.frame
            if candidate.width > 0.0 && candidate.height > 0.0 {
                return candidate
            }
        }
        return nil
    }

    let resolved: NSRect?
    if Thread.isMainThread {
        resolved = MainActor.assumeIsolated {
            resolveOnMain()
        }
    } else {
        resolved = DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                resolveOnMain()
            }
        }
    }

    guard let frame = resolved else {
        return 0
    }
    outX?.pointee = Double(frame.origin.x)
    outY?.pointee = Double(frame.origin.y)
    outWidth?.pointee = Double(frame.size.width)
    outHeight?.pointee = Double(frame.size.height)
    return 1
}

@_cdecl("mfx_macos_overlay_resolve_content_scale_v1")
public func mfx_macos_overlay_resolve_content_scale_v1(_ x: Int32, _ y: Int32) -> Double {
    if Thread.isMainThread {
        return MainActor.assumeIsolated {
            mfxResolveContentScaleOnMainThread(x, y)
        }
    }

    var value = 1.0
    DispatchQueue.main.sync {
        value = MainActor.assumeIsolated {
            mfxResolveContentScaleOnMainThread(x, y)
        }
    }
    return value
}

@_cdecl("mfx_macos_overlay_apply_content_scale_v1")
public func mfx_macos_overlay_apply_content_scale_v1(
    _ contentHandle: UnsafeMutableRawPointer?,
    _ x: Int32,
    _ y: Int32
) {
    let contentHandleBits = UInt(bitPattern: contentHandle)
    if contentHandleBits == 0 {
        return
    }

    if Thread.isMainThread {
        MainActor.assumeIsolated {
            mfxApplyContentScaleOnMainThread(contentHandleBits, x, y)
        }
        return
    }

    DispatchQueue.main.sync {
        MainActor.assumeIsolated {
            mfxApplyContentScaleOnMainThread(contentHandleBits, x, y)
        }
    }
}
