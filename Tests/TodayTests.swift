import Foundation
@main struct Tests {
 static func main() throws {
  let codex = DashboardReader.windows(["primary": ["usedPercent": 34.0, "windowDurationMins": 10080, "resetsAt": 1794392119.0], "secondary": NSNull()], claude: false)
  precondition(codex.count == 1 && codex[0].remaining == 66 && codex[0].id == "Semaine")
  precondition(DashboardReader.windows([:], claude: false).isEmpty)
  precondition(DashboardReader.windows(["primary": ["usedPercent": -1.0]], claude: false).isEmpty)
  let claude = DashboardReader.windows(["primary": ["usedPercent": 7.0, "windowMinutes": 300, "resetsAt": "2026-11-05T04:00:00Z"]], claude: true)
  precondition(claude.first?.remaining == 93 && claude.first?.reset != nil)
  let zero = DashboardReader.windows(["primary": ["usedPercent": 0.0]], claude: true)
  precondition(zero.first?.remaining == 100)
  let live = try DashboardReader.codex()
  precondition(!live.0.windows.isEmpty && !(live.1 ?? []).isEmpty)
  print("PASS: fenêtres absentes, pourcentages, échéances, zéro réel, quota et chats Codex réels")
 }
}
