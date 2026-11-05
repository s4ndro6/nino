import Foundation
import CoreGraphics

/// Pure choreography in screen points. Only geometry is used: no application content is read.
enum CompanionWalkAction { case walk, climb, look, think, wave }

struct CompanionWalkPose {
    var position = CGPoint.zero
    var facing = 1.0
    var phase = 0.0
    var effort = 0.0
    var time = 0.0
    var expression = 0.0
    var action = CompanionWalkAction.look
}

struct CompanionWalkRoute {
    struct Beat {
        let from: CGPoint
        let to: CGPoint
        let duration: Double
        let action: CompanionWalkAction
        let facing: Double
        let phaseStart: Double
    }
    let beats: [Beat]
    var duration: Double { beats.reduce(0) { $0 + $1.duration } }
    static let panelSize = CGSize(width: 124, height: 110)

    init(window: CGRect, screen: CGRect, variation: Int = 0) {
        // Feet are 18 points above the panel bottom. Clamp waypoints, not every animation
        // frame, so the character never walks in place against a screen boundary.
        let left = screen.minX + 62, right = max(left, screen.maxX - 62)
        let bottom = screen.minY + 18, top = max(bottom, screen.maxY - 92)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: min(right, max(left, x)), y: min(top, max(bottom, y)))
        }
        let baseLeft = point(window.minX - 18, bottom)
        let baseRight = point(window.maxX + 18, bottom)
        let ledgeLeft = point(window.minX - 18, window.maxY - 8)
        let ledgeRight = point(window.maxX + 18, window.maxY - 8)
        let desk = point(screen.minX + screen.width * (variation.isMultiple(of: 2) ? 0.68 : 0.3), bottom)
        let middle = point(window.minX + window.width * 0.58, ledgeLeft.y)
        var result: [Beat] = []
        var cursor = baseRight, facing = -1.0, phase = 0.0
        func append(_ target: CGPoint, _ action: CompanionWalkAction, pause: Double = 0) {
            let dx = target.x - cursor.x, dy = target.y - cursor.y
            let distance = hypot(dx, dy)
            if pause == 0 && distance < 1 { return }
            if abs(dx) > 1 { facing = dx < 0 ? -1 : 1 }
            let speed = action == .climb ? 95.0 : 125.0
            let duration = pause > 0 ? pause : max(0.8, distance / speed)
            result.append(Beat(from: cursor, to: target, duration: duration, action: action, facing: facing, phaseStart: phase))
            // Stride phase follows travelled distance, preventing foot sliding at takeoff.
            phase += distance / (action == .climb ? 65 : 85) * .pi * 2
            cursor = target
        }
        append(baseRight, .look, pause: 2.6)
        append(desk, .walk)
        append(desk, .think, pause: 3.4)
        append(baseLeft, .walk)
        append(baseLeft, .look, pause: 1.8)
        append(ledgeLeft, .climb)
        append(ledgeLeft, .wave, pause: 2.0)
        append(middle, .walk)
        append(middle, .look, pause: 3.0)
        append(ledgeRight, .walk)
        append(ledgeRight, .think, pause: 2.2)
        append(baseRight, .climb)
        append(baseRight, .look, pause: 1.2)
        beats = result
    }

    func sample(at elapsed: Double) -> CompanionWalkPose {
        var local = max(0, elapsed).truncatingRemainder(dividingBy: max(1, duration))
        for (index, beat) in beats.enumerated() {
            if local < beat.duration || index == beats.count - 1 {
                let p = min(1, max(0, local / beat.duration))
                // Short acceleration/deceleration, constant velocity for most of each walk.
                let ramp = 0.16
                let progress: Double
                let velocity: Double
                if p < ramp {
                    progress = p * p / (2 * ramp * (1 - ramp)); velocity = p / ramp
                } else if p > 1 - ramp {
                    progress = 1 - (1 - p) * (1 - p) / (2 * ramp * (1 - ramp)); velocity = (1 - p) / ramp
                } else {
                    progress = (p - ramp / 2) / (1 - ramp); velocity = 1
                }
                let dx = beat.to.x - beat.from.x, dy = beat.to.y - beat.from.y
                let distance = hypot(dx, dy)
                return CompanionWalkPose(
                    position: CGPoint(x: beat.from.x + dx * progress, y: beat.from.y + dy * progress),
                    facing: beat.facing,
                    phase: beat.phaseStart + distance * progress / (beat.action == .climb ? 65 : 85) * .pi * 2,
                    effort: distance > 0 ? velocity : 0,
                    time: local, expression: min(1, min(local, beat.duration - local) / 0.4), action: beat.action)
            }
            local -= beat.duration
        }
        return CompanionWalkPose()
    }
}
