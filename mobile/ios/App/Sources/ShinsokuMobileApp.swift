import SwiftUI

@main
struct ShinsokuMobileApp: App {
    @StateObject private var workspace = IOSVoiceWorkspace()
    @StateObject private var transcriber = SpeechTranscriber()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(workspace)
                .environmentObject(transcriber)
        }
    }
}
