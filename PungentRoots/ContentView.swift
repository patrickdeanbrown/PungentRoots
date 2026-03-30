import SwiftUI

struct ContentView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var flowModel = ScanFlowModel()
    @State private var isShowingSettings = false
    @State private var didHandleLaunchArguments = false

    private let launchArguments = ProcessInfo.processInfo.arguments

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    ScanCameraModuleView(flowModel: flowModel)
                    ScanActionBarView(flowModel: flowModel) {
                        isShowingSettings = true
                    }
                    ScanResultSectionView(flowModel: flowModel)
                    if flowModel.showsEmptyState {
                        EmptyStateView()
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemGroupedBackground),
                        Color(.secondarySystemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .toolbar { toolbarContent }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { flowModel.interfaceError != nil },
                    set: { if !$0 { flowModel.dismissError() } }
                )
            ) {
                Button("OK", role: .cancel) {
                    flowModel.dismissError()
                }
            } message: {
                Text(flowModel.interfaceError ?? "")
            }
        }
        .navigationTitle(Text("scan.navigation.title"))
        .toolbarTitleDisplayMode(.large)
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common.done") {
                                isShowingSettings = false
                            }
                        }
                    }
            }
        }
        .task {
            flowModel.bind(environment: appEnvironment)
            handleLaunchArgumentsIfNeeded()
        }
        .onDisappear {
            flowModel.stop()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { isShowingSettings = true }) {
                Label("common.info", systemImage: "info.circle")
            }
            .accessibilityIdentifier("open-settings")
        }
    }

    private func handleLaunchArgumentsIfNeeded() {
        guard didHandleLaunchArguments == false else { return }
        didHandleLaunchArguments = true

        if launchArguments.contains("--ui-test-open-settings") {
            isShowingSettings = true
        }
    }
}

private struct ContentViewPreviewHarness: View {
    @State private var environment = AppEnvironment.preview

    var body: some View {
        ContentView()
            .environment(environment)
    }
}

#Preview {
    ContentViewPreviewHarness()
}
