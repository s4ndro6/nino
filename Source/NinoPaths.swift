import Foundation

/// Installed apps never write next to their bundle (Applications, Downloads or a mounted DMG).
/// Discovery and explicitly portable builds retain their existing external-disk library.
enum NinoPaths {
    static var portable: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NinoPortableStorage") as? Bool == true ||
        Bundle.main.object(forInfoDictionaryKey: "NinoPreviewSession") as? Bool == true
    }
    static func dataRoot(bundle: URL, home: URL, portable: Bool, configured: URL? = nil) -> URL {
        portable ? bundle.deletingLastPathComponent() : (configured ?? home.appendingPathComponent("Library/Application Support/Nino", isDirectory: true))
    }
    // Set only during an explicit library migration; never inferred from Downloads or another app.
    static var configuredRoot: URL? {
        guard let path = UserDefaults.standard.string(forKey: "library.root"),
              path.hasPrefix("/"), path != "/", !path.contains("/../") else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }
    static var root: URL {
        dataRoot(bundle: Bundle.main.bundleURL, home: FileManager.default.homeDirectoryForCurrentUser, portable: portable, configured: configuredRoot)
    }
    static func prepareModelFolder(root: URL) throws -> URL {
        try prepareInstalledRoot(root, portable: false, requireExisting: true)
        let folder = root.appendingPathComponent("Models", isDirectory: true)
        guard folder.standardizedFileURL.path == folder.resolvingSymlinksInPath().path else { throw CocoaError(.fileWriteInvalidFileName) }
        var directory: ObjCBool = false
        if FileManager.default.fileExists(atPath: folder.path, isDirectory: &directory) {
            guard directory.boolValue else { throw CocoaError(.fileWriteInvalidFileName) }
        } else {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        }
        return folder
    }
    static var helper: URL { root.appendingPathComponent("Helpers/CodexBarCLI") }

    static func prepareInstalledRoot(_ root: URL, portable: Bool, requireExisting: Bool = false) throws {
        guard !portable else { return } // Never recreate an absent external-volume library.
        let manager = FileManager.default
        var ancestor = root.standardizedFileURL
        while ancestor.path != "/" {
            if let attributes = try? manager.attributesOfItem(atPath: ancestor.path), attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                throw CocoaError(.fileWriteInvalidFileName)
            }
            ancestor.deleteLastPathComponent()
        }
        if requireExisting {
            var directory: ObjCBool = false
            guard manager.fileExists(atPath: root.path, isDirectory: &directory), directory.boolValue else {
                throw CocoaError(.fileNoSuchFile)
            }
            return
        }
        try manager.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
}
