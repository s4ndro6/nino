import SwiftUI

struct CallPage: View {
    @ObservedObject var store: NinoStore
    @ObservedObject var assistant: CallAssistant
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Un fil pendant l’appel.").font(.system(size: 30, weight: .semibold))
                    Text("Teams, Meet, Slack · son système, même avec un casque").foregroundStyle(.secondary)
                }; Spacer()
                Button("Lire dans l’encoche", systemImage:"rectangle.topthird.inset.filled") { store.openCallAssistant?() }.buttonStyle(NinoPrimaryStyle())
            }
            Text("Nino capte le son de toutes les applications, pas seulement la réunion, et enregistre aussi ton micro. Lance l’écoute quand les participants sont informés. Le direct ci-dessous transcrit le son du Mac ; ta voix est conservée sur sa piste pour la transcription finale.").font(.system(size:12)).foregroundStyle(.secondary)
            HStack {
                Toggle("Transcription locale en direct",isOn:$assistant.enabled).disabled(!store.canCapture)
                Toggle(assistant.purpose == .course ? "Expliquer les questions détectées" : "Proposer une réponse aux questions",isOn:$assistant.autoSuggest)
                Spacer()
                if store.recordingID != nil {
                    Button("Arrêter l’enregistrement",systemImage:"stop.fill") { Task { await store.stopRecording() } }.tint(.red).disabled(store.isStopping)
                } else {
                    Button("Démarrer l’appel",systemImage:"phone") { Task { await store.startRecording(call:true) } }.buttonStyle(NinoPrimaryStyle()).disabled(!store.canCapture)
                }
            }
            HStack {
                Button("Essayer avec un exemple, sans enregistrer") {
                    assistant.useExample()
                    store.openCallAssistant?()
                }.disabled(!store.canCapture || assistant.thinking)
                Text("Exemple simulé").font(.system(size:10)).foregroundStyle(.secondary)
            }
            CallCloudControls(assistant: assistant, settings: store.agent.settings) { store.page = "connections" }
            Text(assistant.modelStatus).font(.system(size:11)).foregroundStyle(.secondary)
            Text("Contexte pour les réponses — ton rôle, le sujet, les faits confirmés").font(.headline)
            TextEditor(text:$assistant.context).font(.system(size:14)).frame(height:90).padding(8).background(.black.opacity(0.15),in:RoundedRectangle(cornerRadius:10)).onChange(of:assistant.context) { _,_ in assistant.saveContext() }
            Divider()
            CallContent(store:store,assistant:assistant,compact:false).frame(minHeight: 380)
        }.padding(28) }
    }
}
struct CallContent: View {
    @ObservedObject var store: NinoStore
    @ObservedObject var assistant: CallAssistant
    var compact: Bool
    @NinoState private var manualQuestion = ""
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(spacing: 12) {
                Picker("Usage de l’assistant", selection: $assistant.purpose) {
                    ForEach(CallPurpose.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).frame(maxWidth: 220)
                if assistant.purpose == .course {
                    Button("Faire le point") { assistant.makeCoursePoint() }.font(.caption).disabled(!assistant.canMakeCoursePoint).help("Résumer l’extrait récent du direct, limité aux 3 000 derniers caractères et aux passages antérieurs sélectionnés")
                }
                Spacer(minLength: 0)
            }
            HStack {
                Circle().fill(store.recordingID != nil ? Color.red : .gray).frame(width:7,height:7)
                Text(assistant.status).font(.system(size:11)).lineLimit(2)
                Spacer()
                if let date = store.recordingStarted { Text(date,style:.timer).font(.system(size:11,design:.monospaced)) }
                if compact && store.recordingID != nil { Button("Arrêter") { Task { await store.stopRecording() } }.tint(.red).disabled(store.isStopping) }
            }
            ScrollViewReader { reader in
                ScrollView {
                    Text(assistant.transcript.isEmpty ? "Les paroles de tes interlocuteurs apparaîtront ici." : assistant.transcript)
                        .font(.system(size:compact ? 13 : 15)).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading).textSelection(.enabled)
                    Color.clear.frame(height:1).id("last")
                }.frame(minHeight:55,maxHeight:compact ? 80 : 150)
                    .onChange(of:assistant.transcript) { _,_ in reader.scrollTo("last",anchor:.bottom) }
            }
            Divider()
            HStack { Text(assistant.purpose == .course ? "POUR COMPRENDRE · À VÉRIFIER" : "SUGGESTION · À VÉRIFIER").font(.system(size:9,weight:.bold)).tracking(1.5).foregroundStyle(ninoAccent); Spacer(); if assistant.thinking { ProgressView().controlSize(.small) } }
            if !assistant.question.isEmpty { Text(assistant.question).font(.system(size:12,weight:.semibold)).lineLimit(2) }
            ScrollView {
                if let error = assistant.answerError { Text(error).font(.system(size: 13)).foregroundStyle(.orange) }
                Text(assistant.suggestion.isEmpty ? (assistant.purpose == .course ? "Une notion à comprendre ? Pose ta question ici. Faire le point résume seulement l’extrait récent du direct." : "Une question détectée déclenchera une proposition. Tu peux aussi saisir une question ci-dessous.") : assistant.suggestion)
                    .font(.system(size:compact ? 21 : 24,weight:.medium)).lineSpacing(5).foregroundStyle(.white).frame(maxWidth:.infinity,alignment:.leading).textSelection(.enabled)
            }.frame(maxHeight:.infinity)
            HStack {
                TextField(assistant.purpose == .course ? "Une notion à comprendre…" : "Question à préparer…",text:$manualQuestion).textFieldStyle(.roundedBorder).onSubmit { assistant.suggest(manualQuestion) }
                Button(assistant.purpose == .course ? "Expliquer" : "Proposer") { assistant.suggest(manualQuestion) }.disabled(manualQuestion.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                if !assistant.suggestion.isEmpty {
                    Button { store.copy(assistant.suggestion) } label: { Image(systemName:"doc.on.doc") }.help("Copier la proposition")
                    Button { store.openCallAssistant?() } label: { Image(systemName:"text.viewfinder") }.help("Lire la réponse dans l’encoche")
                }
            }
        }
    }
}
struct CallOverlay: View {
    @ObservedObject var store: NinoStore
    @ObservedObject var assistant: CallAssistant
    var close: () -> Void
    var body: some View {
        VStack(spacing:12) {
            HStack { Text("NINO · APPEL EN DIRECT").font(.system(size:10,weight:.bold)).tracking(1.5); Spacer(); Button(action:close) { Image(systemName:"xmark") }.buttonStyle(.plain).help("Masquer le panneau, sans arrêter l’appel") }
            CallContent(store:store,assistant:assistant,compact:true)
            Text("Le panneau peut apparaître dans un partage d’écran. Masquer ne coupe pas l’enregistrement.").font(.system(size:9)).foregroundStyle(.secondary)
        }.padding(20).background(.black).foregroundStyle(.white).preferredColorScheme(.dark)
    }
}
