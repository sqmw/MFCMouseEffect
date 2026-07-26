@preconcurrency import AppKit
@preconcurrency import ApplicationServices
@preconcurrency import Foundation
@preconcurrency import QuartzCore
@preconcurrency import SceneKit
import simd

private enum MfxMouseCompanionActionCode: Int32 {
    case idle = 0
    case follow = 1
    case clickReact = 2
    case drag = 3
    case holdReact = 4
    case scrollReact = 5
}

private enum MfxPoseBindingBone: Int {
    case leftEar = 0
    case rightEar = 1
    case leftHand = 2
    case rightHand = 3
    case leftLeg = 4
    case rightLeg = 5
}

private enum MfxMouseCompanionPositionMode: Int32 {
    case relative = 0
    case absolute = 1
    case fixedBottomLeftLegacy = 2
}

private enum MfxMouseCompanionEdgeClampMode: Int32 {
    case strict = 0
    case soft = 1
    case free = 2
}

private let mfxPetScreenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")

private struct MfxActionKeyframe {
    let t: CGFloat
    let rotation: simd_quatf?
    let scale: SIMD3<Float>?
}

private struct MfxActionTrack {
    let bone: String
    let keyframes: [MfxActionKeyframe]
}

private struct MfxActionClip {
    let action: String
    let duration: CGFloat
    let loop: Bool
    let tracks: [MfxActionTrack]
}

private struct MfxActionTrackSample {
    let rotation: simd_quatf?
    let scale: SIMD3<Float>?
}

private func mfxShouldRunActionPulse(_ actionCode: Int32) -> Bool {
    actionCode == MfxMouseCompanionActionCode.holdReact.rawValue ||
        actionCode == MfxMouseCompanionActionCode.scrollReact.rawValue
}

private func mfxNormalizedActionKey(_ action: String) -> String {
    action
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "_", with: "")
        .lowercased()
}

private struct MfxGlbNodeMetadata {
    let name: String?
    let children: [Int]
}

private func mfxClamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    if value < minValue {
        return minValue
    }
    if value > maxValue {
        return maxValue
    }
    return value
}

private func mfxImpulseProfile(_ t: CGFloat, inRatio: CGFloat, holdRatio: CGFloat) -> CGFloat {
    let x = mfxClamp(t, min: 0.0, max: 1.0)
    let inPart = mfxClamp(inRatio, min: 0.05, max: 0.9)
    let holdPart = mfxClamp(holdRatio, min: 0.0, max: 0.7)
    let outStart = mfxClamp(inPart + holdPart, min: inPart, max: 0.98)
    if x < inPart {
        let p = x / inPart
        let eased = 1.0 - pow(1.0 - p, 3.0)
        return mfxClamp(eased, min: 0.0, max: 1.0)
    }
    if x < outStart {
        return 1.0
    }
    let p = (x - outStart) / max(0.001, 1.0 - outStart)
    let eased = 1.0 - p * p * (3.0 - 2.0 * p)
    return mfxClamp(eased, min: 0.0, max: 1.0)
}

private func mfxYawFromQuaternion(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat, _ w: CGFloat) -> CGFloat {
    let siny = 2.0 * (w * z + x * y)
    let cosy = 1.0 - 2.0 * (y * y + z * z)
    return atan2(siny, cosy)
}

@MainActor
private final class MfxMouseCompanionPanelView: NSView {
    private var actionCode: MfxMouseCompanionActionCode = .idle
    private var actionIntensity: CGFloat = 0.0
    private var headTintAmount: CGFloat = 0.0
    private var pointerNormalizedX: CGFloat = 0.0
    private var scrollFacingSign: CGFloat = 1.0
    private var scrollFacingHold: CGFloat = 0.0
    private var clickPulse: CGFloat = 0.0
    private var holdPulse: CGFloat = 0.0
    private var scrollFlapProgress: CGFloat = 1.0
    private var scrollFlapDuration: CGFloat = 0.18
    private var scrollFlapAmplitude: CGFloat = 0.35
    private var queuedScrollFlapDuration: CGFloat = 0.18
    private var queuedScrollFlapAmplitude: CGFloat = 0.35
    private var pendingScrollFlapCount: Int = 0
    private var lastScrollEventTick: CFTimeInterval = 0.0
    private var poseBindingConfigured = false
    private var poseEarSpread: CGFloat = 0.0
    private var poseEarLift: CGFloat = 0.0
    private var poseHandLift: CGFloat = 0.0
    private var poseHandSpread: CGFloat = 0.0
    private var poseLegSpread: CGFloat = 0.0
    private var poseLegKick: CGFloat = 0.0
    private var bobTime: CGFloat = 0.0
    private var frameTimer: Timer?
    private var lastTick: CFTimeInterval = CACurrentMediaTime()

    override var isOpaque: Bool {
        false
    }

    func start() {
        if frameTimer != nil {
            return
        }
        frameTimer = Timer.scheduledTimer(
            timeInterval: 1.0 / 60.0,
            target: self,
            selector: #selector(onFrame(_:)),
            userInfo: nil,
            repeats: true)
    }

    func stop() {
        frameTimer?.invalidate()
        frameTimer = nil
    }

    func updateState(actionCode: Int32, actionIntensity: Float, headTintAmount: Float) {
        let resolvedAction = MfxMouseCompanionActionCode(rawValue: actionCode) ?? .idle
        let rawIntensity = CGFloat(actionIntensity)
        let resolvedIntensity = mfxClamp(abs(rawIntensity), min: 0.0, max: 1.0)
        let resolvedTint = mfxClamp(CGFloat(headTintAmount), min: 0.0, max: 1.0)

        if resolvedAction == .clickReact {
            clickPulse = max(clickPulse, 1.0)
        }
        if resolvedAction == .holdReact {
            holdPulse = max(holdPulse, max(0.35, resolvedIntensity))
        }
        if resolvedAction == .scrollReact {
            scrollFacingSign = rawIntensity < 0.0 ? -1.0 : 1.0
            scrollFacingHold = 0.30
            let now = CACurrentMediaTime()
            let amplitude = mfxClamp(max(0.35, resolvedIntensity), min: 0.35, max: 2.4)
            let maxDuration: CGFloat = 0.26
            let minDuration: CGFloat = 0.10
            var duration = maxDuration
            if lastScrollEventTick > 0.0 {
                let intervalMs = min(max((now - lastScrollEventTick) * 1000.0, 24.0), 180.0)
                let fastness = mfxClamp((180.0 - intervalMs) / (180.0 - 24.0), min: 0.0, max: 1.0)
                duration = maxDuration - (maxDuration - minDuration) * fastness
            }
            lastScrollEventTick = now
            if scrollFlapProgress >= 1.0 {
                scrollFlapProgress = 0.0
                scrollFlapDuration = duration
                scrollFlapAmplitude = amplitude
            } else {
                pendingScrollFlapCount = min(pendingScrollFlapCount + 1, 8)
                queuedScrollFlapDuration = duration
                queuedScrollFlapAmplitude = max(queuedScrollFlapAmplitude, amplitude)
                let elapsed = mfxClamp(scrollFlapProgress, min: 0.0, max: 1.0) * max(0.001, scrollFlapDuration)
                scrollFlapDuration = min(scrollFlapDuration, duration)
                scrollFlapAmplitude = max(scrollFlapAmplitude, amplitude)
                scrollFlapProgress = mfxClamp(elapsed / max(0.001, scrollFlapDuration), min: 0.0, max: 1.0)
            }
        }

        self.actionCode = resolvedAction
        self.actionIntensity = resolvedIntensity
        self.headTintAmount = resolvedTint
        needsDisplay = true
    }

    func updatePointerNormalizedX(_ value: CGFloat) {
        pointerNormalizedX = mfxClamp(value, min: -1.0, max: 1.0)
        needsDisplay = true
    }

    func configurePoseBinding(names: [String]) -> Bool {
        poseBindingConfigured = !names.isEmpty
        if !poseBindingConfigured {
            poseEarSpread = 0.0
            poseEarLift = 0.0
            poseHandLift = 0.0
            poseHandSpread = 0.0
            poseLegSpread = 0.0
            poseLegKick = 0.0
        }
        return poseBindingConfigured
    }

    func applyPose(indices: [Int32], positions: [Float], rotations: [Float], scales: [Float]) {
        guard poseBindingConfigured else {
            return
        }
        let count = indices.count
        if positions.count < count * 3 || rotations.count < count * 4 || scales.count < count * 3 {
            return
        }

        var leftEarX: CGFloat = 0.0
        var leftEarY: CGFloat = 0.0
        var rightEarX: CGFloat = 0.0
        var rightEarY: CGFloat = 0.0
        var leftEarYaw: CGFloat = 0.0
        var rightEarYaw: CGFloat = 0.0
        var leftHandY: CGFloat = 0.0
        var rightHandY: CGFloat = 0.0
        var leftHandYaw: CGFloat = 0.0
        var rightHandYaw: CGFloat = 0.0
        var leftLegYaw: CGFloat = 0.0
        var rightLegYaw: CGFloat = 0.0

        for i in 0..<count {
            let idx = Int(indices[i])
            if idx < 0 {
                continue
            }
            let pBase = i * 3
            let rBase = i * 4
            let px = CGFloat(positions[pBase])
            let py = CGFloat(positions[pBase + 1])
            let qx = CGFloat(rotations[rBase])
            let qy = CGFloat(rotations[rBase + 1])
            let qz = CGFloat(rotations[rBase + 2])
            let qw = CGFloat(rotations[rBase + 3])
            let yawZ = mfxYawFromQuaternion(qx, qy, qz, qw)

            switch idx {
            case 0:
                leftEarX = px
                leftEarY = py
                leftEarYaw = yawZ
            case 1:
                rightEarX = px
                rightEarY = py
                rightEarYaw = yawZ
            case 2:
                leftHandY = py
                leftHandYaw = yawZ
            case 3:
                rightHandY = py
                rightHandYaw = yawZ
            case 4:
                leftLegYaw = yawZ
            case 5:
                rightLegYaw = yawZ
            default:
                break
            }
        }

        let earSpread = mfxClamp((abs(leftEarYaw) + abs(rightEarYaw)) * 0.7 + (abs(leftEarX) + abs(rightEarX)) * 1.8, min: 0.0, max: 1.0)
        let earLift = mfxClamp((leftEarY + rightEarY) * 2.4, min: 0.0, max: 1.0)
        let handLift = mfxClamp((leftHandY + rightHandY) * 2.0, min: 0.0, max: 1.0)
        let handSpread = mfxClamp((abs(leftHandYaw) + abs(rightHandYaw)) * 0.9, min: 0.0, max: 1.0)
        let legSpread = mfxClamp((abs(leftLegYaw) + abs(rightLegYaw)) * 1.0, min: 0.0, max: 1.0)
        let legKick = mfxClamp((abs(leftLegYaw) + abs(rightLegYaw)) * 0.9, min: 0.0, max: 1.0)

        poseEarSpread = earSpread
        poseEarLift = earLift
        poseHandLift = handLift
        poseHandSpread = handSpread
        poseLegSpread = legSpread
        poseLegKick = legKick
        needsDisplay = true
    }

    @objc private func onFrame(_ timer: Timer) {
        let now = CACurrentMediaTime()
        let dt = CGFloat(max(0.0, min(0.08, now - lastTick)))
        lastTick = now

        bobTime += dt
        clickPulse = max(0.0, clickPulse - dt * 3.6)
        holdPulse = max(0.0, holdPulse - dt * 1.2)
        scrollFacingHold = max(0.0, scrollFacingHold - dt)
        if scrollFlapProgress < 1.0 {
            scrollFlapProgress += dt / max(0.001, scrollFlapDuration)
            while scrollFlapProgress >= 1.0, pendingScrollFlapCount > 0 {
                pendingScrollFlapCount -= 1
                scrollFlapProgress = 0.0
                scrollFlapDuration = queuedScrollFlapDuration
                scrollFlapAmplitude = queuedScrollFlapAmplitude
            }
            if scrollFlapProgress >= 1.0 {
                scrollFlapProgress = 1.0
            }
        }

        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        let side = min(bounds.width, bounds.height)
        if side <= 1.0 {
            return
        }

        let clickT = mfxClamp(1.0 - clickPulse, min: 0.0, max: 1.0)
        let clickProfileBase = mfxImpulseProfile(clickT, inRatio: 0.42, holdRatio: 0.16)
        let holdProfileBase = mfxClamp(max(holdPulse, (actionCode == .holdReact ? actionIntensity : 0.0)), min: 0.0, max: 1.0)
        let scrollT = (scrollFlapProgress < 1.0)
            ? mfxClamp(scrollFlapProgress, min: 0.0, max: 1.0)
            : 0.0
        let scrollAmpNorm = (scrollFlapProgress < 1.0)
            ? mfxClamp((scrollFlapAmplitude - 0.35) / (2.4 - 0.35), min: 0.0, max: 1.0)
            : 0.0
        let scrollProfileBase = (scrollFlapProgress < 1.0)
            ? mfxImpulseProfile(scrollT, inRatio: 0.42, holdRatio: 0.16) * mfxClamp(0.82 + scrollAmpNorm * 0.18, min: 0.0, max: 1.0)
            : 0.0
        let scrollFlap = (scrollFlapProgress < 1.0)
            ? CGFloat(sin(Double(scrollT) * Double.pi)) * scrollProfileBase * (0.28 + scrollAmpNorm * 0.16)
            : 0.0
        let idleProfile = (actionCode == .idle) ? actionIntensity : 0.0
        let clickPoseProfile = (actionCode == .clickReact) ? max(poseHandSpread, poseLegSpread, poseEarSpread * 0.9) : 0.0
        let holdPoseProfile = (actionCode == .holdReact) ? (poseHandLift * 0.7) : 0.0
        let scrollPoseProfile = (actionCode == .scrollReact) ? max(poseEarSpread * 0.8, poseLegKick * 0.7) : 0.0
        let clickProfile = max(clickProfileBase, clickPoseProfile)
        let holdProfile = max(holdProfileBase, holdPoseProfile)
        let scrollProfile = max(scrollProfileBase, scrollPoseProfile)

        let followProfile = (actionCode == .follow) ? actionIntensity : 0.0
        let walkRate = 1.6 + followProfile * 1.8
        let walkSwing = CGFloat(sin(Double(bobTime * walkRate * 3.1415926)))
        let bobOffset = (actionCode == .follow)
            ? 0.0
            : sin(Double(bobTime * 2.1)) * Double(2.0 + holdProfile * 3.0 + idleProfile * 1.8)
        let followTiltBase = pointerNormalizedX * 4.0
        let dragTilt = (actionCode == .drag) ? (-actionIntensity * 4.0) : 0.0
        let followTilt = (actionCode == .drag) ? (followTiltBase + dragTilt) : 0.0
        let clickScale = 1.0 + clickProfile * 0.10
        let holdScale = 1.0 + holdProfile * 0.05
        let scrollScale = 1.0 + scrollProfile * 0.04
        let idleScale = 1.0 + sin(Double(bobTime * 1.7)) * Double(idleProfile * 0.018)
        let actionScale = clickScale * holdScale * scrollScale * CGFloat(idleScale)
        let scrollFacingRotation = (scrollFacingHold > 0.0 && scrollFacingSign < 0.0) ? 180.0 : 0.0

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: bounds.midX, yBy: bounds.midY + CGFloat(bobOffset))
        transform.rotate(byDegrees: scrollFacingRotation)
        transform.rotate(byDegrees: followTilt * (actionCode == .drag ? -1.0 : 1.0))
        transform.scale(by: actionScale)
        transform.concat()

