import Foundation
import CoreGraphics

@main struct CompanionWalkTests {
    static func main() {
        // Include negative-origin external displays, small screens, and oversized/offscreen windows.
        let screens = [CGRect(x: 0, y: 40, width: 1440, height: 838), CGRect(x: -1920, y: -300, width: 1920, height: 1080), CGRect(x: 0, y: 0, width: 800, height: 550)]
        for screen in screens {
            for window in [screen.insetBy(dx: 100, dy: 80), screen.insetBy(dx: -200, dy: -200)] {
                for variant in 0..<2 {
                    let route = CompanionWalkRoute(window: window, screen: screen, variation: variant)
                    precondition(route.duration.isFinite && route.duration > 0)
                    var previous = route.sample(at: 0).position
                    var actions = Set<String>()
                    for tick in 0...Int(route.duration * 120 + 2) {
                        let sample = route.sample(at: Double(tick) / 120)
                        let origin = CGPoint(x: sample.position.x - 62, y: sample.position.y - 18)
                        precondition(origin.x >= screen.minX - 0.001 && origin.y >= screen.minY - 0.001)
                        precondition(origin.x + 124 <= screen.maxX + 0.001 && origin.y + 110 <= screen.maxY + 0.001)
                        precondition(hypot(sample.position.x - previous.x, sample.position.y - previous.y) < 2, "No jumps at route joins or loop boundary")
                        precondition((0...1).contains(sample.effort) && (0...1).contains(sample.expression))
                        precondition(sample.phase.isFinite)
                        actions.insert(String(describing: sample.action)); previous = sample.position
                    }
                    precondition(actions.isSuperset(of: ["walk", "climb", "look", "think", "wave"]))
                    var boundary = 0.0
                    for beat in route.beats {
                        let first = route.sample(at: boundary + 0.00001)
                        let last = route.sample(at: boundary + beat.duration - 0.00001)
                        precondition(first.effort < 0.001 && last.effort < 0.001, "Walks start and stop gently")
                        boundary += beat.duration
                    }
                    let next = CompanionWalkRoute(window: window, screen: screen, variation: variant + 1)
                    precondition(next.sample(at: 0).position == route.sample(at: 0).position, "Changing itinerary keeps loop endpoint")
                }
            }
        }
        print("PASS: walk continuity, screen bounds, alternate itinerary, acceleration, five gestures")
    }
}
