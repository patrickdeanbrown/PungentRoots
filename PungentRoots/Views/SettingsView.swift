import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @AppStorage("retakeButtonAlignment") private var retakeAlignmentRaw: String = RetakeButtonAlignment.trailing.rawValue
    @State private var showingCaptureTips = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // App header
                VStack(spacing: 12) {
                    Image(systemName: "camera.macro.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 8)

                    Text("PungentRoots")
                        .font(.title2.weight(.bold))

                    Text("Detect alliums in ingredients instantly")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)

                // Capture settings card
                settingsCard(title: "Capture", icon: "camera.viewfinder") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Retake Button Position")
                                .font(.subheadline.weight(.medium))
                            Picker("", selection: $retakeAlignmentRaw) {
                                ForEach(RetakeButtonAlignment.allCases) { alignment in
                                    Text(alignment.displayName).tag(alignment.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text("Position at bottom corner for easy thumb access")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            showingCaptureTips.toggle()
                        } label: {
                            HStack {
                                Label("Capture Tips", systemImage: "lightbulb.fill")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Image(systemName: showingCaptureTips ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.primary)
                        }

                        if showingCaptureTips {
                            VStack(alignment: .leading, spacing: 12) {
                                tipRow(icon: "viewfinder", text: "Fill the frame with the ingredient list")
                                tipRow(icon: "bolt.badge.clock", text: "Hold steady while the camera focuses")
                                tipRow(icon: "arrow.clockwise", text: "Rescan anytime to update results")
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                // Privacy card
                settingsCard(title: "Privacy", icon: "lock.shield.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                                .foregroundStyle(.green)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("All processing on-device")
                                    .font(.subheadline.weight(.semibold))
                                Text("Camera access powers automatic captures. No photos or text leave your device.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Dictionary card
                settingsCard(title: "Detection Dictionary", icon: "book.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Version")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(appEnvironment.dictionary.version)
                                    .font(.monospaced(.body)().weight(.semibold))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Coverage")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("50+ terms")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .padding(.vertical, 4)

                        Divider()

                        Text("Detects onions, garlic, shallots, leeks, chives, scallions, ramps, and related alliums with synonyms and pattern matching.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Support card
                settingsCard(title: "Support", icon: "questionmark.circle.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        infoRow(
                            icon: "exclamationmark.bubble",
                            title: "Report Issues",
                            description: "Use the Report Issue button when you find incorrect detections"
                        )

                        Divider()

                        infoRow(
                            icon: "camera.badge.clock",
                            title: "Fresh Results",
                            description: "Scans are transient. Rescan for updated results with each label"
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Info & Settings")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.2), value: showingCaptureTips)
    }

    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(Color.accentColor)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func infoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
