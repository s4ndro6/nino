import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: NinoStore
    @NinoState private var step = 0
    @StateObject private var setup = SetupModel()
    @NinoState private var profile = WorkProfile.versatile
    @NinoState private var energy = CompanionEnergy.lively
    @NinoState private var minutes = 25.0
    @NinoState private var speed = 125.0
    @NinoState private var scene = WelcomeScene.notes
    @NinoState private var firstAction = "notes"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection
    private let labels = ["Bienvenue", "Ton quotidien", "Tes outils", "Tes choix", "Ton espace"]
    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 980
            let inset:CGFloat = wide ? 38 : 24
            VStack(spacing:0) {
                header(wide:wide).padding(.horizontal,inset).padding(.top,24).padding(.bottom,18)
                ScrollView {
                    Group {
                        if wide {
                            HStack(alignment:.center,spacing:32) {
                                content(wide:true).frame(maxWidth:step == 2 || step == 3 ? 560 : 490,alignment:.leading)
                                preview.frame(maxWidth:480)
                            }.frame(maxWidth:1100).frame(minHeight:max(400,geometry.size.height-180),alignment:.center)
                        } else {
                            VStack(alignment:.leading,spacing:22) {
                                content(wide:false)
                                if step != 2 && step != 3 { preview.frame(maxWidth:480).frame(maxWidth:.infinity) }
                            }.frame(maxWidth:650)
                        }
                    }.padding(.horizontal,inset).padding(.vertical,18).frame(maxWidth:.infinity)
                }
                footer.padding(.horizontal,inset).padding(.vertical,18).background(Color(white:0.075))
            }.background(Color(red:0.075,green:0.082,blue:0.078))
        }
        .preferredColorScheme(.dark)
        .onAppear { profile=store.profile;energy=store.companionEnergy;minutes=store.timerMinutes;speed=store.wpm;store.welcomeStep=step;store.welcomeEnergy=energy }
        .onChange(of: step) { _, value in store.welcomeStep=value }
        .onChange(of: energy) { _, value in store.welcomeEnergy=value }
    }
    private func header(wide:Bool)->some View {
        VStack(spacing:18) {
            HStack(spacing:10) {
                BrandMark(size:27);Text("nino").font(.system(size:24,weight:.semibold,design:.rounded));Spacer()
                if wide { HStack(spacing:15) { ForEach(0..<labels.count) { index in HStack(spacing:7) { Text(index < step ? "✓" : String(index+1)).font(.system(size:9,weight:.semibold,design:.monospaced)).frame(width:20,height:20).background(index == step ? ninoAccent.opacity(0.15) : .white.opacity(0.04),in:Circle());Text(labels[index]).font(.system(size:11,weight:index == step ? .semibold : .regular)) }.foregroundStyle(index <= step ? ninoAccent : .secondary) } } }
                else { Text("\(step+1) / \(labels.count) · \(labels[step])").font(.system(size:12,weight:.medium)).foregroundStyle(ninoAccent) }
            }
            HStack(spacing:5) { ForEach(0..<labels.count) { i in Capsule().fill(i <= step ? ninoAccent.opacity(0.85) : .white.opacity(0.07)).frame(height:2) } }
            HStack(spacing: 12) {
                Toggle("La promenade de Nino", isOn: $store.welcomeWalkEnabled).toggleStyle(.checkbox).font(.system(size: 11)).disabled(reduceMotion || energy == .calm)
                Spacer()
                if wide { Text(reduceMotion ? "Mouvements réduits activés" : energy == .calm ? "Nino reste dans sa fenêtre" : "Il prend ses marques autour de la fenêtre").font(.system(size: 10)).foregroundStyle(.secondary) }
            }
        }
    }
    private func content(wide:Bool)->some View {
        VStack(alignment:.leading,spacing:22) {
            VStack(alignment:.leading,spacing:13) {
                Text(["BIENVENUE CHEZ TOI", "À CHACUN SON QUOTIDIEN", "JUSTE LES BONS LIENS", "C’EST TOI QUI DÉCIDES", "ON SE LANCE ?"][step]).font(.system(size:9,weight:.semibold)).tracking(1.7).foregroundStyle(ninoAccent)
                Text(["Un petit compagnon.\nDe la place pour tes idées.", "Ton métier. Ton rythme.\nTon Nino.", "Tes outils se rencontrent\nici.", "Ton travail reste à toi.\nTes choix aussi.", "Tout commence\npar une petite action."][step]).font(.system(size:wide ? 36 : 29,weight:.medium,design:.rounded)).tracking(-0.9).fixedSize(horizontal:false,vertical:true)
                Text(["Une note sur le bureau. Le fil de ton projet. Une pause pour te concentrer. Installe-toi : Nino prend peu de place.", "Choisis un point de départ. Tes modèles et raccourcis s’adaptent ; tu pourras toujours changer d’avis.", "Aucun compte n’est nécessaire pour commencer. Relie un service seulement quand il t’apporte quelque chose.", "Les statistiques d’usage sont facultatives. Ton refus ne retire aucune fonctionnalité et tu peux changer ce choix dans les réglages.", "Voici ton espace de départ. Garde une idée, prépare ton travail ou lance quelques minutes de concentration."][step]).font(.system(size:13)).foregroundStyle(.white.opacity(0.62)).lineSpacing(4).fixedSize(horizontal:false,vertical:true)
            }
            Group {
                switch step {
                case 0: scenes
                case 1: profiles
                case 2: connections
                case 3: VStack(spacing: 16) { UsagePrivacyView(analytics: store.analytics); UpdateConsent(updates: store.updates) }
                default: summary
                }
            }.id(step).transition(.opacity.combined(with:.offset(y:reduceMotion ? 0 : 8)))
        }
    }
    private var scenes:some View {
        VStack(spacing:5) {
            ForEach(WelcomeScene.allCases) { item in
                Button { withAnimation(reduceMotion ? nil : .spring(response:0.4,dampingFraction:0.85)) { scene=item } } label: {
                    HStack(alignment:.center,spacing:14) {
                        Image(systemName:item.icon).font(.system(size:18)).frame(width:28).foregroundStyle(scene == item ? ninoAccent : .secondary)
                        VStack(alignment:.leading,spacing:5) { Text(item.title).font(.system(size:14,weight:.medium));Text(item.detail).font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
                        Spacer(minLength:4)
                        Image(systemName:scene == item ? "play.circle.fill" : "play.circle").font(.system(size:18)).foregroundStyle(scene == item ? ninoAccent : .white.opacity(0.2))
                    }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background { if scene == item { RoundedRectangle(cornerRadius:12).fill(.white.opacity(0.055)).matchedGeometryEffect(id:"scene",in:selection) } }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("Voir la démonstration : \(item.title)").accessibilityAddTraits(scene == item ? .isSelected : [])
            }
            HStack { Image(systemName:"lock");Text("Sans compte obligatoire. Tes fichiers restent sur ton Mac.") }.font(.system(size:10)).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading).padding(.top,10)
        }
    }
    private var profiles:some View {
        VStack(alignment:.leading,spacing:18) {
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:9) {
                ForEach(WorkProfile.allCases) { item in
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response:0.4,dampingFraction:0.9)) { profile=item;minutes=item.focusMinutes;speed=item.readingSpeed;scene=(item == .developer || item == .editor) ? .focus : item == .vibeCoder ? .draft : .notes }
                    } label: {
                        HStack(spacing:10) { Image(systemName:item.icon).frame(width:20);Text(item.title).font(.system(size:12,weight:.medium));Spacer(minLength:2);if item == profile { Image(systemName:"checkmark").font(.system(size:10,weight:.bold)) } }
                            .padding(13).frame(maxWidth:.infinity,minHeight:48,alignment:.leading).foregroundStyle(item == profile ? ninoAccent : .white.opacity(0.7))
                            .background(item == profile ? ninoAccent.opacity(0.09) : .white.opacity(0.03),in:RoundedRectangle(cornerRadius:10))
                            .overlay(RoundedRectangle(cornerRadius:10).stroke(item == profile ? ninoAccent.opacity(0.6) : .white.opacity(0.06),lineWidth:1))
                    }.buttonStyle(.plain).accessibilityLabel(item.title + (item == profile ? ", sélectionné" : ""))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(profile.detail).font(.system(size:12)).foregroundStyle(ninoAccent)
                Text(profile.companionApps).font(.system(size:10)).foregroundStyle(.secondary)
            }.frame(minHeight:42,alignment:.topLeading)
            HStack { Text("Sa présence").font(.system(size:12));Spacer();Picker("Présence",selection:$energy) { ForEach(CompanionEnergy.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented).frame(maxWidth:210) }
            DisclosureGroup("Ajuster mon rythme") {
                VStack(spacing:14) {
                    HStack { Text("Concentration");Spacer();Text("\(Int(minutes)) min").monospacedDigit() };Slider(value:$minutes,in:5...90,step:5)
                    HStack { Text("Prompteur");Spacer();Text("\(Int(speed)) mots/min").monospacedDigit() };Slider(value:$speed,in:80...200,step:5)
                }.font(.system(size:11)).padding(.top,12)
            }.font(.system(size:11)).foregroundStyle(.secondary)
        }
    }
    private var connections:some View {
        VStack(alignment:.leading,spacing:18) {
            GoogleConnectionsView(account:store.google)
            DisclosureGroup("Codex et Claude · outils de développement") { SetupConnectionsView(setup:setup).padding(.top,12) }.font(.system(size:12))
            DisclosureGroup("Préparer la voix · micro et transcription") { SetupCapabilitiesView(setup:setup,store:store).padding(.top,12) }.font(.system(size:12))
            Text("Tout est facultatif. Aucun enregistrement ne démarre pendant la configuration.").font(.system(size:11)).foregroundStyle(.secondary)
        }
    }
    private var summary:some View {
        VStack(alignment:.leading,spacing:17) {
            HStack(spacing:12) { Image(systemName:profile.icon).font(.system(size:22)).foregroundStyle(ninoAccent);VStack(alignment:.leading,spacing:4) { Text(profile.title).font(.system(size:14,weight:.medium));Text("\(energy.title) · focus \(Int(minutes)) min · lecture \(Int(speed)) mots/min").font(.system(size:11)).foregroundStyle(.secondary) } }
            Divider()
            Text("PAR QUOI COMMENCER ?").font(.system(size:9,weight:.semibold)).tracking(1.5).foregroundStyle(.secondary)
            first("notes","Poser mon premier post-it","Une idée, une consigne ou trois cases à cocher.","note.text")
            first("home","Découvrir mon espace",profile.workflows.first?.title ?? "Créer ma première fiche de travail.",profile.icon)
            first("agent","Clarifier une idée","Écrire un brief à mon assistant local.","sparkles")
            first("timer","Me concentrer","Régler mon minuteur depuis l’encoche.","timer")
            Label("La voix demandera ses accès quand tu l’utiliseras.",systemImage:"mic").font(.system(size:10)).foregroundStyle(.secondary)
        }
    }
    private func first(_ id:String,_ title:String,_ detail:String,_ icon:String)->some View {
        Button { firstAction=id;scene=id == "timer" ? .focus : id == "notes" ? .notes : .draft } label: {
            HStack(spacing:12) { Image(systemName:icon).frame(width:20);VStack(alignment:.leading,spacing:4) { Text(title).font(.system(size:13,weight:.medium));Text(detail).font(.system(size:11)).foregroundStyle(.secondary) };Spacer();Image(systemName:firstAction == id ? "checkmark.circle.fill" : "circle").foregroundStyle(firstAction == id ? ninoAccent : .secondary) }.padding(.vertical,7).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(firstAction == id ? .isSelected : [])
    }
    private var preview:some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text(step == 3 ? "CHOISIR EN CONFIANCE" : "UN PETIT COIN DE TON MAC").font(.system(size: 9, weight: .semibold)).tracking(1.8)
                Spacer()
                Image(systemName: step == 3 ? "hand.raised" : "macbook").font(.system(size: 16, weight: .light))
            }.foregroundStyle(Color(white: 0.3))
            if step == 3 {
                VStack(alignment: .leading, spacing: 24) {
                    CompanionView(mood: .idle, energy: .calm).frame(width: 112, height: 100).frame(maxWidth: .infinity)
                    Text("Le contenu de tes idées\nn’est pas une statistique.").font(.system(size: 27, weight: .medium, design: .rounded)).tracking(-0.6)
                    Divider()
                    Label("Notes, audio, conversations : exclus", systemImage: "lock")
                    Label("Compteurs d’usage : avec ton accord", systemImage: "chart.bar")
                    Label("Choix modifiable dans Réglages", systemImage: "slider.horizontal.3")
                    Text("Pour cette version, la préparation reste locale. Aucun serveur de collecte n’est connecté.").font(.system(size: 12)).foregroundStyle(Color(white: 0.35)).lineSpacing(3)
                }.font(.system(size: 13)).foregroundStyle(Color(white: 0.15)).padding(.vertical, 8)
            } else {
                WelcomeMac(energy: energy, scene: scene, finished: step == 4)
                    .padding(.horizontal, -14)
                VStack(alignment: .leading, spacing: 9) {
                    Text(step == 1 || step == 4 ? profile.title : scene.title).font(.system(size: 24, weight: .medium, design: .rounded)).tracking(-0.5)
                    Text(step == 1 || step == 4 ? profile.detail : scene.detail).font(.system(size: 13)).lineSpacing(3)
                    Text(step == 1 || step == 4 ? profile.companionApps : scene.requirement).font(.system(size: 10)).padding(.top, 4).foregroundStyle(Color(white: 0.37))
                }.foregroundStyle(Color(white: 0.15))
                if step == 1 || step == 4, let template = profile.workflows.first {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("TON PREMIER MODÈLE").font(.system(size: 8, weight: .semibold)).tracking(1.3)
                        Text(template.title).font(.system(size: 14, weight: .medium))
                        ForEach(Array(template.steps.prefix(2).enumerated()), id: \.offset) { index, title in
                            HStack(alignment: .top, spacing: 8) { Text("0\(index+1)").font(.system(size: 10, design: .monospaced)); Text(title).font(.system(size: 11)) }
                        }
                    }.foregroundStyle(Color(white: 0.25)).padding(.top, 4).id(profile).transition(.opacity)
                }
            }
        }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.93, green: 0.91, blue: 0.86), in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.18)))
    }
    private var footer:some View {
        HStack(spacing:16) {
            Button(step == 0 ? "Essayer sans configuration" : "Retour") { if step == 0 { store.dismissOnboarding() } else { advance(-1) } }.buttonStyle(.plain).foregroundStyle(.secondary).font(.system(size:12))
            Spacer()
            Button(step == 4 ? "Ouvrir mon Nino" : step == 0 ? "C’est parti" : step == 2 || step == 3 ? "Continuer" : "Garder ce profil") {
                if step < 4 { advance(1) }
                else { store.applyProfile(profile,energy:energy,minutes:minutes,speed:speed);if !store.showOnboarding { store.page=firstAction == "timer" ? "home" : firstAction;if firstAction == "timer" { store.openNotchTimer?() } } }
            }.buttonStyle(NinoPrimaryStyle()).disabled(setup.copyingModel)
        }
    }
    private func advance(_ offset:Int) { withAnimation(reduceMotion ? nil : .spring(response:0.45,dampingFraction:0.9)) { step = min(labels.count-1, max(0, step+offset)) } }
}

