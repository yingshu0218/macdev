import Foundation
import Observation

@MainActor
@Observable
final class ShortcutStore {
    static let storageKey = "home.pinned-module-identifiers"

    private let defaults: UserDefaults
    private var isRestoring = true

    var pinnedModuleIDs: [AppModuleID] {
        didSet {
            guard !isRestoring else { return }
            persist()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.pinnedModuleIDs = Self.load(from: defaults)
        self.isRestoring = false
    }

    var pinnedModules: [AppModule] {
        pinnedModuleIDs.compactMap(AppModuleCatalog.module(for:))
    }

    func isPinned(_ id: AppModuleID) -> Bool {
        pinnedModuleIDs.contains(id)
    }

    func setPinned(_ id: AppModuleID, _ isPinned: Bool) {
        if isPinned {
            guard !pinnedModuleIDs.contains(id) else { return }
            pinnedModuleIDs.append(id)
        } else {
            pinnedModuleIDs.removeAll { $0 == id }
        }
    }

    func moveUp(_ id: AppModuleID) {
        guard let index = pinnedModuleIDs.firstIndex(of: id), index > 0 else { return }
        pinnedModuleIDs.swapAt(index, index - 1)
    }

    func moveDown(_ id: AppModuleID) {
        guard let index = pinnedModuleIDs.firstIndex(of: id), index < pinnedModuleIDs.count - 1 else { return }
        pinnedModuleIDs.swapAt(index, index + 1)
    }

    func reset() {
        pinnedModuleIDs = AppModuleCatalog.defaultPinnedIDs
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(pinnedModuleIDs) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [AppModuleID] {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([AppModuleID].self, from: data)
        else {
            return AppModuleCatalog.defaultPinnedIDs
        }

        let knownIDs = Set(AppModuleID.allCases)
        var seen = Set<AppModuleID>()
        return decoded.filter { knownIDs.contains($0) && seen.insert($0).inserted }
    }
}
