import SwiftUI

private struct DisplayOption:Identifiable { let id:Int;let name:String }
struct DisplayChoiceView:View {
    @ObservedObject var store:NinoStore
    @NinoState private var screens=NSScreen.screens
    var body:some View {
        Picker("Écran de l’encoche",selection:Binding(get:{store.preferredDisplay},set:{store.selectDisplay($0)})) {
            Text("Automatique · écran avec encoche").tag(0)
            ForEach(screens.compactMap { screen -> DisplayOption? in
                guard let id=(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue else { return nil }; return DisplayOption(id:id,name:screen.localizedName)
            }) { screen in Text(screen.name).tag(screen.id) }
        }.onReceive(NotificationCenter.default.publisher(for:NSApplication.didChangeScreenParametersNotification)) { _ in screens=NSScreen.screens }
    }
}