        drawShadow(side: side, clickProfile: clickProfile)
        drawLimbs(side: side, clickProfile: clickProfile, holdProfile: holdProfile, scrollProfile: scrollProfile, scrollFlap: scrollFlap, idleProfile: idleProfile, followProfile: followProfile, walkSwing: walkSwing)
        drawBody(side: side, clickProfile: clickProfile, holdProfile: holdProfile)
        drawHead(side: side, clickProfile: clickProfile, holdProfile: holdProfile, scrollProfile: scrollProfile, scrollFlap: scrollFlap, idleProfile: idleProfile)
        drawFace(side: side, clickProfile: clickProfile, scrollProfile: scrollProfile, holdProfile: holdProfile)
        drawActionAura(side: side, clickProfile: clickProfile, holdProfile: holdProfile, scrollProfile: scrollProfile)

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawShadow(side: CGFloat, clickProfile: CGFloat) {
        let shadowRect = NSRect(x: -side * 0.20, y: -side * 0.40, width: side * 0.40, height: side * 0.11)
        let alpha = 0.22 + 0.08 * clickProfile
        NSColor(calibratedWhite: 0.0, alpha: alpha).setFill()
        NSBezierPath(ovalIn: shadowRect).fill()
    }

    private func drawLimbs(side: CGFloat, clickProfile: CGFloat, holdProfile: CGFloat, scrollProfile: CGFloat, scrollFlap: CGFloat, idleProfile: CGFloat, followProfile: CGFloat, walkSwing: CGFloat) {
        let idleHandWave = sin(Double(bobTime * 3.1 + 0.8)) * Double(side * idleProfile * 0.03)
        let handSpread = side * (0.17 + clickProfile * 0.03 + scrollProfile * 0.02 - holdProfile * 0.09 + poseHandSpread * 0.005)
        let handBaseY = side * (0.01 - holdProfile * 0.06)
        let handLift = side * (clickProfile * 0.10 + scrollProfile * 0.10 - holdProfile * 0.01 + poseHandLift * 0.02 + abs(scrollFlap) * 0.04) + CGFloat(idleHandWave)
        let handTwist = 34.0 * clickProfile + 26.0 * scrollProfile + scrollFlap * 18.0 + 50.0 * holdProfile + 8.0 * poseHandSpread + idleProfile * 6.0
        let handRect = NSRect(x: -side * 0.06, y: -side * 0.05, width: side * 0.12, height: side * 0.14)
        let leftHandY = handBaseY + handLift + followProfile * max(0.0, -walkSwing) * side * 0.05
        let rightHandY = handBaseY + handLift + followProfile * max(0.0, walkSwing) * side * 0.05
        let leftHandTwist = handTwist - followProfile * (6.0 + walkSwing * 18.0)
        let rightHandTwist = -handTwist - followProfile * (6.0 - walkSwing * 18.0)
        drawLimbOval(centerX: -handSpread, centerY: leftHandY, degrees: leftHandTwist, rect: handRect)
        drawLimbOval(centerX: handSpread, centerY: rightHandY, degrees: rightHandTwist, rect: handRect)

        let legSpread = side * (0.10 + clickProfile * 0.03 + scrollProfile * 0.04 - holdProfile * 0.05 + poseLegSpread * 0.01)
        let legY = -side * (0.20 - holdProfile * 0.04)
        let legKick = 16.0 * clickProfile + 12.0 * scrollProfile + abs(scrollFlap) * 6.0 + 28.0 * holdProfile + 18.0 * poseLegKick
        let legRect = NSRect(x: -side * 0.055, y: -side * 0.025, width: side * 0.11, height: side * 0.09)
        let leftLegKick = -legKick + followProfile * (4.0 - walkSwing * 18.0)
        let rightLegKick = legKick + followProfile * (4.0 + walkSwing * 18.0)
        drawLimbOval(centerX: -legSpread, centerY: legY, degrees: leftLegKick, rect: legRect)
        drawLimbOval(centerX: legSpread, centerY: legY, degrees: rightLegKick, rect: legRect)
    }

    private func drawLimbOval(centerX: CGFloat, centerY: CGFloat, degrees: CGFloat, rect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        let tf = NSAffineTransform()
        tf.translateX(by: centerX, yBy: centerY)
        tf.rotate(byDegrees: degrees)
        tf.concat()
        let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.5, yRadius: rect.width * 0.5)
        NSColor(calibratedRed: 0.96, green: 0.98, blue: 1.0, alpha: 0.98).setFill()
        path.fill()
        NSColor(calibratedRed: 0.74, green: 0.79, blue: 0.90, alpha: 0.92).setStroke()
        path.lineWidth = 1.1
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawBody(side: CGFloat, clickProfile: CGFloat, holdProfile: CGFloat) {
        let bodyWidth = side * (0.40 + holdProfile * 0.08)
        let bodyHeight = side * (0.44 - holdProfile * 0.13)
        let bodyRect = NSRect(
            x: -bodyWidth * 0.5,
            y: -side * 0.30 - holdProfile * side * 0.02,
            width: bodyWidth,
            height: bodyHeight)
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: side * 0.20, yRadius: side * 0.20)

        let bodyTop = NSColor(calibratedRed: 0.98, green: 0.99 - holdProfile * 0.04, blue: 1.0, alpha: 0.95)
        let bodyBottom = NSColor(calibratedRed: 0.93, green: 0.96 - holdProfile * 0.05, blue: 1.0, alpha: 0.95)
        let bodyGradient = NSGradient(colors: [bodyTop, bodyBottom])
        bodyGradient?.draw(in: bodyPath, angle: -90.0)

        NSColor(calibratedRed: 0.76, green: 0.81, blue: 0.90, alpha: 0.9).setStroke()
        bodyPath.lineWidth = 1.4 + clickProfile * 0.2
        bodyPath.stroke()
    }

    private func drawHead(side: CGFloat, clickProfile: CGFloat, holdProfile: CGFloat, scrollProfile: CGFloat, scrollFlap: CGFloat, idleProfile: CGFloat) {
        let idleEarWave = CGFloat(sin(Double(bobTime * 3.4))) * side * idleProfile * 0.022
        let earLift = (clickProfile * 0.04 + scrollProfile * 0.03 - holdProfile * 0.04 + poseEarLift * 0.05) * side + idleEarWave
        let earWingOpen = (clickProfile * 0.03 + scrollProfile * 0.06 + abs(scrollFlap) * 0.03 + poseEarSpread * 0.06) * side + abs(idleEarWave) * 0.35
        let earFlapDegrees = scrollFlap * 20.0
        let clickEarSpread = (clickProfile * 0.03) * side + abs(idleEarWave) * 0.4
        let leftEarBaseX = -side * 0.11 - clickEarSpread - earWingOpen
        let rightEarBaseX = side * 0.11 + clickEarSpread + earWingOpen
        let earBaseY = side * 0.13 + earLift
        let earWidth = side * 0.12
        let earHeight = side * 0.36
        let headWidth = side * (0.48 + holdProfile * 0.08)
        let headHeight = side * (0.40 - holdProfile * 0.08)
        let headRect = NSRect(
            x: -headWidth * 0.5,
            y: -side * 0.02 - holdProfile * side * 0.018,
            width: headWidth,
            height: headHeight)

        drawEar(baseX: leftEarBaseX, baseY: earBaseY, width: earWidth, height: earHeight, degrees: -6.0 - scrollProfile * 18.0 - earFlapDegrees, side: side, clickProfile: clickProfile)
        drawEar(baseX: rightEarBaseX, baseY: earBaseY, width: earWidth, height: earHeight, degrees: 6.0 + scrollProfile * 18.0 + earFlapDegrees, side: side, clickProfile: clickProfile)

        let headPath = NSBezierPath(ovalIn: headRect)
        let tint = headTintAmount
        let warmTop = NSColor(
            calibratedRed: 0.98,
            green: 0.98 - tint * 0.20 - holdProfile * 0.03,
            blue: 1.0 - tint * 0.35,
            alpha: 0.98)
        let warmBottom = NSColor(
            calibratedRed: 0.94,
            green: 0.95 - tint * 0.18 - holdProfile * 0.04,
            blue: 0.99 - tint * 0.28,
            alpha: 0.98)

        let headGradient = NSGradient(colors: [warmTop, warmBottom])
        headGradient?.draw(in: headPath, angle: -90.0)

        NSColor(calibratedRed: 0.74, green: 0.79, blue: 0.90, alpha: 0.92).setStroke()
        headPath.lineWidth = 1.6
        headPath.stroke()
    }

    private func drawEar(baseX: CGFloat, baseY: CGFloat, width: CGFloat, height: CGFloat, degrees: CGFloat, side: CGFloat, clickProfile: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        let tf = NSAffineTransform()
        tf.translateX(by: baseX, yBy: baseY)
        tf.rotate(byDegrees: degrees)
        tf.concat()

        let rect = NSRect(x: -width * 0.5, y: 0.0, width: width, height: height)
        let earPath = NSBezierPath(roundedRect: rect, xRadius: side * 0.06, yRadius: side * 0.06)
        NSColor(calibratedRed: 0.96, green: 0.98, blue: 1.0, alpha: 0.98).setFill()
        earPath.fill()
        NSColor(calibratedRed: 0.74, green: 0.79, blue: 0.90, alpha: 0.92).setStroke()
        earPath.lineWidth = 1.3
        earPath.stroke()

        let innerInsetX = rect.width * 0.24
        let innerInsetY = rect.height * 0.22
        let innerRect = rect.insetBy(dx: innerInsetX, dy: innerInsetY)
        NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.84, alpha: 0.66 + 0.20 * clickProfile).setFill()
        NSBezierPath(roundedRect: innerRect, xRadius: innerRect.width * 0.5, yRadius: innerRect.width * 0.5).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawFace(side: CGFloat, clickProfile: CGFloat, scrollProfile: CGFloat, holdProfile: CGFloat) {
        let eyeY = side * 0.14
        let eyeOffsetX = side * 0.09
        let eyeWidth = side * 0.045
        let eyeHeight = side * 0.065

        if actionCode == .clickReact {
            drawSmileEye(centerX: -eyeOffsetX, centerY: eyeY, width: eyeWidth * 1.3)
            drawSmileEye(centerX: eyeOffsetX, centerY: eyeY, width: eyeWidth * 1.3)
        } else {
            let blink = (actionCode == .holdReact) ? mfxClamp(holdProfile * 0.6, min: 0.0, max: 0.8) : 0.0
            let actualEyeHeight = eyeHeight * (1.0 - blink)
            NSColor(calibratedWhite: 0.18, alpha: 0.95).setFill()
            NSBezierPath(ovalIn: NSRect(x: -eyeOffsetX - eyeWidth * 0.5, y: eyeY - actualEyeHeight * 0.5, width: eyeWidth, height: max(2.0, actualEyeHeight))).fill()
            NSBezierPath(ovalIn: NSRect(x: eyeOffsetX - eyeWidth * 0.5, y: eyeY - actualEyeHeight * 0.5, width: eyeWidth, height: max(2.0, actualEyeHeight))).fill()
        }

        let noseRect = NSRect(x: -side * 0.018, y: side * 0.075, width: side * 0.036, height: side * 0.026)
        NSColor(calibratedRed: 1.0, green: 0.56, blue: 0.66, alpha: 0.90).setFill()
        NSBezierPath(ovalIn: noseRect).fill()

        let mouthPath = NSBezierPath()
        mouthPath.move(to: NSPoint(x: 0.0, y: side * 0.067))
        mouthPath.line(to: NSPoint(x: 0.0, y: side * 0.038))
        mouthPath.curve(to: NSPoint(x: -side * 0.045, y: side * 0.017), controlPoint1: NSPoint(x: -side * 0.006, y: side * 0.028), controlPoint2: NSPoint(x: -side * 0.026, y: side * 0.012))
        mouthPath.move(to: NSPoint(x: 0.0, y: side * 0.038))
        mouthPath.curve(to: NSPoint(x: side * 0.045, y: side * 0.017), controlPoint1: NSPoint(x: side * 0.006, y: side * 0.028), controlPoint2: NSPoint(x: side * 0.026, y: side * 0.012))
        NSColor(calibratedWhite: 0.25, alpha: 0.88).setStroke()
        mouthPath.lineWidth = 1.3
        mouthPath.lineCapStyle = .round
        mouthPath.stroke()

        let blushAlpha = 0.18 + 0.20 * max(clickProfile, scrollProfile)
        NSColor(calibratedRed: 1.0, green: 0.68, blue: 0.73, alpha: blushAlpha).setFill()
        NSBezierPath(ovalIn: NSRect(x: -side * 0.17, y: side * 0.07, width: side * 0.07, height: side * 0.04)).fill()
        NSBezierPath(ovalIn: NSRect(x: side * 0.10, y: side * 0.07, width: side * 0.07, height: side * 0.04)).fill()
    }

    private func drawSmileEye(centerX: CGFloat, centerY: CGFloat, width: CGFloat) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: centerX - width * 0.5, y: centerY))
        path.curve(to: NSPoint(x: centerX + width * 0.5, y: centerY),
                   controlPoint1: NSPoint(x: centerX - width * 0.2, y: centerY + width * 0.32),
                   controlPoint2: NSPoint(x: centerX + width * 0.2, y: centerY + width * 0.32))
        NSColor(calibratedWhite: 0.2, alpha: 0.96).setStroke()
        path.lineWidth = 1.8
        path.lineCapStyle = .round
        path.stroke()
    }

    private func drawActionAura(side: CGFloat, clickProfile: CGFloat, holdProfile: CGFloat, scrollProfile: CGFloat) {
        let auraStrength = max(clickProfile, holdProfile, scrollProfile)
        if auraStrength <= 0.001 {
            return
        }
        let auraRadius = side * (0.34 + auraStrength * 0.18)
        let auraRect = NSRect(x: -auraRadius, y: -side * 0.05 - auraRadius, width: auraRadius * 2.0, height: auraRadius * 2.0)
        let auraColor: NSColor
        switch actionCode {
        case .scrollReact:
            auraColor = NSColor(calibratedRed: 0.42, green: 0.82, blue: 1.0, alpha: 0.24 * auraStrength)
        case .holdReact:
            auraColor = NSColor(calibratedRed: 1.0, green: 0.77, blue: 0.54, alpha: 0.22 * auraStrength)
        default:
            auraColor = NSColor(calibratedRed: 1.0, green: 0.67, blue: 0.73, alpha: 0.22 * auraStrength)
        }
        auraColor.setStroke()
        let auraPath = NSBezierPath(ovalIn: auraRect)
        auraPath.lineWidth = 2.0
        auraPath.stroke()
    }
}

