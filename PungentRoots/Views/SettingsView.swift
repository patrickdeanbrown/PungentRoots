import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var showingCaptureTips = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                adaptiveGlassGroup(spacing: 18) {
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
                            .padding(12)
                            .adaptiveBadgeSurface(tint: .accentColor)

                        Text("Pungent Roots")
                            .font(.title2.weight(.bold))

                        Text("settings.header.tagline")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                // Capture settings card
                settingsCard(title: LocalizedStringKey("settings.capture.heading"), icon: "camera.viewfinder") {
                    VStack(alignment: .leading, spacing: 16) {
                        infoRow(
                            icon: "camera.aperture",
                            title: LocalizedStringKey("settings.capture.full_label.title"),
                            description: LocalizedStringKey("settings.capture.full_label.description")
                        )

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

                settingsCard(title: LocalizedStringKey("settings.quality.heading"), icon: "checkmark.seal.text.page.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        infoRow(
                            icon: "checkmark.seal.fill",
                            title: LocalizedStringKey("settings.quality.complete.title"),
                            description: LocalizedStringKey("settings.quality.complete.description")
                        )
                        infoRow(
                            icon: "exclamationmark.triangle.fill",
                            title: LocalizedStringKey("settings.quality.partial.title"),
                            description: LocalizedStringKey("settings.quality.partial.description")
                        )
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
                        infoRow(
                            icon: "camera.filters",
                            title: LocalizedStringKey("settings.support.packaging.title"),
                            description: LocalizedStringKey("settings.support.packaging.description")
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle(Text("settings.navigation.title"))
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.2), value: showingCaptureTips)
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
        .adaptiveCardSurface(cornerRadius: 16)
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
