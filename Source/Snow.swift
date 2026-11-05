import SwiftUI
import AppKit

struct SnowLedge {
    var id: String
    var x: Double
    var y: Double
    var width: Double
    var depth: [Double]
    init(id: String, x: Double, y: Double, width: Double) {
        self.id = id; self.x = x; self.y = y; self.width = width
        depth = Array(repeating: 0, count: max(1, Int(ceil(width / 8))))
    }
}
struct SnowParticle {
    var x: Double; var y: Double
    var vx: Double; var vy: Double
    var radius: Double
    var life: Double = .infinity
    var initialLife: Double = .infinity
    var isPowder: Bool { initialLife.isFinite }
    var opacity: Double { isPowder ? max(0,min(1,life / min(0.65,initialLife))) : 1 }
    static func falling(x: Double, y: Double) -> SnowParticle {
        let radius = Double.random(in:0.3...0.85)
        return SnowParticle(x:x,y:y,vx:.random(in:-5...5),vy:16+radius*13,radius:radius)
    }
}
/// Positions are screen-local, with the origin at the top left.
struct SnowWorld {
    var width: Double
    var height: Double
    var particles: [SnowParticle] = []
    var ledges: [SnowLedge] = []
    var previousMouse: CGPoint?
    var phase = 0.0
    mutating func seed() {
        particles = (0..<200).map { _ in SnowParticle.falling(x:.random(in:0...max(1,width)),y:.random(in:-40...max(1,height))) }
    }
    mutating func emitPowder(x:Double,y:Double,depth:Double,vx:Double,vy:Double) {
        let count = min(max(3,Int(depth*1.4)),12)
        for _ in 0..<count where particles.count < 1000 {
            let duration = Double.random(in:0.9...2.4)
            particles.append(SnowParticle(x:x + .random(in:-4...4),y:y + .random(in:-2...2),vx:max(-180,min(180,vx + .random(in:-30...30))),vy:max(-110,min(70,vy + .random(in:-25...20))),radius:.random(in:0.22...0.65),life:duration,initialLife:duration))
        }
    }
    mutating func setLedges(_ new: [SnowLedge]) {
        var updated = new
        for old in ledges {
            if let i = updated.firstIndex(where: { $0.id == old.id }), abs(updated[i].x-old.x)<2, abs(updated[i].y-old.y)<2, abs(updated[i].width-old.width)<2 {
                updated[i].depth = old.depth
            } else {
                // Moving, closing or covering a window releases its accumulated snow.
                for (i,h) in old.depth.enumerated() where h > 1 {
                    emitPowder(x:old.x+Double(i)*8,y:old.y-h,depth:h,vx:0,vy:15)
                }
            }
        }
        ledges = updated
    }
    mutating func step(dt raw: Double, mouse: CGPoint?) {
        let dt = min(0.05,max(0,raw)); phase += dt
        let dx = mouse.flatMap { m in previousMouse.map { m.x-$0.x } } ?? 0
        let dy = mouse.flatMap { m in previousMouse.map { m.y-$0.y } } ?? 0
        let moving = hypot(dx,dy)>0.5
        if let mouse, moving {
            for l in ledges.indices where abs(mouse.y-ledges[l].y)<35 {
                for b in ledges[l].depth.indices {
                    let x = ledges[l].x+Double(b)*8+4
                    if abs(x-mouse.x)<32, ledges[l].depth[b]>0.3 {
                        let h = ledges[l].depth[b]; ledges[l].depth[b] = 0
                        emitPowder(x:x,y:ledges[l].y-h-2,depth:h,vx:dx*5+(x-mouse.x),vy:-25-abs(dy)*2)
                    }
                }
            }
        }
        // Fine powder settles between visible flakes, forming a continuous uneven cap.
        for l in ledges.indices {
            for b in ledges[l].depth.indices {
                let drift = 0.24 + 0.1 * sin(Double(b) * 0.37 + ledges[l].x * 0.01)
                ledges[l].depth[b] = min(ledges[l].id.hasPrefix("dock-") ? 10 : 18, ledges[l].depth[b] + dt * drift)
            }
        }
        previousMouse = mouse
        for i in particles.indices {
            var p = particles[i]
            if p.isPowder {
                p.life -= dt
                if p.life <= 0 { particles[i] = p; continue }
            }
            if let mouse, moving {
                let distance = hypot(p.x-mouse.x,p.y-mouse.y)
                if distance<65 { let strength = (65-distance)/65; p.vx += dx*strength*3; p.vy += dy*strength*2 }
            }
            p.vx = max(-220,min(220,p.vx * pow(p.isPowder ? 0.96 : 0.98,dt*30))); p.vy = max(-140,min(26+p.radius*16,p.vy+12*dt))
            let oldY = p.y
            p.x += (p.vx + sin(phase+Double(i))*8)*dt; p.y += p.vy*dt
            var landed = false
            if p.vy>0 {
                for l in ledges.indices {
                    guard p.x>=ledges[l].x, p.x<ledges[l].x+ledges[l].width else { continue }
                    let bin = min(ledges[l].depth.count-1,Int((p.x-ledges[l].x)/8))
                    let surface = ledges[l].y-ledges[l].depth[bin]
                    if oldY+p.radius<=surface, p.y+p.radius>=surface {
                        for b in max(0,bin-1)...min(ledges[l].depth.count-1,bin+1) { ledges[l].depth[b] = min(ledges[l].id.hasPrefix("dock-") ? 10 : 18,ledges[l].depth[b]+(p.isPowder ? 0.03 : (b==bin ? 2.0 : 0.7))) }
                        landed = true; break
                    }
                }
            }
            if landed || p.y < -100 || p.y>height+12 || p.x < -70 || p.x>width+70 {
                if p.isPowder { p.life = 0 } else { p = SnowParticle.falling(x:.random(in:0...max(1,width)),y:.random(in:-40 ... -5)) }
            }
            particles[i] = p
        }
        particles.removeAll { $0.isPowder && $0.life <= 0 }
    }
}
final class SnowSurfaceView: NSView {
    override var isFlipped: Bool { true }
    var world: SnowWorld
    private let screenFrame: CGRect
    private var screenVisibleFrame: CGRect { NSScreen.screens.first(where: { $0.frame == screenFrame })?.visibleFrame ?? screenFrame }
    private var tick: Timer?
    private var accessibilityObserver: NSObjectProtocol?
    private var last = Date.timeIntervalSinceReferenceDate
    private var lastWindows = 0.0
    private var diagnosticTime = 0.0
    init(screen: NSScreen) {
        screenFrame = screen.frame
        world = SnowWorld(width:screen.frame.width,height:screen.frame.height)
        super.init(frame:NSRect(origin:.zero,size:screen.frame.size))
        world.seed(); if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { updateWindows() }
        accessibilityObserver = NotificationCenter.default.addObserver(forName:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil,queue:.main) { [weak self] _ in self?.configureTimer() }
    }
    required init?(coder:NSCoder) { nil }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow(); configureTimer()
    }
    private func configureTimer() {
        tick?.invalidate(); tick = nil; needsDisplay = true
        guard window != nil, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        last = Date.timeIntervalSinceReferenceDate
        let timer = Timer(timeInterval:1.0/30,repeats:true) { [weak self] _ in self?.advance() }
        RunLoop.main.add(timer,forMode:.common); tick = timer
    }
    func stop() { tick?.invalidate(); tick = nil; if let accessibilityObserver { NotificationCenter.default.removeObserver(accessibilityObserver) }; accessibilityObserver = nil }
    deinit { tick?.invalidate(); if let accessibilityObserver { NotificationCenter.default.removeObserver(accessibilityObserver) } }
    private func advance() {
        let now = Date.timeIntervalSinceReferenceDate, dt = now-last; last = now
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { configureTimer(); return }
        if now-lastWindows>0.5 { updateWindows(); lastWindows = now }
        let global = NSEvent.mouseLocation
        let mouse = screenFrame.contains(global) ? CGPoint(x:global.x-screenFrame.minX,y:screenFrame.maxY-global.y) : nil
        world.step(dt:dt,mouse:mouse); needsDisplay = true
    }
    private func updateWindows() {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly],kCGNullWindowID) as? [[String:Any]], let main = NSScreen.screens.first else { return }
        let origin = CGPoint(x:screenFrame.minX,y:main.frame.maxY-screenFrame.maxY)
        var occluders: [CGRect] = [], surfaces: [SnowLedge] = []
        for w in windows {
            guard let layer = w[kCGWindowLayer as String] as? Int, layer >= 0, layer < 25,
                  (w[kCGWindowAlpha as String] as? Double ?? 1)>0.05,
                  let data = w[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation:data as CFDictionary), rect.width>40,rect.height>20,
                  let id = w[kCGWindowNumber as String] as? Int, id != window?.windowNumber else { continue }
            let local = rect.offsetBy(dx:-origin.x,dy:-origin.y)
            // The Dock and menu-system tracking windows may cover the entire display
            // while being transparent. They must never hide application ledges.
            let coversDisplay = local.width >= world.width * 0.95 && local.height >= world.height * 0.8
            if layer > 0 && (coversDisplay || layer >= 20) {
                let actualDock = (w[kCGWindowOwnerName as String] as? String) == "Dock" && !coversDisplay && local.width > 100 && local.height < world.height*0.45
                if actualDock, local.minY>0, local.minY<world.height {
                    let lo = max(0,local.minX+8), hi = min(world.width,local.maxX-8)
                    if hi>lo { surfaces.append(SnowLedge(id:"dock-\(id)",x:lo,y:local.minY,width:hi-lo)) }
                }
                continue
            }
            defer { occluders.append(local) }
            let isDock = (w[kCGWindowOwnerName as String] as? String) == "Dock" && layer > 0 && local.width < world.width * 0.95 && local.height < world.height * 0.45
            guard (layer == 0 && rect.width>100 && rect.height>60) || isDock else { continue }
            guard local.minY>2,local.minY<world.height,local.maxX>0,local.minX<world.width else { continue }
            var intervals: [(Double,Double)] = [(max(0,local.minX+8),min(world.width,local.maxX-8))]
            for front in occluders where front.minY<=local.minY && front.maxY>local.minY-16 {
                intervals = intervals.flatMap { lo,hi -> [(Double,Double)] in
                    if front.maxX<=lo || front.minX>=hi { return [(lo,hi)] }
                    var result:[(Double,Double)] = []
                    if front.minX>lo { result.append((lo,front.minX)) }
                    if front.maxX<hi { result.append((front.maxX,hi)) }; return result
                }
            }
            for (i,range) in intervals.enumerated() where range.1-range.0>8 {
                surfaces.append(SnowLedge(id:"\(isDock ? "dock" : "window")-\(id)-\(i)",x:range.0,y:local.minY,width:range.1-range.0))
            }
        }
        // On recent macOS, CGWindowList exposes only the Dock's fullscreen hit-test
        // window. Use its reserved screen band as a conservative fallback.
        if !surfaces.contains(where: { $0.id.hasPrefix("dock-") }) {
            let prefs = UserDefaults(suiteName:"com.apple.dock")
            let reserved = screenVisibleFrame.minY-screenFrame.minY
            if reserved > 10, prefs?.bool(forKey:"autohide") != true, (prefs?.string(forKey:"orientation") ?? "bottom") == "bottom" {
                let apps = prefs?.array(forKey:"persistent-apps") as? [[String:Any]] ?? []
                let others = prefs?.array(forKey:"persistent-others")?.count ?? 0
                let identifiers = Set(apps.compactMap { ($0["tile-data"] as? [String:Any])?["bundle-identifier"] as? String })
                let extra = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.bundleIdentifier != "com.apple.finder" && !identifiers.contains($0.bundleIdentifier ?? "") }.count
                let recent = prefs?.bool(forKey:"show-recents") == true ? min(3,prefs?.array(forKey:"recent-apps")?.count ?? 0) : 0
                let count = max(3,apps.count+others+extra+recent+2)
                let configuredTile = (prefs?.object(forKey:"tilesize") as? NSNumber)?.doubleValue ?? 43
                let tile = min(max(16,configuredTile),max(16,reserved-12))
                let dockWidth = min(world.width-24,(Double(count)*(tile+5)+24)*0.94)
                surfaces.append(SnowLedge(id:"dock-reserved-band",x:(world.width-dockWidth)/2,y:world.height-reserved+4,width:dockWidth))
            }
        }
        // Keep the floor deposit outside the Dock footprint, including its rounded ends.
        var floorRanges: [(Double,Double)] = [(0,world.width)]
        for dock in surfaces where dock.id.hasPrefix("dock-") {
            let lo = max(0,dock.x-22), hi = min(world.width,dock.x+dock.width+22)
            floorRanges = floorRanges.flatMap { a,b -> [(Double,Double)] in
                if hi<=a || lo>=b { return [(a,b)] }
                var pieces:[(Double,Double)] = []
                if lo>a { pieces.append((a,lo)) }; if hi<b { pieces.append((hi,b)) }
                return pieces
            }
        }
        for (index,range) in floorRanges.enumerated() where range.1-range.0>8 {
            surfaces.append(SnowLedge(id:"floor-\(index)",x:range.0,y:world.height-2,width:range.1-range.0))
        }
        world.setLedges(surfaces.sorted { $0.y<$1.y })
        let diagnostics = NinoPaths.root.appendingPathComponent("Tests")
        if Date.timeIntervalSinceReferenceDate-diagnosticTime>2, FileManager.default.fileExists(atPath:diagnostics.appendingPathComponent("enable-snow-diagnostics").path) {
            diagnosticTime = Date.timeIntervalSinceReferenceDate
            let info: [String:Any] = ["permission":CGPreflightScreenCaptureAccess(), "ownWindow":window?.windowNumber ?? -1,"screen":[screenFrame.minX,screenFrame.minY,screenFrame.width,screenFrame.height], "visibleFrame":[screenVisibleFrame.minX,screenVisibleFrame.minY,screenVisibleFrame.width,screenVisibleFrame.height], "surfaces":world.ledges.map { ["id":$0.id,"x":$0.x,"y":$0.y,"width":$0.width,"maxDepth":$0.depth.max() ?? 0] as [String:Any] }, "windows":windows.map { ["id":$0[kCGWindowNumber as String] ?? -1,"layer":$0[kCGWindowLayer as String] ?? -1,"bounds":$0[kCGWindowBounds as String] ?? [:],"alpha":$0[kCGWindowAlpha as String] ?? 0,"own":($0[kCGWindowOwnerPID as String] as? Int)==Int(ProcessInfo.processInfo.processIdentifier),"dock":($0[kCGWindowOwnerName as String] as? String)=="Dock"] }]
            if let data = try? JSONSerialization.data(withJSONObject:info,options:[.prettyPrinted,.sortedKeys]) { try? data.write(to:diagnostics.appendingPathComponent("snow-diagnostics.json"),options:.atomic) }
        }
    }
    override func draw(_ dirtyRect:NSRect) {
        NSColor.clear.setFill(); dirtyRect.fill(using:.copy)
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        for ledge in world.ledges {
            let path = NSBezierPath()
            path.move(to:NSPoint(x:ledge.x,y:ledge.y))
            var previous = NSPoint(x:ledge.x,y:ledge.y)
            for i in 0...ledge.depth.count {
                let x = ledge.x + min(ledge.width,Double(i)*8)
                let h: Double
                if i == 0 || i == ledge.depth.count { h = 0 }
                else { h = (ledge.depth[i-1] + 2*ledge.depth[i] + ledge.depth[min(i+1,ledge.depth.count-1)]) / 4 }
                let edgeDistance = min(x-ledge.x,ledge.x+ledge.width-x)
                let blend = min(1,max(0,edgeDistance/18))
                let taper = blend*blend*(3-2*blend)
                let capped = min(h,ledge.id.hasPrefix("dock-") ? 10 : 18) * taper
                let point = NSPoint(x:x,y:ledge.y-(capped < 0.15 ? 0 : capped))
                let mid = (previous.x+point.x)/2
                path.curve(to:point,controlPoint1:NSPoint(x:mid,y:previous.y),controlPoint2:NSPoint(x:mid,y:point.y))
                previous = point
            }
            path.line(to:NSPoint(x:ledge.x+ledge.width,y:ledge.y)); path.close()
            NSColor(calibratedRed:0.96,green:0.98,blue:1,alpha:0.97).setFill(); path.fill()
        }
        for p in world.particles {
            if p.radius > 1.1 {
                NSColor.white.withAlphaComponent(0.09).setFill()
                NSBezierPath(ovalIn:NSRect(x:p.x-p.radius*1.7,y:p.y-p.radius*1.7,width:p.radius*3.4,height:p.radius*3.4)).fill()
            }
            NSColor.white.withAlphaComponent((p.isPowder ? 0.8 : min(0.85,0.3+p.radius*0.45))*p.opacity).setFill()
            NSBezierPath(ovalIn:NSRect(x:p.x-p.radius,y:p.y-p.radius,width:p.radius*2,height:p.radius*2)).fill()
        }
    }
}
@MainActor final class SnowController {
    private var panels:[NSPanel] = []
    func setEnabled(_ enabled:Bool) {
        for panel in panels { (panel.contentView as? SnowSurfaceView)?.stop(); panel.close() }; panels = []
        guard enabled else { return }
        for screen in NSScreen.screens {
            let panel = NSPanel(contentRect:screen.frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.ignoresMouseEvents = true; panel.level = .statusBar; panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]; panel.isReleasedWhenClosed = false
            panel.contentView = SnowSurfaceView(screen:screen); panel.orderFrontRegardless(); panels.append(panel)
        }
    }
}
