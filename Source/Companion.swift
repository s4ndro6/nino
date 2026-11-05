import SwiftUI

/// Original vector character. Motion is decorative, never a microphone level meter.
enum CompanionMood: String, CaseIterable {
    case idle, call, dictate, read, importing, documents, timer, success, error, transcribing, thinking
    var label: String {
        switch self {
        case .idle: return "Je suis là."
        case .transcribing: return "Je transcris"
        case .thinking: return "Je réfléchis"
        case .call: return "Prêt pour l’appel"
        case .dictate: return "Je t’écoute"
        case .read: return "On lit ensemble"
        case .importing: return "Je range les mots"
        case .documents: return "Tout est à sa place"
        case .timer: return "Une chose à la fois"
        case .success: return "C’est prêt !"
        case .error: return "J’ai besoin de ton aide"
        }
    }
}
@MainActor final class NotchPresentation: ObservableObject {
    @Published var expanded = false
    @Published var cameraWidth: CGFloat = 0
    @Published var topHeight: CGFloat = 32
    @Published var preview: CompanionMood = .idle
    @Published var demo = false
    @Published var reading = false
    @Published var showTimer = false
    @Published var showCallPrompter = false
    @Published var automaticCallPrompter = UserDefaults.standard.object(forKey: "automaticCallPrompter") as? Bool ?? true {
        didSet { UserDefaults.standard.set(automaticCallPrompter, forKey: "automaticCallPrompter") }
    }
    @Published var snowEnabled = UserDefaults.standard.object(forKey: "snowEnabled") as? Bool ?? false
}
struct CompanionView: View {
    var mood: CompanionMood
    var demo = false
    var sampleTime: Double? = nil
    var energy: CompanionEnergy = .lively
    var walkPose: CompanionWalkPose? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion || sampleTime != nil)) { timeline in
            let t = sampleTime ?? (reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate)
            let current = demo ? CompanionMood.allCases[Int(t / 3) % CompanionMood.allCases.count] : mood
            Canvas { context, size in
                let scale = min(size.width / 120, size.height / 100)
                context.translateBy(x: (size.width - 120 * scale) / 2, y: (size.height - 100 * scale) / 2)
                context.scaleBy(x: scale, y: scale)
                if let walkPose {
                    Self.drawWalker(in: &context, pose: walkPose, time: t)
                    return
                }
                let active = current != .idle && current != .error
                let bounce = sin(t * (active ? 5 : 2)) * (active ? 3 : 1.2) * (energy == .calm ? 0.25 : 1)
                let blink = t.truncatingRemainder(dividingBy: 4.7) < 0.15
                func capsule(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: Color) {
                    context.fill(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: min(w,h)/2), with: .color(color))
                }
                func line(_ points: [CGPoint], _ color: Color, _ width: CGFloat = 3) {
                    var p = Path(); guard let first = points.first else { return }; p.move(to: first)
                    for point in points.dropFirst() { p.addLine(to: point) }
                    context.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                }
                let ink = Color(red: 0.08, green: 0.17, blue: 0.14)
                capsule(36, 89, 48, 4, .white.opacity(0.07))
                capsule(40, 79 + bounce, 15, 8, ninoAccent)
                capsule(65, 79 - bounce, 15, 8, ninoAccent)
                capsule(31, 26 + bounce, 58, 55, ninoAccent)
                // A soft crest, arms and feet make the entire silhouette move.
                capsule(45, 18 + bounce, 12, 17, ninoAccent)
                capsule(61, 21 + bounce, 10, 14, ninoAccent)
                let wave = current == .success ? sin(t * 9) * 10 : bounce * 1.5
                line([CGPoint(x: 33, y: 56 + bounce), CGPoint(x: 23, y: 64 + wave)], ninoAccent, 8)
                line([CGPoint(x: 87, y: 56 + bounce), CGPoint(x: 98, y: current == .success ? 31 + wave : 64 - wave)], ninoAccent, 8)
                let gaze = current == .read ? sin(t * 2) * 3 : sin(t * 0.7) * 1.5
                capsule(46 + gaze, 43 + bounce, 5, blink ? 2 : 9, ink)
                capsule(68 + gaze, 43 + bounce, 5, blink ? 2 : 9, ink)
                line([CGPoint(x: 56,y: 59 + bounce), CGPoint(x:60,y:61 + bounce), CGPoint(x:64,y:59 + bounce)], ink, 2)
                switch current {
                case .call:
                    var arc = Path(); arc.addArc(center: CGPoint(x:60,y:46 + bounce), radius:33, startAngle:.degrees(185), endAngle:.degrees(355), clockwise:false)
                    context.stroke(arc, with:.color(.white), lineWidth:4)
                    capsule(25,43 + bounce,9,20,.white); capsule(86,43 + bounce,9,20,.white)
                    line([CGPoint(x:90,y:60+bounce),CGPoint(x:82,y:69+bounce),CGPoint(x:69,y:69+bounce)],.white,2)
                case .dictate:
                    capsule(56,63,9,17,.white); line([CGPoint(x:60,y:79),CGPoint(x:60,y:87)],.white,2)
                    for i in 0..<4 { let h = 4 + abs(sin(t*5 + Double(i)))*15; capsule(100 + Double(i)*5,50-h/2,2,h,ninoAccent.opacity(0.8)) }
                case .read:
                    var book = Path(); book.move(to:CGPoint(x:39,y:64)); book.addLine(to:CGPoint(x:60,y:69)); book.addLine(to:CGPoint(x:81,y:64)); book.addLine(to:CGPoint(x:81,y:84)); book.addLine(to:CGPoint(x:60,y:89)); book.addLine(to:CGPoint(x:39,y:84)); book.closeSubpath()
                    context.fill(book,with:.color(.white)); line([CGPoint(x:60,y:69),CGPoint(x:60,y:86)],ink,1)
                    for i in 0..<3 { line([CGPoint(x:43,y:70+i*4),CGPoint(x:55,y:73+i*4)],ink.opacity(0.4),1) }
                case .importing, .documents:
                    let drift = current == .importing ? (t*20).truncatingRemainder(dividingBy:32) : 16
                    context.fill(Path(roundedRect:CGRect(x:91,y:16+drift,width:16,height:21),cornerRadius:3),with:.color(.white))
                    line([CGPoint(x:95,y:23+drift),CGPoint(x:103,y:23+drift)],ink,1)
                    capsule(91,67,21,5,ninoAccent)
                case .timer:
                    context.stroke(Path(ellipseIn:CGRect(x:89,y:25,width:25,height:25)),with:.color(.white),lineWidth:2)
                    let angle = t * 0.7
                    line([CGPoint(x:101.5,y:29),CGPoint(x:101.5,y:37.5),CGPoint(x:101.5+sin(angle)*8,y:37.5-cos(angle)*8)],.white,2)
                case .success:
                    for i in 0..<5 { let a = Double(i)*1.2+t; capsule(60+cos(a)*44,42+sin(a)*33,3,3,.white.opacity(0.7)) }
                case .error:
                    context.draw(Text("?").font(.system(size:24,weight:.semibold)).foregroundColor(.white),at:CGPoint(x:101,y:31))
                case .transcribing:
                    context.fill(Path(roundedRect: CGRect(x: 80, y: 54, width: 30, height: 33), cornerRadius: 3), with: .color(.white))
                    for i in 0..<4 {
                        let progress = (t * 1.8 + Double(i) * 0.23).truncatingRemainder(dividingBy: 1)
                        line([CGPoint(x:85,y:61+Double(i)*6),CGPoint(x:85+18*progress,y:61+Double(i)*6)],ink,2)
                    }
                case .thinking:
                    for i in 0..<3 {
                        let h = 8 + sin(t * 4 + Double(i)) * 5
                        capsule(85+Double(i)*10, 25-h, 5, 5, .white)
                    }
                    line([CGPoint(x:87,y:56+bounce),CGPoint(x:77,y:57+bounce)],ninoAccent,8)
                case .idle: break
                }
            }
        }.accessibilityLabel("Nino : \(mood.label)").allowsHitTesting(false)
    }
}