@MainActor
private final class MfxMouseCompanionPanelWindow: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

@MainActor
private final class MfxMouseCompanionPanelHandle: NSObject {
    private let panel: MfxMouseCompanionPanelWindow
    private let contentView: NSView
    private let companionView: MfxMouseCompanionPanelView
    private let sceneView: SCNView
    private let sceneRootNode = SCNNode()
    private let sceneCameraNode = SCNNode()
    private var targetPetSizePx: CGFloat
    private var panelCanvasSize: CGSize
    private let baseCameraPosition = SCNVector3(x: 0.0, y: 0.24, z: 3.2)
    private var positionMode: MfxMouseCompanionPositionMode = .fixedBottomLeftLegacy
    private var edgeClampMode: MfxMouseCompanionEdgeClampMode = .soft
    private var offsetX: CGFloat
    private var offsetY: CGFloat
    private var absoluteX: CGFloat = 40.0
    private var absoluteY: CGFloat = 40.0
    private var targetMonitor: String = "cursor"
    private var modelNode: SCNNode?
    private var modelLoaded = false
    private var boneNodesByName: [String: [SCNNode]] = [:]
    private var poseBindingNodesByIndex: [[SCNNode]] = []
    private var poseBindingHadMeaningfulDelta = false
    private var restLocalTransformByNode: [ObjectIdentifier: simd_float4x4] = [:]
    private var semanticChestNodes: [SCNNode] = []
    private var semanticHeadNodes: [SCNNode] = []
    private var actionClipsByName: [String: MfxActionClip] = [:]
    private var clickActionClip: MfxActionClip?
    private var actionBoneRemapLower: [String: [String]] = [:]
    private var actionTrackNodeCache: [String: [SCNNode]] = [:]
    private var headTintTargetNodes: [SCNNode] = []
    private var headTintBaseMultiplyByMaterial: [ObjectIdentifier: NSColor] = [:]
    private var appliedHeadTintAmount: CGFloat = -1.0
    private let headTintColor = NSColor(calibratedRed: 1.0, green: 0.30, blue: 0.30, alpha: 1.0)
    private var modelBaseScale: CGFloat = 1.0
    private var modelBasePosition = SCNVector3Zero
    private let modelFacingYaw: CGFloat = .pi
    private let defaultPetReferenceSizePx: CGFloat = 112.0
    private var pointerNormalizedX: CGFloat = 0.0
    private var lastModelActionCode: Int32 = -1
    private var modelBobTime: CGFloat = 0.0
    private var modelLastTick: CFTimeInterval = CACurrentMediaTime()
    private var clickOneShotActive = false
    private var clickOneShotElapsed: CGFloat = 0.0
    private var clickOneShotDuration: CGFloat = 0.30
    private var continuousActionKey: String?
    private var continuousActionElapsed: CGFloat = 0.0
    private var pendingInitialPanelFit = false
    private var pendingRuntimePanelRefitPasses = 0
    private var modelFrameTimer: Timer?
    private var currentActionCode: Int32 = MfxMouseCompanionActionCode.idle.rawValue
    private var currentActionIntensity: Float = 0.0
    private var currentHeadTintAmount: Float = 0.0
    private var scrollFacingSign: CGFloat = 1.0
    private var scrollFacingHold: CGFloat = 0.0

    init(sizePx: Int, offsetX: Int, offsetY: Int) {
        let side = CGFloat(max(96, sizePx))
        targetPetSizePx = side
        panelCanvasSize = CGSize(width: side, height: side)
        panel = MfxMouseCompanionPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: side, height: side),
            styleMask: .borderless,
            backing: .buffered,
            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentView = NSView(frame: NSRect(x: 0, y: 0, width: side, height: side))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor

        companionView = MfxMouseCompanionPanelView(frame: NSRect(x: 0, y: 0, width: side, height: side))
        companionView.wantsLayer = true
        sceneView = SCNView(frame: NSRect(x: 0, y: 0, width: side, height: side))
        sceneView.wantsLayer = true
        sceneView.backgroundColor = .clear
        sceneView.autoenablesDefaultLighting = false
        sceneView.rendersContinuously = true
        sceneView.antialiasingMode = .multisampling4X
        sceneView.isPlaying = true
        sceneView.allowsCameraControl = false
        sceneView.autoresizingMask = [.width, .height]
        sceneView.isHidden = true

        let scene = SCNScene()
        scene.rootNode.addChildNode(sceneRootNode)
        sceneView.scene = scene

        sceneCameraNode.camera = SCNCamera()
        sceneCameraNode.camera?.zNear = 0.01
        sceneCameraNode.camera?.zFar = 1000.0
        sceneCameraNode.camera?.fieldOfView = 64.0
        sceneCameraNode.position = baseCameraPosition
        scene.rootNode.addChildNode(sceneCameraNode)
        sceneView.pointOfView = sceneCameraNode

        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 620
        keyLight.eulerAngles = SCNVector3(x: -0.78, y: 0.95, z: 0.0)
        scene.rootNode.addChildNode(keyLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .ambient
        fillLight.light?.intensity = 700
        scene.rootNode.addChildNode(fillLight)

        contentView.addSubview(sceneView)
        contentView.addSubview(companionView)
        panel.contentView = contentView

        self.offsetX = CGFloat(offsetX)
        self.offsetY = CGFloat(offsetY)

        super.init()
        companionView.start()
        startModelFrameLoop()
    }

    func show() {
        applyCurrentPosition()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func closeAndCleanup() {
        hide()
        stopModelFrameLoop()
        companionView.stop()
        sceneView.removeFromSuperview()
        companionView.removeFromSuperview()
        panel.close()
    }

    func configure(
        sizePx: Int32,
        positionModeCode: Int32,
        edgeClampModeCode: Int32,
        offsetX: Int32,
        offsetY: Int32,
        absoluteX: Int32,
        absoluteY: Int32,
        targetMonitor: String
    ) {
        let resolvedSize = CGFloat(max(96, Int(sizePx)))
        let sizeChanged = abs(resolvedSize - targetPetSizePx) >= 0.5
        targetPetSizePx = resolvedSize
        positionMode = MfxMouseCompanionPositionMode(rawValue: positionModeCode) ?? .fixedBottomLeftLegacy
        edgeClampMode = MfxMouseCompanionEdgeClampMode(rawValue: edgeClampModeCode) ?? .soft
        self.offsetX = CGFloat(offsetX)
        self.offsetY = CGFloat(offsetY)
        self.absoluteX = CGFloat(absoluteX)
        self.absoluteY = CGFloat(absoluteY)
        self.targetMonitor = targetMonitor.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if sizeChanged {
            if modelLoaded {
                resizePanelCanvasIfNeeded(CGSize(width: targetPetSizePx, height: targetPetSizePx))
                normalizeModelTransform()
                if !fitCanvasToModel(preferSnapshot: false, usePresentation: false) {
                    resizePanelCanvasIfNeeded(CGSize(width: targetPetSizePx, height: targetPetSizePx))
                }
                pendingRuntimePanelRefitPasses = 2
            } else {
                resizePanelCanvasIfNeeded(CGSize(width: targetPetSizePx, height: targetPetSizePx))
            }
        }
        applyCurrentPosition()
    }

    func update(actionCode: Int32, actionIntensity: Float, headTintAmount: Float) {
        currentActionCode = actionCode
        currentActionIntensity = actionIntensity
        currentHeadTintAmount = headTintAmount

        if actionCode == MfxMouseCompanionActionCode.clickReact.rawValue {
            beginClickOneShot()
        } else if actionCode == MfxMouseCompanionActionCode.scrollReact.rawValue {
            scrollFacingSign = actionIntensity < 0.0 ? -1.0 : 1.0
            scrollFacingHold = 0.30
        }

        if modelLoaded, let modelNode {
            updateLoadedModel(
                node: modelNode,
                actionCode: actionCode,
                actionIntensity: actionIntensity,
                headTintAmount: headTintAmount)
            return
        }
        companionView.updateState(
            actionCode: actionCode,
            actionIntensity: actionIntensity,
            headTintAmount: headTintAmount)
    }

    func loadModel(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }
        guard let scene = loadScene(url: url) else {
            return false
        }
        guard !scene.rootNode.childNodes.isEmpty else {
            return false
        }

        let container = SCNNode()
        for child in scene.rootNode.childNodes {
            container.addChildNode(child.clone())
        }
        hydrateAnonymousSkeletonNamesIfNeeded(root: container, sourceURL: url)
        disableImportedAnimations(root: container)
        guard containsRenderableGeometry(root: container) else {
            return false
        }

        modelNode?.removeFromParentNode()
        sceneRootNode.addChildNode(container)
        modelNode = container
        rebuildBoneNodeIndex(root: container)
        resolveSemanticCoreBones()
        rebuildHeadTintTargets(root: container)
        actionTrackNodeCache.removeAll(keepingCapacity: true)
        poseBindingNodesByIndex.removeAll(keepingCapacity: true)
        poseBindingHadMeaningfulDelta = false
        sceneView.isHidden = false
        companionView.isHidden = true
        normalizeModelTransform()
        pendingInitialPanelFit = true
        modelLoaded = true
        modelLastTick = CACurrentMediaTime()
        lastModelActionCode = -1
        clickOneShotActive = false
        clickOneShotElapsed = 0.0
        continuousActionKey = nil
        continuousActionElapsed = 0.0
        updateLoadedModel(
            node: container,
            actionCode: currentActionCode,
            actionIntensity: currentActionIntensity,
            headTintAmount: currentHeadTintAmount)
        return true
    }

    func loadActionLibrary(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let rootAny = try? JSONSerialization.jsonObject(with: data),
              let root = rootAny as? [String: Any] else {
            actionClipsByName.removeAll(keepingCapacity: true)
            clickActionClip = nil
            actionBoneRemapLower.removeAll(keepingCapacity: true)
            actionTrackNodeCache.removeAll(keepingCapacity: true)
            clickOneShotDuration = 0.30
            return false
        }

        var remapLower: [String: [String]] = [:]
        if let remap = root["bone_remap"] as? [String: Any] {
            for (key, value) in remap {
                guard let aliasesAny = value as? [Any] else {
                    continue
                }
                let aliases = aliasesAny.compactMap { $0 as? String }
                if !aliases.isEmpty {
                    remapLower[key.lowercased()] = aliases
                }
            }
        }

        var parsedClipsByName: [String: MfxActionClip] = [:]
        if let clips = root["clips"] as? [Any] {
            for clipAny in clips {
                guard let clipDict = clipAny as? [String: Any],
                      let action = clipDict["action"] as? String else {
                    continue
                }
                guard let tracksAny = clipDict["tracks"] as? [Any] else {
                    continue
                }
                var tracks: [MfxActionTrack] = []
                tracks.reserveCapacity(tracksAny.count)
                for trackAny in tracksAny {
                    guard let trackDict = trackAny as? [String: Any],
                          let bone = trackDict["bone"] as? String,
                          let keyframesAny = trackDict["keyframes"] as? [Any] else {
                        continue
                    }
                    var keyframes: [MfxActionKeyframe] = []
                    keyframes.reserveCapacity(keyframesAny.count)
                    for keyAny in keyframesAny {
                        guard let keyDict = keyAny as? [String: Any],
                              let tValue = keyDict["t"] as? NSNumber else {
                            continue
                        }
                        var rotation: simd_quatf?
                        if let rotAny = keyDict["rot"] as? [Any], rotAny.count >= 4,
                           let x = rotAny[0] as? NSNumber,
                           let y = rotAny[1] as? NSNumber,
                           let z = rotAny[2] as? NSNumber,
                           let w = rotAny[3] as? NSNumber {
                            var q = simd_quatf(ix: x.floatValue, iy: y.floatValue, iz: z.floatValue, r: w.floatValue)
                            if simd_length_squared(q.vector) >= 0.000001 {
                                q = simd_normalize(q)
                                rotation = q
                            }
                        }
                        var scale: SIMD3<Float>?
                        if let scaleAny = keyDict["scale"] as? [Any], scaleAny.count >= 3,
                           let sx = scaleAny[0] as? NSNumber,
                           let sy = scaleAny[1] as? NSNumber,
                           let sz = scaleAny[2] as? NSNumber {
                            scale = SIMD3<Float>(sx.floatValue, sy.floatValue, sz.floatValue)
                        }
                        keyframes.append(MfxActionKeyframe(
                            t: CGFloat(tValue.doubleValue),
                            rotation: rotation,
                            scale: scale))
                    }
                    if keyframes.isEmpty {
                        continue
                    }
                    keyframes.sort { lhs, rhs in
                        lhs.t < rhs.t
                    }
                    tracks.append(MfxActionTrack(bone: bone, keyframes: keyframes))
                }
                if tracks.isEmpty {
                    continue
                }
                let durationValue = (clipDict["duration"] as? NSNumber)?.doubleValue ?? 0.30
                let duration = mfxClamp(CGFloat(durationValue), min: 0.05, max: 5.0)
                let loop = (clipDict["loop"] as? Bool) ?? true
                let clip = MfxActionClip(action: action, duration: duration, loop: loop, tracks: tracks)
                parsedClipsByName[mfxNormalizedActionKey(action)] = clip
            }
        }

        actionClipsByName = parsedClipsByName
        let parsedClickClip = parsedClipsByName[mfxNormalizedActionKey("clickReact")]
        clickActionClip = parsedClickClip
        actionBoneRemapLower = remapLower
        actionTrackNodeCache.removeAll(keepingCapacity: true)
        clickOneShotDuration = parsedClickClip?.duration ?? 0.30
        continuousActionKey = nil
        continuousActionElapsed = 0.0
        return !parsedClipsByName.isEmpty
    }

