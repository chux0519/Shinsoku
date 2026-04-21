import SwiftUI

@main
struct ShinsokuMobileApp: App {
    @StateObject private var workspace = IOSVoiceWorkspace()
    @StateObject private var transcriber = SpeechTranscriber()
    @StateObject private var flow = FlowSessionCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(workspace)
                .environmentObject(transcriber)
                .environmentObject(flow)
        }
    }
}
