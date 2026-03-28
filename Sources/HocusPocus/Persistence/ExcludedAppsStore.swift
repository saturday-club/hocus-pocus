import AppKit
import Observation

@Observable
@MainActor
final class ExcludedAppsStore {
    private(set) var bundleIDs: Set<String>

    init() {
        let stored = UserDefaults.standard.stringArray(forKey: DefaultsKey.excludedApps) ?? []
        self.bundleIDs = Set(stored)
    }

    func add(_ bundleID: String) {
        bundleIDs.insert(bundleID)
        persist()
    }

    func remove(_ bundleID: String) {
        bundleIDs.remove(bundleID)
        persist()
    }

    func contains(_ bundleID: String) -> Bool {
        bundleIDs.contains(bundleID)
    }

    func addFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier else { return }
        add(bundleID)
    }

    func toggle(_ bundleID: String) {
        if contains(bundleID) {
            remove(bundleID)
        } else {
            add(bundleID)
        }
    }

    private func persist() {
        UserDefaults.standard.set(Array(bundleIDs), forKey: DefaultsKey.excludedApps)
    }
}