    func configurePoseBinding(names: [String]) -> Bool {
        guard modelLoaded else {
            return companionView.configurePoseBinding(names: names)
        }
        guard !names.isEmpty else {
            poseBindingNodesByIndex.removeAll(keepingCapacity: true)
            poseBindingHadMeaningfulDelta = false
            return false
        }
        var mapping: [[SCNNode]] = []
        mapping.reserveCapacity(names.count)
        for name in names {
            mapping.append(resolvePoseBindingNodes(for: name))
        }
        poseBindingNodesByIndex = mapping
        poseBindingHadMeaningfulDelta = false
        return poseBindingNodesByIndex.contains { !$0.isEmpty }
    }

    private func resolvePoseBindingNodes(for name: String) -> [SCNNode] {
        guard let key = Self.normalizedBoneName(name) else {
            return []
        }
        let semanticBinding = isSemanticPoseBindingKey(key)
        if let exact = boneNodesByName[key], !exact.isEmpty {
            let sortedExact = sortPoseBindingMatches(exact, key: key, containsPatterns: [key])
            if semanticBinding {
                return resolvedSemanticPoseBindingNodes(key: key, root: sortedExact[0])
            }
            return sortedExact
        }

        let containsPatterns: [String]
        switch key {
        case "left_ear":
            containsPatterns = ["ear.l", "earl", "left ear", "left_ear"]
        case "right_ear":
            containsPatterns = ["ear.r", "earr", "right ear", "right_ear"]
        case "left_hand":
            containsPatterns = ["arm.l", "hand.l", "left hand", "left_hand"]
        case "right_hand":
            containsPatterns = ["arm.r", "hand.r", "right hand", "right_hand"]
        case "left_leg":
            containsPatterns = ["leg.l", "left leg", "left_leg"]
        case "right_leg":
            containsPatterns = ["leg.r", "right leg", "right_leg"]
        default:
            containsPatterns = [key]
        }

        var matches: [SCNNode] = []
        var seen = Set<ObjectIdentifier>()
        for (candidateName, nodes) in boneNodesByName {
            guard containsPatterns.contains(where: { candidateName.contains($0) }) else {
                continue
            }
            for node in nodes {
                let nodeId = ObjectIdentifier(node)
                if seen.insert(nodeId).inserted {
                    matches.append(node)
                }
            }
        }

        if matches.isEmpty {
            return []
        }
        let sortedMatches = sortPoseBindingMatches(matches, key: key, containsPatterns: containsPatterns)
        if semanticBinding {
            return resolvedSemanticPoseBindingNodes(key: key, root: sortedMatches[0])
        }
        return sortedMatches
    }

    private func resolvedSemanticPoseBindingNodes(key: String, root: SCNNode) -> [SCNNode] {
        switch key {
        case "left_ear", "right_ear":
            return collectPoseBindingChain(from: root, maxDepth: 3)
        case "left_hand", "right_hand", "left_leg", "right_leg":
            return collectPoseBindingChain(from: root, maxDepth: 2)
        default:
            return [root]
        }
    }

    private func collectPoseBindingChain(from root: SCNNode, maxDepth: Int) -> [SCNNode] {
        let depth = max(1, maxDepth)
        var chain: [SCNNode] = [root]
        var seen: Set<ObjectIdentifier> = [ObjectIdentifier(root)]
        var cursor = root
        for _ in 1..<depth {
            let candidates = cursor.childNodes.filter { child in
                let childId = ObjectIdentifier(child)
                guard !seen.contains(childId) else {
                    return false
                }
                return Self.normalizedBoneName(child.name) != nil &&
                    restLocalTransformByNode[childId] != nil
            }
            guard let next = candidates.sorted(by: { lhs, rhs in
                let lhsY = lhs.worldPosition.y
                let rhsY = rhs.worldPosition.y
                if lhsY != rhsY {
                    return lhsY > rhsY
                }
                let lhsName = Self.normalizedBoneName(lhs.name) ?? ""
                let rhsName = Self.normalizedBoneName(rhs.name) ?? ""
                return lhsName < rhsName
            }).first else {
                break
            }
            chain.append(next)
            seen.insert(ObjectIdentifier(next))
            cursor = next
        }
        return chain
    }

    private func poseBindingDeltaWeights(
        poseBoneIndex: Int,
        nodeIndex: Int
    ) -> (position: Float, rotation: Float, scale: Float) {
        guard nodeIndex > 0 else {
            return (1.0, 1.0, 1.0)
        }
        switch poseBoneIndex {
        case MfxPoseBindingBone.leftHand.rawValue, MfxPoseBindingBone.rightHand.rawValue:
            return (0.0, 0.48, 1.0)
        case MfxPoseBindingBone.leftLeg.rawValue, MfxPoseBindingBone.rightLeg.rawValue:
            return (0.0, 0.62, 1.0)
        default:
            return (1.0, 1.0, 1.0)
        }
    }

    private func isSemanticPoseBindingKey(_ key: String) -> Bool {
        switch key {
        case "left_ear", "right_ear", "left_hand", "right_hand", "left_leg", "right_leg":
            return true
        default:
            return false
        }
    }

    private func sortPoseBindingMatches(
        _ matches: [SCNNode],
        key: String,
        containsPatterns: [String]
    ) -> [SCNNode] {
        return matches.sorted { lhs, rhs in
            let lhsName = Self.normalizedBoneName(lhs.name) ?? ""
            let rhsName = Self.normalizedBoneName(rhs.name) ?? ""
            let lhsScore = poseBindingMatchScore(name: lhsName, key: key, containsPatterns: containsPatterns)
            let rhsScore = poseBindingMatchScore(name: rhsName, key: key, containsPatterns: containsPatterns)
            if lhsScore != rhsScore {
                return lhsScore < rhsScore
            }
            return lhsName < rhsName
        }
    }

    private func poseBindingMatchScore(
        name: String,
        key: String,
        containsPatterns: [String]
    ) -> (Int, Int, Int, Int) {
        let patternRank = containsPatterns.firstIndex(where: { name.contains($0) }) ?? containsPatterns.count
        let dotCount = name.reduce(into: 0) { partialResult, character in
            if character == "." {
                partialResult += 1
            }
        }
        let exactPrefixPenalty: Int
        if name == key || name.hasPrefix(key) {
            exactPrefixPenalty = 0
        } else {
            exactPrefixPenalty = 1
        }
        return (patternRank, exactPrefixPenalty, dotCount, name.count)
    }

    private func poseBindingHasMeaningfulDelta(
        positions: [Float],
        rotations: [Float],
        scales: [Float],
        poseCount: Int
    ) -> Bool {
        guard poseCount > 0 else {
            return false
        }
        let positionThreshold: Float = 0.0001
        let rotationThreshold: Float = 0.0001
        let scaleThreshold: Float = 0.0001
        for idx in 0..<poseCount {
            let pBase = idx * 3
            let rBase = idx * 4
            if abs(positions[pBase]) > positionThreshold ||
                abs(positions[pBase + 1]) > positionThreshold ||
                abs(positions[pBase + 2]) > positionThreshold {
                return true
            }
            if abs(rotations[rBase]) > rotationThreshold ||
                abs(rotations[rBase + 1]) > rotationThreshold ||
                abs(rotations[rBase + 2]) > rotationThreshold ||
                abs(rotations[rBase + 3] - 1.0) > rotationThreshold {
                return true
            }
            if abs(scales[pBase] - 1.0) > scaleThreshold ||
                abs(scales[pBase + 1] - 1.0) > scaleThreshold ||
                abs(scales[pBase + 2] - 1.0) > scaleThreshold {
                return true
            }
        }
        return false
    }

    func applyPose(indices: [Int32], positions: [Float], rotations: [Float], scales: [Float]) {
        guard modelLoaded else {
            companionView.applyPose(indices: indices, positions: positions, rotations: rotations, scales: scales)
            return
        }
        guard modelNode != nil, !indices.isEmpty, !poseBindingNodesByIndex.isEmpty else {
            return
        }
        if clickOneShotActive {
            // Keep click window visually deterministic: one-shot press/rebound only.
            restoreAllPoseBindingNodesToRest()
            return
        }
        let poseCount = indices.count
        if positions.count < poseCount * 3 || rotations.count < poseCount * 4 || scales.count < poseCount * 3 {
            return
        }

        let hasMeaningfulDelta = poseBindingHasMeaningfulDelta(
            positions: positions,
            rotations: rotations,
            scales: scales,
            poseCount: poseCount)
        if !hasMeaningfulDelta {
            if poseBindingHadMeaningfulDelta {
                restoreAllPoseBindingNodesToRest()
                poseBindingHadMeaningfulDelta = false
            }
            return
        }
        poseBindingHadMeaningfulDelta = true

        for nodes in poseBindingNodesByIndex {
            for node in nodes {
                let nodeId = ObjectIdentifier(node)
                guard let restLocal = restLocalTransformByNode[nodeId] else {
                    continue
                }
                node.simdTransform = restLocal
            }
        }

        for idx in 0..<poseCount {
            let poseBoneIndex = Int(indices[idx])
            if poseBoneIndex < 0 || poseBoneIndex >= poseBindingNodesByIndex.count {
                continue
            }
            let nodes = poseBindingNodesByIndex[poseBoneIndex]
            if nodes.isEmpty {
                continue
            }
            let pBase = idx * 3
            let rBase = idx * 4
            for (nodeIndex, node) in nodes.enumerated() {
                let deltaWeights = poseBindingDeltaWeights(
                    poseBoneIndex: poseBoneIndex,
                    nodeIndex: nodeIndex)
                let localDelta = composeLocalDelta(
                    positionX: positions[pBase],
                    positionY: positions[pBase + 1],
                    positionZ: positions[pBase + 2],
                    rotationX: rotations[rBase],
                    rotationY: rotations[rBase + 1],
                    rotationZ: rotations[rBase + 2],
                    rotationW: rotations[rBase + 3],
                    scaleX: scales[pBase],
                    scaleY: scales[pBase + 1],
                    scaleZ: scales[pBase + 2],
                    positionWeight: deltaWeights.position,
                    rotationWeight: deltaWeights.rotation,
                    scaleWeight: deltaWeights.scale)
                let nodeId = ObjectIdentifier(node)
                guard let restLocal = restLocalTransformByNode[nodeId] else {
                    continue
                }
                node.simdTransform = simd_mul(restLocal, localDelta)
            }
        }
    }

    func moveFollow(cursorX: Int32, cursorY: Int32) {
        let desktop = resolveDesktopBounds()
        let width = max(1.0, desktop.width)
        let normalizedX = ((CGFloat(cursorX) - desktop.minX) / width) * 2.0 - 1.0
        pointerNormalizedX = mfxClamp(normalizedX, min: -1.0, max: 1.0)
        companionView.updatePointerNormalizedX(pointerNormalizedX)
        if positionMode != .relative {
            return
        }
        let cursor = NSEvent.mouseLocation
        let desired = NSPoint(
            x: cursor.x - panel.frame.width * 0.52 + offsetX,
            y: cursor.y - panel.frame.height * 0.48 + offsetY)
        panel.setFrameOrigin(applyEdgeClamp(to: desired))
    }

    private func applyCurrentPosition() {
        switch positionMode {
        case .relative:
            let cursor = NSEvent.mouseLocation
            let desired = NSPoint(
                x: cursor.x - panel.frame.width * 0.52 + offsetX,
                y: cursor.y - panel.frame.height * 0.48 + offsetY)
            panel.setFrameOrigin(applyEdgeClamp(to: desired))
        case .absolute:
            setAbsoluteOrigin()
        case .fixedBottomLeftLegacy:
            setFixedBottomLeftOrigin()
        }
    }

    private func setFixedBottomLeftOrigin() {
        let desktop = resolveDesktopBounds()
        let desired = NSPoint(
            x: desktop.minX + offsetX,
            y: desktop.minY + offsetY)
        panel.setFrameOrigin(applyEdgeClamp(to: desired))
    }

    private func setAbsoluteOrigin() {
        let screen = resolveTargetScreen() ?? NSScreen.main
        let desktop = resolveDesktopBounds()
        let targetFrame = screen?.frame ?? desktop
        let desired = NSPoint(
            x: targetFrame.minX + absoluteX,
            y: targetFrame.maxY - absoluteY - panel.frame.height)
        panel.setFrameOrigin(applyEdgeClamp(to: desired))
    }

