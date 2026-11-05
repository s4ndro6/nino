import SwiftUI
import AppKit

extension StickyNoteColor {
    /// Opaque paper pigments, with a separate ink color for readable controls.
    var paper: Color {
        switch self {
        case .sand: return Color(red: 1.00, green: 0.88, blue: 0.44)
        case .apricot: return Color(red: 1.00, green: 0.76, blue: 0.51)
        case .rose: return Color(red: 0.98, green: 0.75, blue: 0.78)
        case .sage: return Color(red: 0.75, green: 0.88, blue: 0.71)
        case .sky: return Color(red: 0.73, green: 0.85, blue: 0.95)
        case .lavender: return Color(red: 0.84, green: 0.79, blue: 0.94)
        }
    }
    var ink: Color { Color(red: 0.18, green: 0.16, blue: 0.12) }
    var secondaryInk: Color { Color(red: 0.34, green: 0.31, blue: 0.25) }
    var tint: Color {
        switch self {
        case .sand: return Color(red: 0.49, green: 0.34, blue: 0.07)
        case .apricot: return Color(red: 0.57, green: 0.28, blue: 0.10)
        case .rose: return Color(red: 0.52, green: 0.22, blue: 0.30)
        case .sage: return Color(red: 0.20, green: 0.38, blue: 0.24)
        case .sky: return Color(red: 0.18, green: 0.34, blue: 0.48)
        case .lavender: return Color(red: 0.37, green: 0.27, blue: 0.48)
        }
    }
}

private struct StickyPaperOutline: Shape {
    var fold: CGFloat = 16
    func path(in rect: CGRect) -> Path {
        let f = min(fold, min(rect.width, rect.height) / 5)
        var path = Path()
        path.move(to: CGPoint(x: 2, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: 2), control: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - f))
        path.addLine(to: CGPoint(x: rect.maxX - f, y: rect.maxY))
        path.addLine(to: CGPoint(x: 2, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: 0, y: rect.maxY - 2), control: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: 2))
        path.addQuadCurve(to: CGPoint(x: 2, y: 0), control: .zero)
        path.closeSubpath()
        return path
    }
}

/// Static fibers: no timer, random state, external image, or per-frame animation.
private struct StickyPaperGrain: View {
    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let count = min(1800, Int(size.width * size.height / 95))
            for index in 0..<max(0, count) {
                let seed = UInt64(index &+ 1) &* 2_654_435_761
                let x = CGFloat(seed % 10_007) / 10_007 * size.width
                let y = CGFloat((seed &* 1_103_515_245 &+ 12_345) % 10_009) / 10_009 * size.height
                var fiber = Path()
                fiber.move(to: CGPoint(x: x, y: y))
                fiber.addLine(to: CGPoint(x: x + CGFloat(index % 4 + 1) * 0.35, y: y + 0.2))
                context.stroke(fiber, with: .color(index.isMultiple(of: 3) ? .white.opacity(0.18) : .brown.opacity(0.065)), lineWidth: 0.55)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct StickyPaperSurface: View {
    let color: StickyNoteColor
    var folded = true
    private var outline: StickyPaperOutline { StickyPaperOutline(fold: folded ? 16 : 3) }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                outline.fill(color.paper)
                // The glued edge is denser; the lower sheet catches warm light.
                LinearGradient(stops: [.init(color: color.tint.opacity(0.16), location: 0), .init(color: .clear, location: 0.17), .init(color: .white.opacity(0.16), location: 0.72), .init(color: color.tint.opacity(0.08), location: 1)], startPoint: .top, endPoint: .bottom)
                StickyPaperGrain()
                Rectangle().fill(.white.opacity(0.26)).frame(height: 0.7).padding(.top, 1)
                if folded {
                    Path { p in
                        let x = geometry.size.width, y = geometry.size.height
                        p.move(to: CGPoint(x: x - 16, y: y)); p.addLine(to: CGPoint(x: x - 16, y: y - 16)); p.addLine(to: CGPoint(x: x, y: y - 16)); p.closeSubpath()
                    }.fill(LinearGradient(colors: [color.paper, color.paper.opacity(0.8), .white.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: color.tint.opacity(0.25), radius: 1.6, x: -1, y: -1)
                }
            }.clipShape(outline)
                .overlay(outline.stroke(color.tint.opacity(0.18), lineWidth: 0.65))
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct StickyTapeOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 2, y: 0)); p.addLine(to: CGPoint(x: rect.width - 2, y: 0))
        for step in 1...6 { p.addLine(to: CGPoint(x: rect.width - (step.isMultiple(of: 2) ? 0 : 2), y: rect.height * CGFloat(step) / 6)) }
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        for step in (0..<6).reversed() { p.addLine(to: CGPoint(x: step.isMultiple(of: 2) ? 0 : 2, y: rect.height * CGFloat(step) / 6)) }
        p.closeSubpath(); return p
    }
}

struct StickyPaperTape: View {
    var body: some View {
        StickyTapeOutline().fill(Color(red: 1, green: 0.98, blue: 0.88).opacity(0.54))
            .overlay(StickyTapeOutline().stroke(.white.opacity(0.3), lineWidth: 0.5))
            .overlay(StickyPaperGrain().opacity(0.6))
            .frame(width: 76, height: 19).rotationEffect(.degrees(-3))
            .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
            .allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// A real AppKit drag strip leaves the text editor and toolbar free to receive clicks.
struct StickyPaperDragHandle: NSViewRepresentable {
    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
    }
    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.toolTip = "Déplacer la note"
        return view
    }
    func updateNSView(_ nsView: DragView, context: Context) {}
}
