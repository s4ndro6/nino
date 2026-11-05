import Foundation
@main struct NinoPathsTests {
    static func main() throws {
        let fm = FileManager.default
        let fixture = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("Build/Fixtures/nino-paths-" + UUID().uuidString)
        try fm.createDirectory(at: fixture, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: fixture) }
        let home = fixture.appendingPathComponent("home")
        let expected = home.appendingPathComponent("Library/Application Support/Nino")
        for bundle in ["/Applications/Nino.app", "/Volumes/Nino/Nino.app", "/private/var/AppTranslocation/id/d/Nino.app"] {
            precondition(NinoPaths.dataRoot(bundle: URL(fileURLWithPath: bundle), home: home, portable: false).path == expected.path)
        }
        let external = fixture.appendingPathComponent("external/Nino.app")
        precondition(NinoPaths.dataRoot(bundle: external, home: home, portable: true).path == external.deletingLastPathComponent().path)
        try NinoPaths.prepareInstalledRoot(expected, portable: false)
        let marker = expected.appendingPathComponent("keep.txt")
        try Data("preserve".utf8).write(to: marker)
        try NinoPaths.prepareInstalledRoot(expected, portable: false)
        let content = try String(contentsOf: marker, encoding: .utf8)
        precondition(content == "preserve")
        let absent = fixture.appendingPathComponent("absent/external")
        try NinoPaths.prepareInstalledRoot(absent, portable: true)
        precondition(!fm.fileExists(atPath: absent.path))
        let linked = fixture.appendingPathComponent("linked")
        try fm.createSymbolicLink(at: linked, withDestinationURL: expected)
        do { try NinoPaths.prepareInstalledRoot(linked.appendingPathComponent("nested"), portable: false); fatalError("Symlink accepted") }
        catch is CocoaError { }
        precondition(!fm.fileExists(atPath: expected.appendingPathComponent("nested").path))
        print("PASS storage: Applications/DMG/translocation, fresh directory, existing data, portable missing volume, symlink ancestors")
    }
}