    private func resolveTargetScreen() -> NSScreen? {
        let normalizedTarget = targetMonitor.isEmpty ? "cursor" : targetMonitor
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            return nil
        }
        if normalizedTarget == "primary" {
            let mainId = CGMainDisplayID()
            return screens.first(where: { screen in
                guard let screenNumber = screen.deviceDescription[mfxPetScreenNumberKey] as? NSNumber else {
                    return false
                }
                return CGDirectDisplayID(screenNumber.uint32Value) == mainId
            }) ?? screens.first
        }
        if normalizedTarget == "cursor" || normalizedTarget == "custom" {
            let cursor = NSEvent.mouseLocation
            return screens.first(where: { $0.frame.contains(cursor) }) ?? screens.first
        }
        if let exact = screens.first(where: { screen in
            guard let screenNumber = screen.deviceDescription[mfxPetScreenNumberKey] as? NSNumber else {
                return false
            }
            let rawId = String(screenNumber.uint32Value)
            return normalizedTarget == rawId || normalizedTarget == "monitor_\(rawId)"
        }) {
            return exact
        }
        return screens.first
    }

    private func resolveDesktopBounds() -> NSRect {
        let screens = NSScreen.screens
        guard let first = screens.first else {
            return panel.frame
        }
        var union = first.frame
        for screen in screens.dropFirst() {
            union = union.union(screen.frame)
        }
        return union
    }

    private func applyEdgeClamp(to origin: NSPoint, panelSize: CGSize? = nil) -> NSPoint {
        switch edgeClampMode {
        case .free:
            return origin
        case .strict:
            return clampToDesktop(origin, visibleRatio: 1.0, minimumVisiblePx: 0.0, panelSize: panelSize)
        case .soft:
            return clampToDesktop(origin, visibleRatio: 0.40, minimumVisiblePx: 48.0, panelSize: panelSize)
        }
    }

    private func clampToDesktop(
        _ origin: NSPoint,
        visibleRatio: CGFloat,
        minimumVisiblePx: CGFloat,
        panelSize: CGSize? = nil
    ) -> NSPoint {
        let desktop = resolveDesktopBounds()
        let size = panelSize ?? panel.frame.size
        let width = size.width
        let height = size.height
        let requiredVisibleX = min(width, max(minimumVisiblePx, width * visibleRatio))
        let requiredVisibleY = min(height, max(minimumVisiblePx, height * visibleRatio))
        let minX = desktop.minX - width + requiredVisibleX
        let minY = desktop.minY - height + requiredVisibleY
        let maxX = desktop.maxX - requiredVisibleX
        let maxY = desktop.maxY - requiredVisibleY
        return NSPoint(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY))
    }

    private func resizePanelCanvasIfNeeded(_ newSize: CGSize) {
        let snapped = CGSize(
            width: ceil(max(targetPetSizePx, newSize.width)),
            height: ceil(max(targetPetSizePx, newSize.height)))
        if abs(snapped.width - panelCanvasSize.width) < 0.5,
           abs(snapped.height - panelCanvasSize.height) < 0.5 {
            return
        }

        let oldFrame = panel.frame
        let newOrigin: NSPoint
        if positionMode == .fixedBottomLeftLegacy {
            newOrigin = NSPoint(
                x: resolveDesktopBounds().minX + offsetX,
                y: resolveDesktopBounds().minY + offsetY)
        } else if positionMode == .absolute {
            let screen = resolveTargetScreen() ?? NSScreen.main
            let desktop = resolveDesktopBounds()
            let targetFrame = screen?.frame ?? desktop
            newOrigin = NSPoint(
                x: targetFrame.minX + absoluteX,
                y: targetFrame.maxY - absoluteY - snapped.height)
        } else {
            newOrigin = NSPoint(
                x: oldFrame.midX - snapped.width * 0.5,
                y: oldFrame.midY - snapped.height * 0.5)
        }

        panelCanvasSize = snapped
        updateCameraForCurrentCanvas()
        let bounds = NSRect(origin: .zero, size: snapped)
        panel.setFrame(
            NSRect(origin: applyEdgeClamp(to: newOrigin, panelSize: snapped), size: snapped),
            display: true)
        contentView.frame = bounds
        sceneView.frame = bounds
        companionView.frame = bounds
    }

    private func updateCameraForCurrentCanvas() {
        let widthRatio = panelCanvasSize.width / max(1.0, targetPetSizePx)
        let heightRatio = panelCanvasSize.height / max(1.0, targetPetSizePx)
        let ratio = max(1.0, max(widthRatio, heightRatio))
        sceneCameraNode.position = SCNVector3(
            x: baseCameraPosition.x,
            y: baseCameraPosition.y,
            z: baseCameraPosition.z * ratio)
    }

    private func startModelFrameLoop() {
        if modelFrameTimer != nil {
            return
        }
        let timer = Timer(
            timeInterval: 1.0 / 120.0,
            target: self,
            selector: #selector(onModelFrame(_:)),
            userInfo: nil,
            repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        modelFrameTimer = timer
    }

    private func stopModelFrameLoop() {
        modelFrameTimer?.invalidate()
        modelFrameTimer = nil
    }

    private func applyScrollFacingPresentation() {
        let shouldFlip = scrollFacingHold > 0.0 && scrollFacingSign < 0.0
        sceneView.frameCenterRotation = shouldFlip ? 180.0 : 0.0
    }

    @objc
    private func onModelFrame(_ timer: Timer) {
        _ = timer
        guard modelLoaded, let modelNode else {
            return
        }
        updateLoadedModel(
            node: modelNode,
            actionCode: currentActionCode,
            actionIntensity: currentActionIntensity,
            headTintAmount: currentHeadTintAmount)
        if pendingInitialPanelFit {
            fitCanvasToModel()
            pendingInitialPanelFit = false
        }
        if pendingRuntimePanelRefitPasses > 0 {
            fitCanvasToModel()
            pendingRuntimePanelRefitPasses -= 1
        }
    }

    private func loadScene(url: URL) -> SCNScene? {
        return try? SCNScene(url: url, options: nil)
    }

    private func disableImportedAnimations(root: SCNNode) {
        root.removeAllAnimations()
        root.enumerateChildNodes { node, _ in
            node.removeAllAnimations()
        }
    }

    private func hydrateAnonymousSkeletonNamesIfNeeded(root: SCNNode, sourceURL: URL) {
        guard sourceURL.pathExtension.lowercased() == "usdz" else {
            return
        }
        guard let canonicalNames = loadCanonicalJointDescendantNames(for: sourceURL), !canonicalNames.isEmpty else {
            return
        }
        guard let skeletonContainer = findSkeletonContainer(in: root) else {
            return
        }

        var anonymousNodes: [SCNNode] = []
        collectAnonymousSkeletonNodes(from: skeletonContainer, into: &anonymousNodes)
        guard anonymousNodes.count == canonicalNames.count else {
            return
        }

        for (node, name) in zip(anonymousNodes, canonicalNames) {
            if node.name == nil || isAnonymousSkeletonNodeName(node.name) {
                node.name = name
            }
        }
    }

    private func loadCanonicalJointDescendantNames(for sourceURL: URL) -> [String]? {
        if let jsonURL = canonicalJointMetadataURL(for: sourceURL),
           let names = parseJointDescendantNamesFromJson(url: jsonURL),
           !names.isEmpty {
            return names
        }
        guard let glbURL = canonicalGlbMetadataURL(for: sourceURL) else {
            return nil
        }
        return parseJointDescendantNamesFromGlb(url: glbURL)
    }

    private func canonicalJointMetadataURL(for sourceURL: URL) -> URL? {
        let jsonURL = sourceURL.deletingPathExtension().appendingPathExtension("joints.json")
        return FileManager.default.fileExists(atPath: jsonURL.path) ? jsonURL : nil
    }

    private func canonicalGlbMetadataURL(for sourceURL: URL) -> URL? {
        let glbURL = sourceURL.deletingPathExtension().appendingPathExtension("glb")
        return FileManager.default.fileExists(atPath: glbURL.path) ? glbURL : nil
    }

    private func parseJointDescendantNamesFromJson(url: URL) -> [String]? {
        guard let data = try? Data(contentsOf: url),
              let rootAny = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        if let names = rootAny as? [String] {
            return names.isEmpty ? nil : names
        }
        if let root = rootAny as? [String: Any],
           let names = root["joint_descendant_names"] as? [String],
           !names.isEmpty {
            return names
        }
        return nil
    }

    private func parseJointDescendantNamesFromGlb(url: URL) -> [String]? {
        guard let data = try? Data(contentsOf: url),
              let root = parseGlbRootJson(data: data),
              let nodesAny = root["nodes"] as? [Any],
              let skinsAny = root["skins"] as? [Any],
              let firstSkin = skinsAny.first as? [String: Any],
              let jointsAny = firstSkin["joints"] as? [Any],
              !jointsAny.isEmpty else {
            return nil
        }

        var nodes: [MfxGlbNodeMetadata] = []
        nodes.reserveCapacity(nodesAny.count)
        for nodeAny in nodesAny {
            guard let nodeDict = nodeAny as? [String: Any] else {
                nodes.append(MfxGlbNodeMetadata(name: nil, children: []))
                continue
            }
            let name = nodeDict["name"] as? String
            let children = (nodeDict["children"] as? [Any])?.compactMap { value -> Int? in
                if let number = value as? NSNumber {
                    return number.intValue
                }
                return nil
            } ?? []
            nodes.append(MfxGlbNodeMetadata(name: name, children: children))
        }

        let jointIds = Set(jointsAny.compactMap { value -> Int? in
            if let number = value as? NSNumber {
                return number.intValue
            }
            return nil
        })
        guard !jointIds.isEmpty else {
            return nil
        }

        let rootJointId: Int
        if let skeletonValue = firstSkin["skeleton"] as? NSNumber {
            rootJointId = skeletonValue.intValue
        } else if let firstJoint = jointsAny.first as? NSNumber {
            rootJointId = firstJoint.intValue
        } else {
            return nil
        }

        var orderedNames: [String] = []
        appendJointDescendantNames(
            nodeIndex: rootJointId,
            nodes: nodes,
            jointIds: jointIds,
            includeCurrent: false,
            output: &orderedNames)
        return orderedNames.isEmpty ? nil : orderedNames
    }

    private func parseGlbRootJson(data: Data) -> [String: Any]? {
        guard data.count >= 20 else {
            return nil
        }
        let magic = readUInt32LE(data: data, offset: 0)
        let version = readUInt32LE(data: data, offset: 4)
        let fileLength = Int(readUInt32LE(data: data, offset: 8))
        guard magic == 0x46546C67, version == 2, fileLength <= data.count else {
            return nil
        }

        let jsonChunkLength = Int(readUInt32LE(data: data, offset: 12))
        let jsonChunkType = readUInt32LE(data: data, offset: 16)
        guard jsonChunkType == 0x4E4F534A else {
            return nil
        }

        let jsonStart = 20
        let jsonEnd = jsonStart + jsonChunkLength
        guard jsonChunkLength > 0, jsonEnd <= data.count else {
            return nil
        }

        let jsonData = data.subdata(in: jsonStart..<jsonEnd)
        guard let rootAny = try? JSONSerialization.jsonObject(with: jsonData),
              let root = rootAny as? [String: Any] else {
            return nil
        }
        return root
    }

    private func appendJointDescendantNames(
        nodeIndex: Int,
        nodes: [MfxGlbNodeMetadata],
        jointIds: Set<Int>,
        includeCurrent: Bool,
        output: inout [String]
    ) {
        guard nodeIndex >= 0, nodeIndex < nodes.count else {
            return
        }
        let node = nodes[nodeIndex]
        if includeCurrent, jointIds.contains(nodeIndex), let name = node.name, !name.isEmpty {
            output.append(name)
        }
        for childIndex in node.children {
            appendJointDescendantNames(
                nodeIndex: childIndex,
                nodes: nodes,
                jointIds: jointIds,
                includeCurrent: true,
                output: &output)
        }
    }

    private func findSkeletonContainer(in root: SCNNode) -> SCNNode? {
        var match: SCNNode?
        root.enumerateChildNodes { node, stop in
            guard let name = node.name?.lowercased(), name == "skeleton" else {
                return
            }
            match = node
            stop.pointee = true
        }
        return match
    }

    private func collectAnonymousSkeletonNodes(from node: SCNNode, into output: inout [SCNNode]) {
        for child in node.childNodes {
            if isAnonymousSkeletonNodeName(child.name) {
                output.append(child)
            }
            collectAnonymousSkeletonNodes(from: child, into: &output)
        }
    }

    private func isAnonymousSkeletonNodeName(_ value: String?) -> Bool {
        guard let value else {
            return false
        }
        guard value.hasPrefix("n") else {
            return false
        }
        return Int(value.dropFirst()) != nil
    }

    private func readUInt32LE(data: Data, offset: Int) -> UInt32 {
        let b0 = UInt32(data[offset + 0])
        let b1 = UInt32(data[offset + 1]) << 8
        let b2 = UInt32(data[offset + 2]) << 16
        let b3 = UInt32(data[offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }

    private func containsRenderableGeometry(root: SCNNode) -> Bool {
        var hasRenderable = false
        root.enumerateChildNodes { node, stop in
            guard let geometry = node.geometry else {
                return
            }
            if !geometry.sources(for: .vertex).isEmpty {
                hasRenderable = true
                stop.pointee = true
            }
        }
        return hasRenderable
    }

    private func rebuildBoneNodeIndex(root: SCNNode) {
        boneNodesByName.removeAll(keepingCapacity: true)
        restLocalTransformByNode.removeAll(keepingCapacity: true)
        actionTrackNodeCache.removeAll(keepingCapacity: true)
        root.enumerateChildNodes { node, _ in
            guard let key = Self.normalizedBoneName(node.name), !key.isEmpty else {
                return
            }
            self.boneNodesByName[key, default: []].append(node)
            self.restLocalTransformByNode[ObjectIdentifier(node)] = node.simdTransform
        }
    }

    private func resolveSemanticCoreBones() {
        semanticHeadNodes = resolveSemanticNodes(
            exactCandidates: ["head", "face", "kao", "neck", "頭", "顔"],
            fallbackContains: ["head", "face", "kao", "neck", "頭", "顔"],
            limit: 1)
        if let headNode = semanticHeadNodes.first,
           let chestAncestor = findAncestorSemanticNode(
            from: headNode,
            exactCandidates: ["chest", "upperchest", "spine2", "spine.002", "spine", "torso", "body"],
            fallbackContains: ["chest", "spine", "torso", "body"]) {
            semanticChestNodes = [chestAncestor]
            return
        }
        semanticChestNodes = resolveSemanticNodes(
            exactCandidates: ["chest", "upperchest", "spine2", "spine.002", "spine", "torso", "body"],
            fallbackContains: ["chest", "spine", "torso", "body"],
            limit: 1)
    }

    private func findAncestorSemanticNode(
        from node: SCNNode,
        exactCandidates: [String],
        fallbackContains: [String]
    ) -> SCNNode? {
        let exactKeys = Set(exactCandidates.compactMap { Self.normalizedBoneName($0) })
        let containsKeys = fallbackContains.map { $0.lowercased() }
        var current = node.parent
        while let candidate = current {
            if let key = Self.normalizedBoneName(candidate.name) {
                if exactKeys.contains(key) || containsKeys.contains(where: { key.contains($0) }) {
                    return candidate
                }
            }
            current = candidate.parent
        }
        return nil
    }

    private func resolveSemanticNodes(
        exactCandidates: [String],
        fallbackContains: [String],
        limit: Int
    ) -> [SCNNode] {
        var nodes: [SCNNode] = []
        for name in exactCandidates {
            guard let key = Self.normalizedBoneName(name), let matched = boneNodesByName[key], !matched.isEmpty else {
                continue
            }
            nodes.append(contentsOf: matched)
            if nodes.count >= limit {
                break
            }
        }
        if nodes.isEmpty {
            for (key, matched) in boneNodesByName {
                if fallbackContains.contains(where: { key.contains($0.lowercased()) }) {
                    nodes.append(contentsOf: matched)
                }
            }
        }
        if nodes.isEmpty {
            return []
        }
        let sorted = nodes.sorted { lhs, rhs in
            lhs.worldPosition.y > rhs.worldPosition.y
        }
        return Array(sorted.prefix(max(0, limit)))
    }

    private func restoreNodesToRest(_ nodes: [SCNNode]) {
        for node in nodes {
            let nodeId = ObjectIdentifier(node)
            guard let rest = restLocalTransformByNode[nodeId] else {
                continue
            }
            node.simdTransform = rest
        }
    }

    private func restoreAllPoseBindingNodesToRest() {
        for nodes in poseBindingNodesByIndex {
            restoreNodesToRest(nodes)
        }
    }

    private func restoreSemanticCoreNodesToRest() {
        restoreNodesToRest(semanticChestNodes)
        restoreNodesToRest(semanticHeadNodes)
    }

    private func restoreClickActionClipNodesToRest() {
        guard let clip = clickActionClip else {
            return
        }
        var restoredNodeIds = Set<ObjectIdentifier>()
        for track in clip.tracks {
            let nodes = resolveActionTrackNodes(track.bone)
            for node in nodes {
                let nodeId = ObjectIdentifier(node)
                if restoredNodeIds.contains(nodeId) {
                    continue
                }
                restoredNodeIds.insert(nodeId)
                guard let rest = restLocalTransformByNode[nodeId] else {
                    continue
                }
                node.simdTransform = rest
            }
        }
    }

    private func restoreActionClipNodesToRest(_ clip: MfxActionClip) {
        var restoredNodeIds = Set<ObjectIdentifier>()
        for track in clip.tracks {
            let nodes = resolveActionTrackNodes(track.bone)
            for node in nodes {
                let nodeId = ObjectIdentifier(node)
                if restoredNodeIds.contains(nodeId) {
                    continue
                }
                restoredNodeIds.insert(nodeId)
                guard let rest = restLocalTransformByNode[nodeId] else {
                    continue
                }
                node.simdTransform = rest
            }
        }
    }

    private func continuousClipKey(for actionCode: Int32) -> String? {
        if actionCode == MfxMouseCompanionActionCode.follow.rawValue {
            return nil
        }
        return mfxNormalizedActionKey("idle")
    }

    private func resolveActionTrackNodes(_ boneName: String) -> [SCNNode] {
        let key = boneName.lowercased()
        if let cached = actionTrackNodeCache[key] {
            return cached
        }
        let resolved = resolveActionTrackNodesInternal(boneName, visited: Set([key]))
        actionTrackNodeCache[key] = resolved
        return resolved
    }

    private func resolveActionTrackNodesInternal(_ boneName: String, visited: Set<String>) -> [SCNNode] {
        guard let lower = Self.normalizedBoneName(boneName) else {
            return []
        }
        if let exact = boneNodesByName[lower], !exact.isEmpty {
            return [exact[0]]
        }

        if lower == "chest" {
            if !semanticChestNodes.isEmpty {
                return [semanticChestNodes[0]]
            }
            let fallback = resolveSemanticNodes(
                exactCandidates: ["chest", "upperchest", "spine2", "spine.002", "spine", "torso", "body"],
                fallbackContains: ["chest", "spine", "torso", "body"],
                limit: 1)
            return fallback
        }
        if lower == "head" {
            if !semanticHeadNodes.isEmpty {
                return [semanticHeadNodes[0]]
            }
            let fallback = resolveSemanticNodes(
                exactCandidates: ["head", "face", "kao", "neck", "頭", "顔"],
                fallbackContains: ["head", "face", "kao", "neck", "頭", "顔"],
                limit: 1)
            return fallback
        }
        if lower == "spine" {
            let fallback = resolveSemanticNodes(
                exactCandidates: ["spine", "spine1", "spine01", "hips", "pelvis", "root", "torso", "body"],
                fallbackContains: ["spine", "hips", "pelvis", "root", "torso", "body"],
                limit: 1)
            return fallback
        }

        var containsMatches: [SCNNode] = []
        for (candidateName, nodes) in boneNodesByName where candidateName.contains(lower) {
            containsMatches.append(contentsOf: nodes)
        }
        if !containsMatches.isEmpty {
            let sorted = containsMatches.sorted { lhs, rhs in
                lhs.worldPosition.y > rhs.worldPosition.y
            }
            return [sorted[0]]
        }

        if let aliases = actionBoneRemapLower[lower] {
            for alias in aliases {
                guard let aliasLower = Self.normalizedBoneName(alias), !visited.contains(aliasLower) else {
                    continue
                }
                var nextVisited = visited
                nextVisited.insert(aliasLower)
                let mapped = resolveActionTrackNodesInternal(alias, visited: nextVisited)
                if !mapped.isEmpty {
                    return mapped
                }
            }
        }

        return []
    }

    private func sampleActionTrack(_ track: MfxActionTrack, localTime: CGFloat) -> MfxActionTrackSample {
        let keyframes = track.keyframes
        if keyframes.isEmpty {
            return MfxActionTrackSample(rotation: nil, scale: nil)
        }
        if keyframes.count == 1 {
            return MfxActionTrackSample(rotation: keyframes[0].rotation, scale: keyframes[0].scale)
        }

        let first = keyframes[0]
        let last = keyframes[keyframes.count - 1]
        if localTime <= first.t {
            return MfxActionTrackSample(rotation: first.rotation, scale: first.scale)
        }
        if localTime >= last.t {
            return MfxActionTrackSample(rotation: last.rotation, scale: last.scale)
        }

        var left = 0
        var right = keyframes.count - 1
        while left <= right {
            let mid = (left + right) >> 1
            if keyframes[mid].t <= localTime {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }

        let a = keyframes[max(0, right)]
        let b = keyframes[min(keyframes.count - 1, right + 1)]
        let span = max(0.000001, b.t - a.t)
        let alpha = Float(mfxClamp((localTime - a.t) / span, min: 0.0, max: 1.0))

        var sampledRotation: simd_quatf?
        if a.rotation != nil || b.rotation != nil {
            let qa = a.rotation ?? simd_quatf(angle: 0.0, axis: SIMD3<Float>(0.0, 1.0, 0.0))
            let qb = b.rotation ?? qa
            sampledRotation = simd_normalize(simd_slerp(qa, qb, alpha))
        }

        var sampledScale: SIMD3<Float>?
        if a.scale != nil || b.scale != nil {
            let sa = a.scale ?? SIMD3<Float>(1.0, 1.0, 1.0)
            let sb = b.scale ?? sa
            sampledScale = sa + (sb - sa) * alpha
        }

        return MfxActionTrackSample(rotation: sampledRotation, scale: sampledScale)
    }

    private func applyClickActionClipPose(localTime: CGFloat) -> Bool {
        guard let clip = clickActionClip else {
            return false
        }
        return applyActionClipPose(clip, localTime: localTime)
    }

    private func applyActionClipPose(_ clip: MfxActionClip, localTime: CGFloat) -> Bool {
        let t = mfxClamp(localTime, min: 0.0, max: clip.duration)
        var anyApplied = false

        for track in clip.tracks {
            let nodes = resolveActionTrackNodes(track.bone)
            if nodes.isEmpty {
                continue
            }
            let sample = sampleActionTrack(track, localTime: t)
            for node in nodes {
                let nodeId = ObjectIdentifier(node)
                guard let rest = restLocalTransformByNode[nodeId] else {
                    continue
                }
                let rotation = sample.rotation ?? simd_quatf(angle: 0.0, axis: SIMD3<Float>(0.0, 1.0, 0.0))
                let scale = sample.scale ?? SIMD3<Float>(1.0, 1.0, 1.0)
                let delta = composeLocalDelta(
                    positionX: 0.0,
                    positionY: 0.0,
                    positionZ: 0.0,
                    rotationX: rotation.vector.x,
                    rotationY: rotation.vector.y,
                    rotationZ: rotation.vector.z,
                    rotationW: rotation.vector.w,
                    scaleX: scale.x,
                    scaleY: scale.y,
                    scaleZ: scale.z)
                node.simdTransform = simd_mul(rest, delta)
                anyApplied = true
            }
        }

        return anyApplied
    }

    private func applyContinuousActionClipIfNeeded(actionCode: Int32, dt: CGFloat) {
        guard let nextKey = continuousClipKey(for: actionCode) else {
            if let previousKey = continuousActionKey,
                let previousClip = actionClipsByName[previousKey] {
                restoreActionClipNodesToRest(previousClip)
            }
            continuousActionKey = nil
            continuousActionElapsed = 0.0
            return
        }
        guard let clip = actionClipsByName[nextKey] else {
            continuousActionKey = nil
            continuousActionElapsed = 0.0
            return
        }
        if continuousActionKey != nextKey {
            continuousActionKey = nextKey
            continuousActionElapsed = 0.0
        } else {
            continuousActionElapsed += dt
        }
        let localTime: CGFloat
        if clip.loop {
            localTime =
                clip.duration > 0.0001
                ? continuousActionElapsed.truncatingRemainder(dividingBy: clip.duration)
                : 0.0
        } else {
            localTime = mfxClamp(continuousActionElapsed, min: 0.0, max: clip.duration)
        }
        restoreActionClipNodesToRest(clip)
        _ = applyActionClipPose(clip, localTime: localTime)
    }

    private func applyIdleProceduralToLoadedModel(idleProfile: CGFloat) {
        guard idleProfile > 0.001 else {
            return
        }

        let earWave = Float(sin(Double(modelBobTime * 5.2))) * 0.22
        let handWave = Float(sin(Double(modelBobTime * 4.1 + 1.2))) * 0.16

        applyProceduralBoneRotation(
            binding: .leftEar,
            rotationX: 0.0,
            rotationY: 0.0,
            rotationZ: earWave)
        applyProceduralBoneRotation(
            binding: .rightEar,
            rotationX: 0.0,
            rotationY: 0.0,
            rotationZ: -earWave)
        applyProceduralBoneRotation(
            binding: .leftHand,
            rotationX: -handWave * 0.7,
            rotationY: 0.0,
            rotationZ: handWave * 0.35)
        applyProceduralBoneRotation(
            binding: .rightHand,
            rotationX: handWave * 0.7,
            rotationY: 0.0,
            rotationZ: -handWave * 0.35)
    }

    private func applyProceduralBoneRotation(
        binding: MfxPoseBindingBone,
        rotationX: Float,
        rotationY: Float,
        rotationZ: Float
    ) {
        let index = binding.rawValue
        guard index >= 0, index < poseBindingNodesByIndex.count else {
            return
        }
        let nodes = poseBindingNodesByIndex[index]
        if nodes.isEmpty {
            return
        }
        let proceduralNodes: [SCNNode]
        switch binding {
        case .leftEar, .rightEar:
            // Idle ear sway should only drive the representative ear-root node.
            // Replaying the same procedural delta on every matched ear segment compounds
            // the motion and reads as visible jitter on multi-segment ears.
            proceduralNodes = [nodes[0]]
        default:
            proceduralNodes = nodes
        }
        let qx = rotationX * 0.5
        let qy = rotationY * 0.5
        let qz = rotationZ * 0.5
        let cx = cos(qx)
        let sx = sin(qx)
        let cy = cos(qy)
        let sy = sin(qy)
        let cz = cos(qz)
        let sz = sin(qz)
        let q = simd_quatf(
            ix: sx * cy * cz - cx * sy * sz,
            iy: cx * sy * cz + sx * cy * sz,
            iz: cx * cy * sz - sx * sy * cz,
            r: cx * cy * cz + sx * sy * sz)
        let delta = composeLocalDelta(
            positionX: 0.0,
            positionY: 0.0,
            positionZ: 0.0,
            rotationX: q.vector.x,
            rotationY: q.vector.y,
            rotationZ: q.vector.z,
            rotationW: q.vector.w,
            scaleX: 1.0,
            scaleY: 1.0,
            scaleZ: 1.0)
        for node in proceduralNodes {
            let nodeId = ObjectIdentifier(node)
            guard let restLocal = restLocalTransformByNode[nodeId] else {
                continue
            }
            node.simdTransform = simd_mul(restLocal, delta)
        }
    }

    private func normalizeModelTransform() {
        guard let modelNode else {
            return
        }
        let (minV, maxV) = modelNode.boundingBox
        let sx = maxV.x - minV.x
        let sy = maxV.y - minV.y
        let sz = maxV.z - minV.z
        let fitX = sx * 1.14
        let fitY = sy * 1.24
        let fitZ = sz * 1.12
        let maxDim = max(0.001, max(fitX, max(fitY, fitZ)))
        if !sx.isFinite || !sy.isFinite || !sz.isFinite || maxDim < 0.001 {
            modelBaseScale = 1.0
            modelNode.scale = SCNVector3(x: modelBaseScale, y: modelBaseScale, z: modelBaseScale)
            modelNode.position = SCNVector3Zero
            modelBasePosition = modelNode.position
            modelNode.eulerAngles = SCNVector3(x: 0.0, y: modelFacingYaw, z: 0.0)
            return
        }

        let targetSizeScale = max(0.20, targetPetSizePx / max(1.0, defaultPetReferenceSizePx))
        modelBaseScale = min(10.0, max(0.02, (0.70 * targetSizeScale) / maxDim))
        modelNode.scale = SCNVector3(x: modelBaseScale, y: modelBaseScale, z: modelBaseScale)
        let cx = (minV.x + maxV.x) * 0.5
        let cy = (minV.y + maxV.y) * 0.5
        let cz = (minV.z + maxV.z) * 0.5
        let verticalLift = sy * modelBaseScale * 0.08
        modelNode.position = SCNVector3(
            x: -(cx * modelBaseScale),
            y: -(cy * modelBaseScale) + verticalLift,
            z: -(cz * modelBaseScale))
        modelBasePosition = modelNode.position
        modelNode.eulerAngles = SCNVector3(x: 0.0, y: modelFacingYaw, z: 0.0)
    }

    @discardableResult
    private func fitCanvasToModel(
        preferSnapshot: Bool = true,
        usePresentation: Bool = true
    ) -> Bool {
        guard let modelNode,
              let measured = measuredRenderableBounds(
                for: modelNode,
                preferSnapshot: preferSnapshot,
                usePresentation: usePresentation)
        else {
            return false
        }
        resizePanelCanvasIfNeeded(
            CGSize(
                width: measured.width * 1.5,
                height: measured.height * 3.0))
        recenterModelInCanvas(modelNode, usePresentation: usePresentation)
        return true
    }

    private func recenterModelInCanvas(_ node: SCNNode, usePresentation: Bool = true) {
        guard let projected = measuredRenderableBounds(
            for: node,
            preferSnapshot: false,
            usePresentation: usePresentation)
        else {
            return
        }
        let deltaX = panelCanvasSize.width * 0.5 - projected.midX
        let deltaY = panelCanvasSize.height * 0.5 - projected.midY
        if abs(deltaX) < 0.5, abs(deltaY) < 0.5 {
            return
        }

        let anchorPosition = usePresentation ? node.presentation.position : node.position
        let anchor = sceneView.projectPoint(anchorPosition)
        let shifted = SCNVector3(
            x: anchor.x + deltaX,
            y: anchor.y - deltaY,
            z: anchor.z)
        let worldAnchor = sceneView.unprojectPoint(anchor)
        let worldShifted = sceneView.unprojectPoint(shifted)
        node.position.x += worldShifted.x - worldAnchor.x
        node.position.y += worldShifted.y - worldAnchor.y
        node.position.z += worldShifted.z - worldAnchor.z
        modelBasePosition = node.position
    }

    private func measuredRenderableBounds(
        for root: SCNNode,
        preferSnapshot: Bool = true,
        usePresentation: Bool = true
    ) -> CGRect? {
        if preferSnapshot, let snapshot = snapshotVisibleBounds() {
            return snapshot
        }
        return projectedRenderableBounds(for: root, usePresentation: usePresentation)
    }

    private func projectedRenderableBounds(for root: SCNNode, usePresentation: Bool = true) -> CGRect? {
        sceneView.layoutSubtreeIfNeeded()
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        var found = false

        root.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry, !geometry.sources(for: .vertex).isEmpty else {
                return
            }
            let (localMin, localMax) = geometry.boundingBox
            let corners = [
                SCNVector3(localMin.x, localMin.y, localMin.z),
                SCNVector3(localMin.x, localMin.y, localMax.z),
                SCNVector3(localMin.x, localMax.y, localMin.z),
                SCNVector3(localMin.x, localMax.y, localMax.z),
                SCNVector3(localMax.x, localMin.y, localMin.z),
                SCNVector3(localMax.x, localMin.y, localMax.z),
                SCNVector3(localMax.x, localMax.y, localMin.z),
                SCNVector3(localMax.x, localMax.y, localMax.z),
            ]
            for corner in corners {
                let world = usePresentation
                    ? node.presentation.convertPosition(corner, to: nil)
                    : node.convertPosition(corner, to: nil)
                let projected = sceneView.projectPoint(world)
                minX = min(minX, projected.x)
                minY = min(minY, projected.y)
                maxX = max(maxX, projected.x)
                maxY = max(maxY, projected.y)
            }
            found = true
        }

        guard found,
              minX.isFinite, minY.isFinite, maxX.isFinite, maxY.isFinite,
              maxX > minX, maxY > minY else {
            return nil
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func snapshotVisibleBounds() -> CGRect? {
        sceneView.layoutSubtreeIfNeeded()
        sceneView.needsDisplay = true
        sceneView.displayIfNeeded()
        let image = sceneView.snapshot()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        guard width > 0, height > 0 else {
            return nil
        }

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                guard let rawColor = bitmap.colorAt(x: x, y: y),
                      let color = rawColor.usingColorSpace(.deviceRGB) else {
                    continue
                }
                if color.alphaComponent < 0.05 {
                    continue
                }
                if x < minX { minX = x }
                if y < minY { minY = y }
                if x > maxX { maxX = x }
                if y > maxY { maxY = y }
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return nil
        }

        let scaleX = max(0.0001, image.size.width / CGFloat(width))
        let scaleY = max(0.0001, image.size.height / CGFloat(height))
        let bounds = CGRect(
            x: CGFloat(minX) * scaleX,
            y: CGFloat(minY) * scaleY,
            width: CGFloat(maxX - minX + 1) * scaleX,
            height: CGFloat(maxY - minY + 1) * scaleY)

        let widthCoverage = bounds.width / max(1.0, panelCanvasSize.width)
        let heightCoverage = bounds.height / max(1.0, panelCanvasSize.height)
        if widthCoverage > 0.97, heightCoverage > 0.97 {
            return nil
        }
        return bounds
    }

    private func updateLoadedModel(
        node: SCNNode,
        actionCode: Int32,
        actionIntensity: Float,
        headTintAmount: Float
    ) {
        let now = CACurrentMediaTime()
        let dt = CGFloat(max(0.0, min(0.05, now - modelLastTick)))
        modelLastTick = now
        modelBobTime += dt
        scrollFacingHold = max(0.0, scrollFacingHold - dt)
        applyScrollFacingPresentation()

        let resolvedIntensity = CGFloat(mfxClamp(abs(CGFloat(actionIntensity)), min: 0.0, max: 1.0))
        let oneShotDuration = mfxClamp(clickOneShotDuration, min: 0.05, max: 5.0)
        if clickOneShotActive {
            clickOneShotElapsed += dt
            if clickOneShotElapsed >= oneShotDuration {
                clickOneShotElapsed = oneShotDuration
                clickOneShotActive = false
            }
        }
        let clickTime = mfxClamp(clickOneShotElapsed, min: 0.0, max: oneShotDuration)
        let clickPeakTime: CGFloat = 0.055
        let effectiveActionCode = clickOneShotActive
            ? MfxMouseCompanionActionCode.clickReact.rawValue
            : actionCode
        let idleProfile = (effectiveActionCode == MfxMouseCompanionActionCode.idle.rawValue) ? resolvedIntensity : 0.0

        if effectiveActionCode != lastModelActionCode {
            lastModelActionCode = effectiveActionCode
            if mfxShouldRunActionPulse(effectiveActionCode) {
                runActionPulse(node: node, actionCode: effectiveActionCode, intensity: actionIntensity)
            }
        }

        if clickOneShotActive {
            node.eulerAngles.x = 0.0
            node.eulerAngles.y = modelFacingYaw
            node.position = modelBasePosition
        } else {
            let dragLean = (effectiveActionCode == MfxMouseCompanionActionCode.drag.rawValue) ? (resolvedIntensity * 0.05) : 0.0
            let followProfile = (effectiveActionCode == MfxMouseCompanionActionCode.follow.rawValue) ? resolvedIntensity : 0.0
            let followLean = 0.0 * followProfile
            let dragYaw = (effectiveActionCode == MfxMouseCompanionActionCode.drag.rawValue) ? (-0.20 * resolvedIntensity) : 0.0
            let facingYaw = modelFacingYaw
            node.eulerAngles.x = -dragLean - followLean
            node.eulerAngles.y = facingYaw + dragYaw

            let bobStrength =
                (effectiveActionCode == MfxMouseCompanionActionCode.idle.rawValue)
                ? (0.004 + resolvedIntensity * 0.006)
                : (followProfile > 0.0 ? 0.0 : (0.010 + resolvedIntensity * 0.012))
            let sway = sin(Double(modelBobTime * 2.0)) * Double(bobStrength)
            let idleLift = cos(Double(modelBobTime * 2.4)) * Double(idleProfile * 0.014)
            let walkBob = 0.0
            node.position.x = modelBasePosition.x + CGFloat(sway)
            node.position.y = modelBasePosition.y + CGFloat(idleLift + walkBob)
            node.position.z = modelBasePosition.z
        }
        node.scale.x = modelBaseScale
        node.scale.y = modelBaseScale
        node.scale.z = modelBaseScale

        if clickOneShotActive {
            restoreClickActionClipNodesToRest()
        } else {
            applyContinuousActionClipIfNeeded(actionCode: effectiveActionCode, dt: dt)
            applyIdleProceduralToLoadedModel(idleProfile: idleProfile)
        }
        let clipApplied = clickOneShotActive && applyClickActionClipPose(localTime: clickTime)
        if !clipApplied && clickOneShotActive {
            restoreSemanticCoreNodesToRest()
            let clickStrength = mfxClamp(max(0.72, resolvedIntensity), min: 0.0, max: 1.0)
            var chestScaleX: CGFloat = 1.0
            var chestScaleY: CGFloat = 1.0
            var chestScaleZ: CGFloat = 1.0
            if clickTime <= clickPeakTime {
                let a = mfxClamp(clickTime / clickPeakTime, min: 0.0, max: 1.0)
                let eased = a * a * (3.0 - 2.0 * a)
                chestScaleX = 1.0 + 0.06 * eased * clickStrength
                chestScaleY = 1.0 - 0.08 * eased * clickStrength
                chestScaleZ = 1.0 + 0.06 * eased * clickStrength
            } else {
                let b = mfxClamp((clickTime - clickPeakTime) / max(0.001, oneShotDuration - clickPeakTime), min: 0.0, max: 1.0)
                let eased = b * b * (3.0 - 2.0 * b)
                chestScaleX = (1.06 - 0.06 * eased) * clickStrength + (1.0 - clickStrength)
                chestScaleY = (0.92 + 0.08 * eased) * clickStrength + (1.0 - clickStrength)
                chestScaleZ = (1.06 - 0.06 * eased) * clickStrength + (1.0 - clickStrength)
            }
            for chest in semanticChestNodes {
                chest.scale.x *= chestScaleX
                chest.scale.y *= chestScaleY
                chest.scale.z *= chestScaleZ
            }
        }
        if !clickOneShotActive && effectiveActionCode == MfxMouseCompanionActionCode.holdReact.rawValue {
            restoreSemanticCoreNodesToRest()
            let holdStrength = mfxClamp(resolvedIntensity, min: 0.0, max: 1.0)
            let squatEase = holdStrength * holdStrength * (3.0 - 2.0 * holdStrength)
            for chest in semanticChestNodes {
                chest.eulerAngles.x -= 0.008 * squatEase
                chest.scale.x *= 1.0 + 0.05 * squatEase
                chest.scale.y *= 1.0 - 0.08 * squatEase
                chest.scale.z *= 1.0 + 0.04 * squatEase
            }
            for head in semanticHeadNodes {
                head.eulerAngles.x += 0.008 * squatEase
            }
        }

        let tint = mfxClamp(CGFloat(headTintAmount), min: 0.0, max: 1.0)
        applyHeadTint(tintAmount: tint)
    }

    private func beginClickOneShot() {
        clickOneShotActive = true
        clickOneShotDuration = mfxClamp(clickActionClip?.duration ?? 0.30, min: 0.05, max: 5.0)
        clickOneShotElapsed = 0.0
        continuousActionKey = nil
        continuousActionElapsed = 0.0
        restoreAllPoseBindingNodesToRest()
    }

    private func runActionPulse(node: SCNNode, actionCode: Int32, intensity: Float) {
        if !mfxShouldRunActionPulse(actionCode) {
            return
        }
        node.removeAction(forKey: "mfx_action_pulse")
        let amp = CGFloat(max(0.02, min(0.12, intensity * 0.16)))
        let upDuration = 0.14
        let up = SCNAction.scale(to: modelBaseScale * (1.0 + amp), duration: upDuration)
        let down = SCNAction.scale(to: modelBaseScale, duration: 0.16)
        up.timingMode = .easeOut
        down.timingMode = .easeInEaseOut
        node.runAction(SCNAction.sequence([up, down]), forKey: "mfx_action_pulse")
    }

    private func rebuildHeadTintTargets(root: SCNNode) {
        headTintTargetNodes.removeAll(keepingCapacity: true)
        headTintBaseMultiplyByMaterial.removeAll(keepingCapacity: true)
        appliedHeadTintAmount = -1.0

        var tintableNodes: [SCNNode] = []
        root.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry, !geometry.materials.isEmpty else {
                return
            }
            tintableNodes.append(node)
        }
        guard !tintableNodes.isEmpty else {
            return
        }

        var selected = tintableNodes.filter { node in
            guard let name = node.name?.lowercased() else {
                return false
            }
            return name.contains("head") ||
                name.contains("face") ||
                name.contains("kao") ||
                name.contains("頭") ||
                name.contains("顔")
        }

        if selected.isEmpty {
            let ys = tintableNodes.map(meshWorldCenterY)
            if let minY = ys.min(), let maxY = ys.max() {
                let thresholdY = minY + (maxY - minY) * 0.5
                selected = tintableNodes.filter { meshWorldCenterY($0) >= thresholdY }
            }
        }

        if selected.isEmpty, let topmost = tintableNodes.max(by: { meshWorldCenterY($0) < meshWorldCenterY($1) }) {
            selected = [topmost]
        }

        headTintTargetNodes = selected
        for node in headTintTargetNodes {
            guard let geometry = node.geometry else {
                continue
            }
            for material in geometry.materials {
                let materialId = ObjectIdentifier(material)
                if headTintBaseMultiplyByMaterial[materialId] == nil {
                    headTintBaseMultiplyByMaterial[materialId] = resolvedMaterialMultiplyColor(material) ?? NSColor.white
                }
            }
        }
    }

    private func applyHeadTint(tintAmount: CGFloat) {
        let tint = mfxClamp(tintAmount, min: 0.0, max: 1.0)
        if abs(tint - appliedHeadTintAmount) < 0.0001 {
            return
        }
        for child in headTintTargetNodes {
            guard let geometry = child.geometry else {
                continue
            }
            for material in geometry.materials {
                let materialId = ObjectIdentifier(material)
                let baseColor = headTintBaseMultiplyByMaterial[materialId] ?? NSColor.white
                material.multiply.contents = blendedColor(
                    from: baseColor,
                    to: headTintColor,
                    amount: tint)
            }
        }
        appliedHeadTintAmount = tint
    }

    private func meshWorldCenterY(_ node: SCNNode) -> CGFloat {
        guard let geometry = node.geometry else {
            return CGFloat(node.presentation.worldPosition.y)
        }
        let (localMin, localMax) = geometry.boundingBox
        let center = SCNVector3(
            (localMin.x + localMax.x) * 0.5,
            (localMin.y + localMax.y) * 0.5,
            (localMin.z + localMax.z) * 0.5)
        let world = node.presentation.convertPosition(center, to: nil)
        return CGFloat(world.y)
    }

    private func resolvedMaterialMultiplyColor(_ material: SCNMaterial) -> NSColor? {
        if let color = material.multiply.contents as? NSColor {
            return color.usingColorSpace(.deviceRGB) ?? color
        }
        return nil
    }

    private func blendedColor(from: NSColor, to: NSColor, amount: CGFloat) -> NSColor {
        let alpha = mfxClamp(amount, min: 0.0, max: 1.0)
        let lhs = from.usingColorSpace(.deviceRGB) ?? from
        let rhs = to.usingColorSpace(.deviceRGB) ?? to
        return NSColor(
            calibratedRed: lhs.redComponent + (rhs.redComponent - lhs.redComponent) * alpha,
            green: lhs.greenComponent + (rhs.greenComponent - lhs.greenComponent) * alpha,
            blue: lhs.blueComponent + (rhs.blueComponent - lhs.blueComponent) * alpha,
            alpha: lhs.alphaComponent + (rhs.alphaComponent - lhs.alphaComponent) * alpha)
    }

    private static func normalizedBoneName(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        return trimmed.lowercased()
    }

    private func composeLocalDelta(
        positionX: Float,
        positionY: Float,
        positionZ: Float,
        rotationX: Float,
        rotationY: Float,
        rotationZ: Float,
        rotationW: Float,
        scaleX: Float,
        scaleY: Float,
        scaleZ: Float,
        positionWeight: Float = 1.0,
        rotationWeight: Float = 1.0,
        scaleWeight: Float = 1.0
    ) -> simd_float4x4 {
        let safePositionWeight = Swift.max(0.0, Swift.min(1.0, positionWeight))
        let safeRotationWeight = Swift.max(0.0, Swift.min(1.0, rotationWeight))
        let safeScaleWeight = Swift.max(0.0, Swift.min(1.0, scaleWeight))
        var rotation = simd_quatf(ix: rotationX, iy: rotationY, iz: rotationZ, r: rotationW)
        let rotationVector = rotation.vector
        if !rotationVector.x.isFinite ||
            !rotationVector.y.isFinite ||
            !rotationVector.z.isFinite ||
            !rotationVector.w.isFinite ||
            simd_length_squared(rotationVector) < 0.000001 {
            rotation = simd_quatf(angle: 0.0, axis: SIMD3<Float>(0.0, 1.0, 0.0))
        } else {
            rotation = simd_normalize(rotation)
        }
        if safeRotationWeight < 0.999 {
            let identity = simd_quatf(angle: 0.0, axis: SIMD3<Float>(0.0, 1.0, 0.0))
            rotation = simd_normalize(simd_slerp(identity, rotation, safeRotationWeight))
        }

        var scale = SIMD3<Float>(
            scaleX.isFinite ? scaleX : 1.0,
            scaleY.isFinite ? scaleY : 1.0,
            scaleZ.isFinite ? scaleZ : 1.0)
        if scale.x == 0.0 { scale.x = 1.0 }
        if scale.y == 0.0 { scale.y = 1.0 }
        if scale.z == 0.0 { scale.z = 1.0 }
        scale = SIMD3<Float>(
            1.0 + (scale.x - 1.0) * safeScaleWeight,
            1.0 + (scale.y - 1.0) * safeScaleWeight,
            1.0 + (scale.z - 1.0) * safeScaleWeight)

        let translation = SIMD3<Float>(
            (positionX.isFinite ? positionX : 0.0) * safePositionWeight,
            (positionY.isFinite ? positionY : 0.0) * safePositionWeight,
            (positionZ.isFinite ? positionZ : 0.0) * safePositionWeight)

        var scaleMatrix = matrix_identity_float4x4
        scaleMatrix.columns.0.x = scale.x
        scaleMatrix.columns.1.y = scale.y
        scaleMatrix.columns.2.z = scale.z

        var translationMatrix = matrix_identity_float4x4
        translationMatrix.columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1.0)
        return simd_mul(simd_mul(translationMatrix, simd_float4x4(rotation)), scaleMatrix)
    }
}

// Main-actor panel registry. The C ABI still transports an opaque
// "pointer", but its bits are a registry ID, never an object address.
// Queued async operations that land after release simply miss the
// registry lookup and become no-ops, so no ordering of hide / update /
// apply_pose vs release can dereference a freed handle.
@MainActor
private var mfxMouseCompanionPanelRegistry: [UInt: MfxMouseCompanionPanelHandle] = [:]
@MainActor
private var mfxMouseCompanionPanelNextId: UInt = 1

@MainActor
private func mfxCreateMouseCompanionPanelOnMainThread(_ sizePx: Int, _ offsetX: Int, _ offsetY: Int) -> UnsafeMutableRawPointer? {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let handle = MfxMouseCompanionPanelHandle(sizePx: sizePx, offsetX: offsetX, offsetY: offsetY)
    let panelId = mfxMouseCompanionPanelNextId
    mfxMouseCompanionPanelNextId &+= 1
    mfxMouseCompanionPanelRegistry[panelId] = handle
    return UnsafeMutableRawPointer(bitPattern: panelId)
}

@MainActor
private func mfxReleaseMouseCompanionPanelOnMainThread(_ panelHandleBits: UInt) {
    guard panelHandleBits != 0 else {
        return
    }
    // Double release degrades to a no-op instead of over-releasing.
    guard let handle = mfxMouseCompanionPanelRegistry.removeValue(forKey: panelHandleBits) else {
        return
    }
    handle.closeAndCleanup()
}

@MainActor
private func mfxWithMouseCompanionPanelHandle(
    _ panelHandleBits: UInt,
    _ body: (MfxMouseCompanionPanelHandle) -> Void
) {
    guard panelHandleBits != 0 else {
        return
    }
    guard let handle = mfxMouseCompanionPanelRegistry[panelHandleBits] else {
        return
    }
    body(handle)
}

@_cdecl("mfx_macos_mouse_companion_panel_create_v1")
public func mfx_macos_mouse_companion_panel_create_v1(
    _ sizePx: Int32,
    _ offsetX: Int32,
    _ offsetY: Int32
) -> UnsafeMutableRawPointer? {
    let resolvedSize = Int(sizePx)
    let resolvedOffsetX = Int(offsetX)
    let resolvedOffsetY = Int(offsetY)

    if Thread.isMainThread {
        let bits = MainActor.assumeIsolated {
            UInt(bitPattern: mfxCreateMouseCompanionPanelOnMainThread(resolvedSize, resolvedOffsetX, resolvedOffsetY))
        }
        return UnsafeMutableRawPointer(bitPattern: bits)
    }

    var bits: UInt = 0
    DispatchQueue.main.sync {
        bits = MainActor.assumeIsolated {
            UInt(bitPattern: mfxCreateMouseCompanionPanelOnMainThread(resolvedSize, resolvedOffsetX, resolvedOffsetY))
        }
    }
    return UnsafeMutableRawPointer(bitPattern: bits)
}

@_cdecl("mfx_macos_mouse_companion_panel_release_v1")
public func mfx_macos_mouse_companion_panel_release_v1(_ panelHandle: UnsafeMutableRawPointer?) {
    let panelHandleBits = UInt(bitPattern: panelHandle)
    if panelHandleBits == 0 {
        return
    }

    if Thread.isMainThread {
        MainActor.assumeIsolated {
            mfxReleaseMouseCompanionPanelOnMainThread(panelHandleBits)
        }
        return
    }

    DispatchQueue.main.sync {
        MainActor.assumeIsolated {
            mfxReleaseMouseCompanionPanelOnMainThread(panelHandleBits)
        }
    }
}

@_cdecl("mfx_macos_mouse_companion_panel_show_v1")
public func mfx_macos_mouse_companion_panel_show_v1(_ panelHandle: UnsafeMutableRawPointer?) {
    let panelHandleBits = UInt(bitPattern: panelHandle)
    if panelHandleBits == 0 {
        return
    }

    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            mfxWithMouseCompanionPanelHandle(panelHandleBits) { handle in
                handle.show()
            }
        }
    }
}