struct PersonalHomeView: View {
    @ObservedObject var store: NinoStore
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:28) {
                HStack {
                    VStack(alignment:.leading,spacing:12) {
                        Text("TON ESPACE · \(store.profile.title.uppercased())").font(.system(size:10,weight:.semibold)).tracking(1.6).foregroundStyle(ninoAccent)
                        Text("Qu’est-ce qu’on\navance aujourd’hui ?").font(.system(size:34,weight:.medium,design:.rounded)).tracking(-0.8)
                        Text(store.profile.detail).foregroundStyle(.secondary)
                    }
                    Spacer()
                    CompanionView(mood:store.busyID != nil ? .transcribing : store.recordingID != nil ? .dictate : .idle,energy:store.companionEnergy).frame(width:150,height:130)
                }
                DailyFocusView(store:store,today:store.today)
                if let doc=store.latestTranscript {
                    Button { store.selected=doc.id;store.page="library" } label: { HStack(spacing:12) { Image(systemName:"doc.text").foregroundStyle(ninoAccent);VStack(alignment:.leading,spacing:4) { Text("Reprendre mon dernier texte").font(.system(size:12,weight:.medium));Text(doc.title).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(1) };Spacer();Image(systemName:"arrow.up.right").font(.caption) }.padding(16).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:12)) }.buttonStyle(.plain)
                }
                VStack(spacing:0) {
                    ForEach(store.profile.tools,id:\.self) { tool in
                        Button { perform(tool) } label: {
                            HStack(spacing:16) {
                                Image(systemName:icon(tool)).font(.system(size:20)).frame(width:28).foregroundStyle(ninoAccent)
                                VStack(alignment:.leading,spacing:5) { Text(title(tool)).font(.system(size:15,weight:.medium));Text(detail(tool)).font(.system(size:12)).foregroundStyle(.secondary) }
                                Spacer();Image(systemName:"chevron.right").font(.system(size:11)).foregroundStyle(.secondary)
                            }.padding(.vertical,19).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(["voice","dictate","call","import"].contains(tool) && !store.canCapture)
                        Divider()
                    }
                }
                HStack {
                    Label("⌃⌥N ouvre l’encoche",systemImage:"keyboard").font(.system(size:12)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Personnaliser mon Nino") { store.showOnboarding=true }.buttonStyle(.plain).foregroundStyle(ninoAccent).disabled(!store.canConfigure)
                }
                Text("Les quotas et chats nécessitent les outils Codex / Claude déjà connectés sur ce Mac. Nino affiche les échanges enregistrés, pas l’état en direct d’une réponse en cours.").font(.system(size:11)).foregroundStyle(.secondary)
            }.padding(36)
        }
    }
    func title(_ id:String)->String { switch id {case "today":return "Retrouver mes quotas et mes chats";case "dictate":return "Dicter une idée ou un prompt";case "timer":return "Me concentrer \(Int(store.timerMinutes)) minutes";case "call":return "Préparer un appel";case "prompter":return "Préparer ma prise de parole";case "import":return "Transcrire un média";case "voice":return "Capturer une note vocale";default:return "Retrouver mes textes"} }
    func detail(_ id:String)->String { switch id {case "today":return "Limites Codex / Claude, objectif et derniers échanges.";case "dictate":return "Parle, arrête, puis copie le texte dans ton outil.";case "timer":return "Le compte à rebours reste visible dans l’encoche.";case "call":return "Ouvre les commandes avant de lancer l’enregistrement.";case "prompter":return "Lis ton script au rythme choisi, depuis le panneau flottant.";case "import":return "Audio ou vidéo local, transcription puis export TXT / SRT / VTT.";case "voice":return "Conserve l’audio original et sa transcription sur ton disque.";default:return "Relis, corrige et exporte tes transcriptions."} }
    func icon(_ id:String)->String { switch id {case "today":return "sun.max";case "dictate":return "mic";case "timer":return "timer";case "call":return "phone";case "prompter":return "text.viewfinder";case "import":return "square.and.arrow.down";case "voice":return "waveform";default:return "doc.text"} }
    func perform(_ id:String) {
        switch id {
        case "dictate":Task { await store.startRecording(call:false,dictation:true) }
        case "voice":Task { await store.startRecording(call:false) }
        case "import":store.chooseFiles()
        case "documents":store.page="library"
        case "timer":store.openNotchTimer?()
        default:store.page=id
        }
    }
}