private extension CompanionView {
    /// Same silhouette, crest, palette and face as the notch mascot, with articulated limbs.
    static func drawWalker(in context: inout GraphicsContext, pose: CompanionWalkPose, time: Double) {
        let moving = pose.action == .walk || pose.action == .climb
        let climbing = pose.action == .climb
        let gait = sin(pose.phase), opposite = sin(pose.phase + .pi)
        let effort = pose.effort
        let expression = pose.expression
        let bounce = moving ? -abs(cos(pose.phase)) * 2.6 * effort : sin(time * 2) * 0.8
        let ink = Color(red: 0.08, green: 0.17, blue: 0.14)
        let far = ninoAccent.opacity(0.72)
        let curious = pose.action == .look || pose.action == .think
        let tilt = curious ? sin(pose.time * 1.4) * 7 * expression : gait * 2 * effort
        // Subtle three-quarter profile: narrow torso, offset face, far eye partly hidden.
        context.translateBy(x: 60, y: 84)
        context.scaleBy(x: pose.facing, y: 1)
        context.rotate(by: .degrees(tilt))
        context.translateBy(x: -60, y: -84)
        func capsule(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: Color) {
            context.fill(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: min(w,h) / 2), with: .color(color))
        }
        func limb(_ points: [CGPoint], _ color: Color, _ width: CGFloat = 7) {
            var path = Path(); path.move(to: points[0])
            for point in points.dropFirst() { path.addLine(to: point) }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
        func arm(near: Bool) {
            let swing = (near ? opposite : gait) * effort
            let shoulderX = near ? 72.0 : 46.0
            let elbowX = shoulderX + swing * (climbing ? 7 : 9)
            var handX = shoulderX + swing * 17
            var handY = 71 + bounce - max(0, swing) * 4
            if climbing {
                handX = shoulderX + 13
                handY = 34 + swing * 15
            } else if near && pose.action == .think {
                handX += (78 - handX) * expression; handY += (57 + bounce - handY) * expression
            } else if near && pose.action == .look {
                handX += (87 - handX) * expression; handY += (39 + bounce - handY) * expression
            } else if near && pose.action == .wave {
                handX += (90 + sin(pose.time * 10) * 6 - handX) * expression
                handY += (30 + bounce - handY) * expression
            }
            limb([CGPoint(x: shoulderX, y: 53 + bounce), CGPoint(x: elbowX, y: (handY + 53 + bounce) / 2 + 3), CGPoint(x: handX, y: handY)], near ? ninoAccent : far)
        }
        func leg(near: Bool) {
            let swing = (near ? gait : opposite) * effort
            let hipX = near ? 66.0 : 53.0
            let footX = hipX + swing * 13
            let lift = max(0, cos(pose.phase + (near ? 0 : .pi))) * 7 * effort
            let footY = climbing ? 83 - lift - 8 * effort : 85 - lift
            limb([CGPoint(x: hipX, y: 72 + bounce), CGPoint(x: hipX + swing * 5, y: 78 - lift), CGPoint(x: footX, y: footY)], near ? ninoAccent : far, 8)
            capsule(footX - 4, footY - 2, 13, 6, near ? ninoAccent : far)
        }
        arm(near: false); leg(near: false)
        capsule(36, 26 + bounce, 49, 52, ninoAccent)
        capsule(47, 18 + bounce, 12, 17, ninoAccent)
        capsule(62, 21 + bounce, 10, 14, ninoAccent)
        leg(near: true)
        let blink = time.truncatingRemainder(dividingBy: 4.7) < 0.14
        let gaze = curious ? sin(pose.time * 1.6) * 2.5 * expression : 1.0
        capsule(60 + gaze, 43 + bounce, 5, blink ? 2 : 9, ink)
        capsule(76 + gaze, 44 + bounce, 3.5, blink ? 2 : 7, ink)
        limb([CGPoint(x: 66, y: 59 + bounce), CGPoint(x: 70, y: 61 + bounce), CGPoint(x: 74, y: 59 + bounce)], ink, 2)
        capsule(74, 55 + bounce, 6, 2, Color.white.opacity(0.24))
        arm(near: true)
        if pose.action == .think {
            for i in 0..<3 {
                let delay = Double(i) * 0.55
                let alpha = min(1, max(0, pose.time - delay)) * expression
                capsule(89 + Double(i) * 8, 27 - Double(i) * 5 + sin(time * 3 + Double(i)), 3 + Double(i), 3 + Double(i), .white.opacity(alpha * 0.9))
            }
        }
    }
}