@_cdecl("mfx_macos_mouse_companion_panel_hide_v1")
public func mfx_macos_mouse_companion_panel_hide_v1(_ panelHandle: UnsafeMutableRawPointer?) {
    let panelHandleBits = UInt(bitPattern: panelHandle)
    if panelHandleBits == 0 {
        return
    }

    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            mfxWithMouseCompanionPanelHandle(panelHandleBits) { handle in
                handle.hide()
            }
        }
    }
}

@_cdecl("mfx_macos_mouse_companion_panel_configure_v1")
public func mfx_macos_mouse_companion_panel_configure_v1(
    _ panelHandle: UnsafeMutableRawPointer?,
    _ sizePx: Int32,
    _ positionModeCode: Int32,
    _ edgeClampModeCode: Int32,
    _ offsetX: Int32,
    _ offsetY: Int32,
    _ absoluteX: Int32,
    _ absoluteY: Int32,
    _ targetMonitorUtf8: UnsafePointer<CChar>?
) {
    let panelHandleBits = UInt(bitPattern: panelHandle)
    if panelHandleBits == 0 {
        return
    }
    let targetMonitor = targetMonitorUtf8.map { String(cString: $0) } ?? "cursor"

    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            mfxWithMouseCompanionPanelHandle(panelHandleBits) { handle in
                handle.configure(
                    sizePx: sizePx,
                    positionModeCode: positionModeCode,
                    edgeClampModeCode: edgeClampModeCode,
                    offsetX: offsetX,
                    offsetY: offsetY,
                    absoluteX: absoluteX,
                    absoluteY: absoluteY,
                    targetMonitor: targetMonitor)
            }
        }
    }
}