struct DailyFocusView:View {
    @ObservedObject var store:NinoStore
    @ObservedObject var today:TodayStore
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            Label("Une chose à avancer maintenant",systemImage:"scope").font(.system(size:14,weight:.medium))
            TextField("Ex. Préparer ma démo, terminer un ticket…",text:$today.focus).textFieldStyle(.plain).font(.system(size:14)).padding(13).background(.black.opacity(0.15),in:RoundedRectangle(cornerRadius:9)).onChange(of:today.focus) { _,value in if value.count > 1500 { today.focus=String(value.prefix(1500)) } }
            ViewThatFits(in:.horizontal) {
                HStack(spacing:16) { focusButton;planButton;Spacer();Text("Enregistré sur ce Mac").font(.system(size:10)).foregroundStyle(.secondary) }
                VStack(alignment:.leading,spacing:12) { focusButton;planButton;Text("Enregistré sur ce Mac").font(.system(size:10)).foregroundStyle(.secondary) }
            }
        }.padding(20).background(ninoAccent.opacity(0.055),in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(ninoAccent.opacity(0.12)))
    }
    private var focusButton:some View { Button("Préparer mon focus") { store.openNotchTimer?() }.buttonStyle(NinoPrimaryStyle()) }
    private var planButton:some View { Button("Découper en trois étapes") { store.agent.input="Aide-moi à avancer sur cet objectif. Propose trois actions concrètes : " + today.focus;store.page="agent" }.buttonStyle(.plain).font(.system(size:12)).disabled(today.focus.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty) }
}
