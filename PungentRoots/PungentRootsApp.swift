import SwiftUI

@main
struct PungentRootsApp: App {
    @StateObject private var appEnvironment: AppEnvironment

    init() {
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
    }
}
