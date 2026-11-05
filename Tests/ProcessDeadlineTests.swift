import Foundation
@main struct DeadlineTests {
 static func main() throws {
  for script in ["trap '' TERM; sleep 4", "sleep 4 & exit 0"] {
   let start = ProcessInfo.processInfo.systemUptime
   let process = try DashboardProcess(path: "/bin/sh", arguments: ["-c", script], timeout: 0.3)
   do { _ = try process.document(); fatalError("Expected timeout") } catch { }
   process.close()
   precondition(ProcessInfo.processInfo.systemUptime - start < 2)
  }
  let oversized = try DashboardProcess(path: "/usr/bin/yes", arguments: ["data"], timeout: 3)
  do { _ = try oversized.document(); fatalError("Expected bound") } catch { }
  oversized.close()
  print("PASS: deadline TERM ignoré, descendant tenant stdout, sortie bornée")
 }
}
