import SwiftUI

struct ExcludedAppsView: View {
    @State private var appState = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Excluded Apps")
                    .font(.headline)
                Spacer()
                Button("Add Current App") {
                    appState.excludedApps.addFrontmostApp()
                }
            }

            if appState.excludedApps.bundleIDs.isEmpty {
                ContentUnavailableView(
                    "No Excluded Apps",
                    systemImage: "app.dashed",
                    description: Text("Apps in this list will not trigger the focus overlay.")
                )
            } else {
                List {
                    ForEach(Array(appState.excludedApps.bundleIDs).sorted(), id: \.self) { bundleID in
                        HStack {
                            appIcon(for: bundleID)
                                .resizable()
                                .frame(width: 24, height: 24)
                            VStack(alignment: .leading) {
                                Text(appName(for: bundleID))
                                Text(bundleID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                appState.excludedApps.remove(bundleID)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func appIcon(for bundleID: String) -> Image {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let icon = NSWorkspace.shared.icon(forFile: url.path) as NSImage? {
            return Image(nsImage: icon)
        }
        return Image(systemName: "app")
    }

    private func appName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url.deletingPathExtension().lastPathComponent
        }
        return bundleID
    }
}
