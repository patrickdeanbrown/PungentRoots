import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @AppStorage("retakeButtonAlignment") private var retakeAlignmentRaw: String = RetakeButtonAlignment.trailing.rawValue

    var body: some View {
        Form {
            Section("Capture") {
                Picker("Retake button", selection: $retakeAlignmentRaw) {
                    ForEach(RetakeButtonAlignment.allCases) { alignment in
                        Text(alignment.displayName).tag(alignment.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                DisclosureGroup("Capture tips") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Move close so the ingredient panel fills the frame.", systemImage: "viewfinder")
                        Label("Let the app focus — the scan triggers when text is sharp.", systemImage: "bolt.badge.clock")
                        Label("Highlights appear instantly; rescan whenever labels change.", systemImage: "arrow.clockwise")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
            }

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
