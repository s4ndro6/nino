import Foundation

/// Installed apps never write next to their bundle (Applications, Downloads or a mounted DMG).
/// Discovery and explicitly portable builds retain their existing external-disk library.
enum NinoPaths {
    static var portable: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NinoPortableStorage") as? Bool == true ||
        Bundle.main.object(forInfoDictionaryKey: "NinoPreviewSession") as? Bool == true
    }
    static func dataRoot(bundle: URL, home: URL, portable: Bool) -> URL {
        portable ? bundle.deletingLastPathComponent() : home.appendingPathComponent("Library/Application Support/Nino", isDirectory: true)
    }
    static var root: URL {
        dataRoot(bundle: Bundle.main.bundleURL, home: FileManager.default.homeDirectoryForCurrentUser, portable: portable)
    }
    static var helper: URL { root.appendingPathComponent("Helpers/CodexBarCLI") }

    static func prepareInstalledRoot(_ root: URL, portable: Bool) throws {
        guard !portable else { return } // Never recreate an absent external-volume library.
        let manager = FileManager.default
        var ancestor = root.standardizedFileURL
        while ancestor.path != "/" {
            if let attributes = try? manager.attributesOfItem(atPath: ancestor.path), attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                throw CocoaError(.fileWriteInvalidFileName)
            }
            ancestor.deleteLastPathComponent()
        }
        try manager.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
}