@_cdecl("mfx_macos_mouse_companion_panel_update_v1")
public func mfx_macos_mouse_companion_panel_update_v1(
    _ panelHandle: UnsafeMutableRawPointer?,
    _ actionCode: Int32,
    _ actionIntensity: Float,
    _ headTintAmount: Float
) {
    let panelHandleBits = UInt(bitPattern: panelHandle)
    if panelHandleBits == 0 {
        return
    }

    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            mfxWithMouseCompanionPanelHandle(panelHandleBits) { handle in
                handle.update(actionCode: actionCode, actionIntensity: actionIntensity, headTintAmount: headTintAmount)
            }
        }
    }
}

@_cdecl("mfx_macos_mouse_companion_panel_move_follow_v1")
public func mfx_macos_mouse_companion_panel_move_follow_v1(
    _ panelHandle: UnsafeMutableRawPointer?,
    _ x: Int32,
    _ y: Int32
) {
    let panelHandleBits = UInt(bitPattern: panelHandle)
    if panelHandleBits == 0 {
        return
    }

    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            mfxWithMouseCompanionPanelHandle(panelHandleBits) { handle in
                handle.moveFollow(cursorX: x, cursorY: y)
            }
        }
    }
}

@_cdecl("mfx_macos_mouse_companion_panel_load_model_v1")
public func mfx_macos_mouse_companion_panel_load_model_v1(
    _ panelHandle: UnsafeMutableRawPointer?,
    _ modelPathUtf8: UnsafePointer<CChar>?
) -> Bool {
    let panelHandleBits = UInt(bitPattern: panelHandle)
    if panelHandleBits == 0 {
        return false
    }
    guard let modelPathUtf8, let path = String(validatingCString: modelPathUtf8), !path.isEmpty else {
        return false
    }

    if Thread.isMainThread {
        return MainActor.assumeIsolated {
            var loaded = false
            mfxWithMouseCompanionPanelHandle(panelHandleBits) { handle in
                loaded = handle.loadModel(path: path)
            }
            return loaded
        }
    }

    var loaded = false
    DispatchQueue.main.sync {
        MainActor.assumeIsolated {
            mfxWithMouseCompanionPanelHandle(panelHandleBits) { handle in
                loaded = handle.loadModel(path: path)
            }
        }
    }
    return loaded
}

