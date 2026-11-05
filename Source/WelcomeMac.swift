import SwiftUI

enum WelcomeScene: String, CaseIterable, Identifiable {
    case notes, capture, draft, focus
    var id: String { rawValue }
    var title: String { switch self { case .notes: return "Poser une idée"; case .capture: return "Dicter une pensée"; case .draft: return "Débloquer un sujet"; case .focus: return "Finir une chose" } }
    var icon: String { switch self { case .notes: return "note.text"; case .capture: return "waveform"; case .draft: return "sparkles"; case .focus: return "timer" } }
    var detail: String { switch self {
        case .notes: return "Un post-it sur ton bureau. Une checklist qui reste sous les yeux."
        case .capture: return "Parle, retrouve ton texte, copie-le où tu travailles."
        case .draft: return "Pose un brief. Repars avec trois prochaines actions."
        case .focus: return "Lance ton minuteur et garde ton objectif à portée de main."
    } }
    var requirement: String { switch self { case .notes:return "Disponible tout de suite · sans compte"; case .capture:return "Micro + moteur de transcription";case .draft:return "Apple Intelligence compatible";case .focus:return "Disponible immédiatement" } }
}

/// A deliberately labelled, deterministic demonstration; no microphone or account activity.
struct WelcomeMac: View {
    var energy: CompanionEnergy
    var scene: WelcomeScene = .notes
    var finished = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @NinoState private var started = Date()
    var body: some View {
        GeometryReader { geometry in
            let scale = min(1.15, max(0.5, geometry.size.width / 450))
            TimelineView(.animation(minimumInterval:1.0/24,paused:reduceMotion)) { timeline in
                let elapsed = reduceMotion ? 7.0 : max(0,timeline.date.timeIntervalSince(started))
                let progress = elapsed.truncatingRemainder(dividingBy:12)
                let phase = finished || reduceMotion ? 2 : progress < 4 ? 0 : progress < 8 ? 1 : 2
                laptop(time:elapsed,phase:phase)
                    .scaleEffect(scale,anchor:.top)
                    .frame(width:geometry.size.width,height:320 * scale,alignment:.top)
            }
        }.frame(height:330)
        .onChange(of:scene) { _,_ in started=Date() }
        .accessibilityElement(children:.ignore)
        .accessibilityLabel("Démonstration : \(scene.title). \(scene.detail) Aucun enregistrement réel.")
    }
    private func mood(_ phase:Int)->CompanionMood {
        if finished { return .success }
        switch scene { case .notes: return .documents; case .capture: return phase == 0 ? .dictate : phase == 1 ? .transcribing : .success
        case .draft: return phase < 2 ? .thinking : .success
        case .focus:return .timer }
    }
    private func laptop(time:Double,phase:Int)->some View {
        VStack(spacing:0) {
            ZStack(alignment:.top) {
                RoundedRectangle(cornerRadius:17).fill(Color(red:0.105,green:0.13,blue:0.125))
                LinearGradient(colors:[ninoAccent.opacity(0.1),.clear],startPoint:.topLeading,endPoint:.bottomTrailing).clipShape(RoundedRectangle(cornerRadius:17))
                VStack(spacing:14) {
                    HStack { Image(systemName:"apple.logo");Text("Bureau");Spacer();Image(systemName:"wifi");Image(systemName:"battery.100percent");Text("9:41") }.font(.system(size:7,weight:.medium)).foregroundStyle(.white.opacity(0.55)).padding(.horizontal,12).frame(height:20)
                    ZStack {
                        RoundedRectangle(cornerRadius:12).fill(scene == .notes ? Color.clear : Color(white:0.12)).shadow(color:.black.opacity(0.15),radius:15,y:10)
                        VStack(alignment:.leading,spacing:13) {
                            HStack(spacing:4) { ForEach(0..<3) { _ in Circle().fill(.white.opacity(0.2)).frame(width:4,height:4) };Spacer();Text("\(scene == .capture ? "Ma prochaine idée" : scene == .draft ? "Mon prochain pas" : "Une chose à la fois")").font(.system(size:7)).foregroundStyle(.secondary) }
                            if scene == .focus { focus(time:time) } else if scene == .notes { paperNote(phase: phase) } else { note(phase:phase,time:time) }
                        }.padding(17)
                    }.frame(height:171).padding(.horizontal,27)
                    Spacer(minLength:0)
                    HStack(spacing:7) { ForEach(["folder","calendar","text.alignleft","terminal","music.note"],id:\.self) { icon in Image(systemName:icon).font(.system(size:9)).foregroundStyle(.white.opacity(0.55)).frame(width:20,height:20).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:5)) } }.padding(5).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:9)).padding(.bottom,8)
                }
                HStack(spacing:7) {
                    CompanionView(mood:mood(phase),sampleTime:reduceMotion ? 0 : time,energy:energy).frame(width:39,height:32)
                    VStack(alignment:.leading,spacing:2) { Text("nino").font(.system(size:10,weight:.semibold,design:.rounded));Text(scene == .notes ? "Une idée à garder" : scene == .focus ? "Concentration" : phase == 0 ? (scene == .capture ? "À l’écoute" : "Ton brief") : phase == 1 ? "J’y travaille" : "C’est prêt").font(.system(size:7)).foregroundStyle(ninoAccent) }
                    if phase == 0 && scene == .capture {
                        HStack(spacing:2) { ForEach(0..<5) { i in Capsule().fill(ninoAccent).frame(width:2,height:4+abs(sin(time*4+Double(i)))*10) } }.frame(width:20)
                    } else { Image(systemName:scene == .focus ? "timer" : phase == 2 ? "checkmark" : "ellipsis").font(.system(size:10)).foregroundStyle(ninoAccent) }
                }.frame(width:150,height:43).background(Color(white:0.035),in:UnevenRoundedRectangle(bottomLeadingRadius:14,bottomTrailingRadius:14))
            }.frame(width:400,height:263).overlay(RoundedRectangle(cornerRadius:17).stroke(.white.opacity(0.15),lineWidth:1)).padding(6).background(Color(white:0.045),in:RoundedRectangle(cornerRadius:23))
            ZStack(alignment:.top) { RoundedRectangle(cornerRadius:3).fill(LinearGradient(colors:[Color(white:0.38),Color(white:0.16)],startPoint:.top,endPoint:.bottom)).frame(width:450,height:9);UnevenRoundedRectangle(bottomLeadingRadius:4,bottomTrailingRadius:4).fill(Color(white:0.18)).frame(width:63,height:3) }
            Text("DÉMONSTRATION · AUCUNE CAPTURE RÉELLE").font(.system(size:8,weight:.medium)).tracking(1.1).foregroundStyle(Color(white:0.38)).padding(.top,23)
        }.frame(width:450,height:320,alignment:.top)
    }
    private func paperNote(phase: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Pour demain.").font(.system(size: 16, weight: .medium, design: .rounded))
                Label("Une chose à finir", systemImage: phase == 2 ? "checkmark.square" : "square")
                Label("Une idée à garder", systemImage: "square")
                Text("Le reste peut attendre.").font(.system(size: 9)).padding(.top, 4)
            }.font(.system(size: 10)).foregroundStyle(StickyNoteColor.sand.ink)
                .padding(.horizontal, 16).padding(.top, 24).padding(.bottom, 20)
                .frame(width: 205, alignment: .leading)
                .background(StickyPaperSurface(color: .sand, folded: true))
                .overlay(alignment: .top) { StickyPaperTape().offset(y: -7) }
                .rotationEffect(.degrees(-3))
                .shadow(color: .black.opacity(0.22), radius: 7, x: 1, y: 8)
            Spacer(minLength: 0)
        }.padding(.leading, 22).padding(.top, 2)
    }
    private func note(phase:Int,time:Double)->some View {
        VStack(alignment:.leading,spacing:10) {
            HStack { Image(systemName:scene.icon).foregroundStyle(ninoAccent);Text(scene == .capture ? "Et si on simplifiait l’accueil ?" : "Un bouton déborde sur mobile.").fontWeight(.medium) }.font(.system(size:11))
            ForEach(0..<3) { i in
                let lines = scene == .capture ? ["Mon idée est devenue du texte.","Je peux la corriger, la retrouver…","…et la reprendre dans mon outil."] : ["01  Reproduire sur un petit écran.","02  Corriger la largeur du bouton.","03  Vérifier le clic et le clavier."]
                HStack { Text(lines[i]).font(.system(size:9)).foregroundStyle(.white.opacity(0.65));Spacer() }
                    .opacity(phase == 0 ? 0.13 : phase == 1 ? (time.truncatingRemainder(dividingBy:4) > Double(i) ? 1 : 0.13) : 1)
                    .offset(y:phase == 0 ? 3 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration:0.45),value:phase)
            }
            HStack { Spacer();Label(phase == 2 ? "Prêt à copier" : "En cours",systemImage:phase == 2 ? "checkmark.circle.fill" : "ellipsis").font(.system(size:8,weight:.medium)).foregroundStyle(phase == 2 ? ninoAccent : .secondary) }.padding(.top,3)
        }
    }
    private func focus(time:Double)->some View {
        HStack(spacing:22) {
            ZStack { Circle().stroke(.white.opacity(0.06),lineWidth:4);Circle().trim(from:0,to:0.78).stroke(ninoAccent,style:StrokeStyle(lineWidth:4,lineCap:.round)).rotationEffect(.degrees(-90));Text("25:00").font(.system(size:19,weight:.light,design:.monospaced)) }.frame(width:88,height:88)
            VStack(alignment:.leading,spacing:8) { Text("Terminer ma première tâche").font(.system(size:11,weight:.medium));Text("Le temps reste dans l’encoche.\nLe reste peut attendre.").font(.system(size:9)).foregroundStyle(.secondary).lineSpacing(3) }
        }.padding(.vertical,4)
    }
}
