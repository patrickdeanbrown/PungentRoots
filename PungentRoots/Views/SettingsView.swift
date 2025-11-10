import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var showingCaptureTips = false

#if os(iOS)
    @MainActor
    private var dataScannerSupported: Bool {
        if #available(iOS 16.0, *) {
            return DataScannerCaptureController.isSupported
        } else {
            return false
        }
    }
#else
    private var dataScannerSupported: Bool { false }
#endif

    var body: some View {
        @Bindable var bindings = appEnvironment

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

                    Text("Pungent Roots")
                        .font(.title2.weight(.bold))

                    Text("settings.header.tagline")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)

                // Capture settings card
                settingsCard(title: LocalizedStringKey("settings.capture.heading"), icon: "camera.viewfinder") {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle(isOn: $bindings.captureOptions.prefersDataScanner) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("settings.visionkit.toggle")
                                    .font(.subheadline.weight(.medium))
                                Text("settings.visionkit.description")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .disabled(!dataScannerSupported)

#if os(iOS)
                        if !dataScannerSupported {
                            Text("settings.visionkit.unsupported")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
#endif

                        Button {
                            showingCaptureTips.toggle()
                        } label: {
                            HStack {
                                Label(LocalizedStringKey("settings.tips.title"), systemImage: "lightbulb.fill")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Image(systemName: showingCaptureTips ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.primary)
                        }

                        if showingCaptureTips {
                            VStack(alignment: .leading, spacing: 12) {
                                tipRow(icon: "viewfinder", text: LocalizedStringKey("settings.tips.fill_frame"))
                                tipRow(icon: "bolt.badge.clock", text: LocalizedStringKey("settings.tips.hold_steady"))
                                tipRow(icon: "arrow.clockwise", text: LocalizedStringKey("settings.tips.rescan"))
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                // Privacy card
                settingsCard(title: LocalizedStringKey("settings.privacy.heading"), icon: "lock.shield.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                                .foregroundStyle(.green)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("settings.privacy.on_device.title")
                                    .font(.subheadline.weight(.semibold))
                                Text("settings.privacy.on_device.description")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Dictionary card
                settingsCard(title: LocalizedStringKey("settings.dictionary.heading"), icon: "book.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("settings.dictionary.version")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(appEnvironment.dictionary.version)
                                    .font(.monospaced(.body)().weight(.semibold))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("settings.dictionary.coverage")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("settings.dictionary.coverage_value")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .padding(.vertical, 4)

                        Divider()

                        Text("settings.dictionary.description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Support card
                settingsCard(title: LocalizedStringKey("settings.support.heading"), icon: "questionmark.circle.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        infoRow(
                            icon: "camera.badge.clock",
                            title: LocalizedStringKey("settings.support.fresh.title"),
                            description: LocalizedStringKey("settings.support.fresh.description")
                        )
                    }
                }

                // About card
                settingsCard(title: LocalizedStringKey("settings.about.heading"), icon: "info.circle.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Version info
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("settings.about.version")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(appVersion)
                                    .font(.body.weight(.medium))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("settings.about.build")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(buildNumber)
                                    .font(.body.weight(.medium))
                            }
                        }
                        .padding(.vertical, 4)

                        Divider()

                        // Copyright
                        Text("settings.about.copyright")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider()

                        // Open Source
                        infoRow(
                            icon: "chevron.left.forwardslash.chevron.right",
                            title: LocalizedStringKey("settings.about.opensource.title"),
                            description: LocalizedStringKey("settings.about.opensource.description")
                        )

                        Divider()

                        // Legal links
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                openURL("https://github.com/patrickdeanbrown/PungentRoots/blob/main/PRIVACY_POLICY.md")
                            } label: {
                                HStack {
                                    Text("settings.about.privacy")
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption)
                                }
                                .foregroundStyle(.primary)
                            }

                            Button {
                                openURL("https://github.com/patrickdeanbrown/PungentRoots/blob/main/TERMS_OF_SERVICE.md")
                            } label: {
                                HStack {
                                    Text("settings.about.terms")
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption)
                                }
                                .foregroundStyle(.primary)
                            }

                            Button {
                                openURL("https://github.com/patrickdeanbrown/PungentRoots/blob/main/LICENSE")
                            } label: {
                                HStack {
                                    Text("settings.about.license")
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption)
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(Text("settings.navigation.title"))
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.2), value: showingCaptureTips)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #endif
    }

    private func settingsCard<Content: View>(title: LocalizedStringKey, icon: String, @ViewBuilder content: () -> Content) -> some View {
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

    private func tipRow(icon: String, text: LocalizedStringKey) -> some View {
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

    private func infoRow(icon: String, title: LocalizedStringKey, description: LocalizedStringKey) -> some View {
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