@_cdecl("mfx_macos_mouse_companion_panel_load_action_library_v1")
public func mfx_macos_mouse_companion_panel_load_action_library_v1(
    _ panelHandle: UnsafeMutableRawPointer?,
    _ actionLibraryPathUtf8: UnsafePointer<CChar>?
) -> Bool {
    let panelHandleBits = UInt(bitPattern: panelHandle)
    if panelHandleBits == 0 {
        return false
    }
    guard let actionLibraryPathUtf8,
          let path = String(validatingCString: actionLibraryPathUtf8),
          !path.isEmpty else {
        return false
    }

    if Thread.isMainThread {
        return MainActor.assumeIsolated {
            var loaded = false
            mfxWithMouseCompanionPanelHandle(panelHandleBits) { handle in
                loaded = handle.loadActionLibrary(path: path)
            }
            return loaded
        }
    }

    var loaded = false
    DispatchQueue.main.sync {
        MainActor.assumeIsolated {
            mfxWithMouseCompanionPanelHandle(panelHandleBits) { handle in
                loaded = handle.loadActionLibrary(path: path)
            }
        }
    }
    return loaded
}

@_cdecl("mfx_macos_mouse_companion_panel_configure_pose_binding_v1")
public func mfx_macos_mouse_companion_panel_configure_pose_binding_v1(
    _ panelHandle: UnsafeMutableRawPointer?,
    _ boneNames: UnsafePointer<UnsafePointer<CChar>?>?,
    _ boneCount: Int32
) -> Bool {
    let panelHandleBits = UInt(bitPattern: panelHandle)
    if panelHandleBits == 0 || boneCount <= 0 {
        return false
    }
    var names: [String] = []
    names.reserveCapacity(Int(boneCount))
    if let boneNames {
        for i in 0..<Int(boneCount) {
            if let cName = boneNames[i] {
                names.append(String(cString: cName))
            }
        }
    }
    if names.isEmpty {
        return false
    }

    if Thread.isMainThread {
        return MainActor.assumeIsolated {
            var configured = false
            mfxWithMouseCompanionPanelHandle(panelHandleBits) { handle in
                configured = handle.configurePoseBinding(names: names)
            }
            return configured
        }
    }

    var configured = false
    DispatchQueue.main.sync {
        MainActor.assumeIsolated {
            mfxWithMouseCompanionPanelHandle(panelHandleBits) { handle in
                configured = handle.configurePoseBinding(names: names)
            }
        }
    }
    return configured
}

@_cdecl("mfx_macos_mouse_companion_panel_apply_pose_v1")
public func mfx_macos_mouse_companion_panel_apply_pose_v1(
    _ panelHandle: UnsafeMutableRawPointer?,
    _ boneIndices: UnsafePointer<Int32>?,
    _ positions: UnsafePointer<Float>?,
    _ rotations: UnsafePointer<Float>?,
    _ scales: UnsafePointer<Float>?,
    _ poseCount: Int32
) {
    let panelHandleBits = UInt(bitPattern: panelHandle)
    if panelHandleBits == 0 || poseCount <= 0 {
        return
    }
    guard let boneIndices, let positions, let rotations, let scales else {
        return
    }

    let count = Int(poseCount)
    let indicesArray = Array(UnsafeBufferPointer(start: boneIndices, count: count))
    let positionsArray = Array(UnsafeBufferPointer(start: positions, count: count * 3))
    let rotationsArray = Array(UnsafeBufferPointer(start: rotations, count: count * 4))
    let scalesArray = Array(UnsafeBufferPointer(start: scales, count: count * 3))

    if Thread.isMainThread {
        MainActor.assumeIsolated {
            mfxWithMouseCompanionPanelHandle(panelHandleBits) { handle in
                handle.applyPose(
                    indices: indicesArray,
                    positions: positionsArray,
                    rotations: rotationsArray,
                    scales: scalesArray)
            }
        }
        return
    }

    // Do not synchronously wait for main queue here.
    // Startup can call into AppController::GetConfigSnapshot() on main thread
    // while dispatch worker ticks pose updates. A sync hop would deadlock
    // (main waits worker -> worker waits main).
    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            mfxWithMouseCompanionPanelHandle(panelHandleBits) { handle in
                handle.applyPose(
                    indices: indicesArray,
                    positions: positionsArray,
                    rotations: rotationsArray,
                    scales: scalesArray)
            }
        }
    }
}
