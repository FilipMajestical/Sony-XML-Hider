import AppKit
import Foundation

private let appName = "Sony XML Hider"
private let bundleID = "com.majestical.sonyxmlhider"
private let launchAgentLabel = bundleID
private let launchAgentURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist")
private let installedAppURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Applications/\(appName).app")

final class SonyXMLWatcher: NSObject {
    private var timer: Timer?
    private var knownClipFolders = Set<String>()
    private var lastOpenedAt: [String: Date] = [:]

    override init() {
        super.init()
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(volumeChanged(_:)), name: NSWorkspace.didMountNotification, object: nil)
        nc.addObserver(self, selector: #selector(volumeChanged(_:)), name: NSWorkspace.didUnmountNotification, object: nil)
        nc.addObserver(self, selector: #selector(volumeChanged(_:)), name: NSWorkspace.didRenameVolumeNotification, object: nil)
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        timer?.invalidate()
    }

    func start() {
        scan(openNewFolders: true)
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.scan(openNewFolders: true)
        }
        RunLoop.main.run()
    }

    @objc private func volumeChanged(_ note: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.scan(openNewFolders: true)
        }
    }

    private func mountedVolumes() -> [URL] {
        FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey],
            options: [.skipHiddenVolumes]
        ) ?? []
    }

    private func scan(openNewFolders: Bool) {
        var current = Set<String>()

        for volume in mountedVolumes() {
            let clip = volume.appendingPathComponent("PRIVATE/M4ROOT/CLIP", isDirectory: true)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: clip.path, isDirectory: &isDir), isDir.boolValue else { continue }

            current.insert(clip.path)
            hideXMLFiles(in: clip)

            if openNewFolders && !knownClipFolders.contains(clip.path) {
                // Debounce repeated macOS mount notifications for the same volume.
                let now = Date()
                if let last = lastOpenedAt[clip.path], now.timeIntervalSince(last) < 3.0 {
                    continue
                }
                lastOpenedAt[clip.path] = now
                NSWorkspace.shared.open(clip)
            }
        }

        knownClipFolders = current
    }

    private func hideXMLFiles(in folder: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsSubdirectoryDescendants]
        ) else { return }

        for file in files where file.pathExtension.lowercased() == "xml" {
            runChflags(flag: "hidden", path: file.path)
        }
    }
}

@discardableResult
private func runProcess(_ executable: String, _ arguments: [String]) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: executable)
    p.arguments = arguments
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    do {
        try p.run()
        p.waitUntilExit()
        return p.terminationStatus
    } catch {
        return -1
    }
}

private func runChflags(flag: String, path: String) {
    _ = runProcess("/usr/bin/chflags", [flag, path])
}

private func appBundleURL() -> URL? {
    let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    // .../Sony XML Hider.app/Contents/MacOS/Sony XML Hider
    return executable
        .deletingLastPathComponent() // MacOS
        .deletingLastPathComponent() // Contents
        .deletingLastPathComponent() // .app
}

private func writeLaunchAgent() throws {
    let plistDir = launchAgentURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: plistDir, withIntermediateDirectories: true)

    let executable = installedAppURL.appendingPathComponent("Contents/MacOS/\(appName)").path
    let plist: [String: Any] = [
        "Label": launchAgentLabel,
        "ProgramArguments": [executable, "--watch"],
        "RunAtLoad": true,
        "KeepAlive": false,
        "ProcessType": "Background"
    ]
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try data.write(to: launchAgentURL, options: .atomic)
}

private func stopLaunchAgent() {
    let domain = "gui/\(getuid())"
    _ = runProcess("/bin/launchctl", ["bootout", domain, launchAgentURL.path])
}

private func startLaunchAgent() {
    let domain = "gui/\(getuid())"
    _ = runProcess("/bin/launchctl", ["bootstrap", domain, launchAgentURL.path])
    _ = runProcess("/bin/launchctl", ["kickstart", "-k", "\(domain)/\(launchAgentLabel)"])
}

private func unhideConnectedSonyXML() {
    let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) ?? []
    for volume in volumes {
        let clip = volume.appendingPathComponent("PRIVATE/M4ROOT/CLIP", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: clip, includingPropertiesForKeys: nil) else { continue }
        for file in files where file.pathExtension.lowercased() == "xml" {
            runChflags(flag: "nohidden", path: file.path)
        }
    }
}

private func install() -> Bool {
    guard let sourceApp = appBundleURL() else { return false }
    let fm = FileManager.default

    do {
        try fm.createDirectory(at: installedAppURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        stopLaunchAgent()
        if fm.fileExists(atPath: installedAppURL.path) {
            try fm.removeItem(at: installedAppURL)
        }
        try fm.copyItem(at: sourceApp, to: installedAppURL)
        try writeLaunchAgent()
        startLaunchAgent()
        return true
    } catch {
        NSLog("Install error: \(error)")
        return false
    }
}

private func uninstall() -> Bool {
    let fm = FileManager.default
    stopLaunchAgent()
    unhideConnectedSonyXML()
    do {
        if fm.fileExists(atPath: launchAgentURL.path) { try fm.removeItem(at: launchAgentURL) }
        if fm.fileExists(atPath: installedAppURL.path) { try fm.removeItem(at: installedAppURL) }
        return true
    } catch {
        NSLog("Uninstall error: \(error)")
        return false
    }
}

private func showInstallerUI() {
    NSApplication.shared.setActivationPolicy(.accessory)
    NSApplication.shared.activate(ignoringOtherApps: true)

    let alert = NSAlert()
    alert.messageText = "Sony XML Hider"
    alert.informativeText = "Automatski sakriva Sony .XML sidecar fajlove i otvara PRIVATE/M4ROOT/CLIP kada ubaciš karticu.\n\nNišta se ne briše.\n\nFrom Majestical with love <3"
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Install")
    alert.addButton(withTitle: "Uninstall")
    alert.addButton(withTitle: "Cancel")

    switch alert.runModal() {
    case .alertFirstButtonReturn:
        let ok = install()
        let done = NSAlert()
        done.messageText = ok ? "Instalirano" : "Instalacija nije uspela"
        done.informativeText = ok
            ? "Sony XML Hider sada radi u pozadini i automatski će se pokretati pri prijavi na macOS."
            : "Pokušaj ponovo. Ako macOS blokira aplikaciju, otvori System Settings → Privacy & Security i izaberi Open Anyway."
        done.runModal()
    case .alertSecondButtonReturn:
        let ok = uninstall()
        let done = NSAlert()
        done.messageText = ok ? "Uklonjeno" : "Uninstall nije u potpunosti uspeo"
        done.informativeText = ok
            ? "Sony XML Hider je uklonjen. XML fajlovi na trenutno povezanim Sony karticama su ponovo vidljivi."
            : "Proveri ~/Applications i ~/Library/LaunchAgents za preostale fajlove."
        done.runModal()
    default:
        break
    }
}

if CommandLine.arguments.contains("--watch") {
    SonyXMLWatcher().start()
} else if CommandLine.arguments.contains("--uninstall") {
    _ = uninstall()
} else {
    showInstallerUI()
}
