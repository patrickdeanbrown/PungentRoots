import SwiftUI
import SwiftData

@main
struct PungentRootsApp: App {
    private let sharedModelContainer: ModelContainer
    @StateObject private var appEnvironment: AppEnvironment

    init() {
        sharedModelContainer = Self.makeModelContainer()
        let dictionary = try? DictionaryLoader(bundle: .main).load()
        guard let dictionary else {
            fatalError("Unable to load detection dictionary")
        }
        _appEnvironment = StateObject(wrappedValue: AppEnvironment(dictionary: dictionary))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appEnvironment)
        }
        .modelContainer(sharedModelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: Scan.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
