import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

struct LocalAppShortcut: Codable, Hashable, Identifiable {
    let id: UUID
    var path: String
    var displayName: String

    init(url: URL) {
        id = UUID()
        path = url.path
        displayName = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
    }

    var url: URL { URL(fileURLWithPath: path) }
}

@MainActor @Observable
final class LocalAppShortcutStore {
    private static let storageKey = "home.local-app-shortcuts"
    private let defaults: UserDefaults
    var shortcuts: [LocalAppShortcut] { didSet { persist() } }
    var lastErrorMessage: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        shortcuts = (defaults.data(forKey: Self.storageKey)).flatMap { try? JSONDecoder().decode([LocalAppShortcut].self, from: $0) } ?? []
        shortcuts.removeAll { !FileManager.default.fileExists(atPath: $0.path) }
    }

    func chooseApplications() {
        let panel = NSOpenPanel()
        panel.title = "添加到应用快捷入口"
        panel.prompt = "添加"
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !shortcuts.contains(where: { $0.path == url.path }) {
            shortcuts.append(LocalAppShortcut(url: url))
        }
    }

    func open(_ shortcut: LocalAppShortcut) {
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: shortcut.url, configuration: configuration) { [weak self] _, error in
            if let error { Task { @MainActor in self?.lastErrorMessage = "无法打开 \(shortcut.displayName)：\(error.localizedDescription)" } }
        }
    }

    func remove(_ id: UUID) { shortcuts.removeAll { $0.id == id } }
    func move(_ id: UUID, offset: Int) {
        guard let index = shortcuts.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard shortcuts.indices.contains(target) else { return }
        shortcuts.swapAt(index, target)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(shortcuts) { defaults.set(data, forKey: Self.storageKey) }
    }
}
