import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment

    var body: some View {
        Form {
            Section("Privacy") {
                Label("All processing stays on this device.", systemImage: "lock.shield")
                Text("Camera access powers automatic captures. No photos or text leave your device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Dictionary") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appEnvironment.dictionary.version)
                        .font(.monospaced(.body)())
                        .foregroundStyle(.secondary)
                }
                Text("Includes synonyms and patterns for onions, garlic, shallots, leeks, chives, scallions, ramps, and related alliums.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Support") {
                Text("If a label uses a term we miss or misclassifies, capture a screenshot and share it with support so we can tune the detector quickly.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Scans are transient; rescan for the freshest results and highlight screenshots for feedback.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Info & Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
