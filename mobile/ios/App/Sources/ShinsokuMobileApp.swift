import SwiftUI

@main
struct ShinsokuMobileApp: App {
    @State private var selectedProfile = VoiceProfile.defaults.first ?? .init(id: "dictation", title: "Dictation", mode: .dictation)

    var body: some Scene {
        WindowGroup {
            RootView(selectedProfile: $selectedProfile)
        }
    }
}
