import SwiftUI

@main
struct PungentRootsApp: App {
    @State private var appEnvironment: AppEnvironment

    init() {
        _appEnvironment = State(wrappedValue: .live())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appEnvironment)
        }
    }
}
