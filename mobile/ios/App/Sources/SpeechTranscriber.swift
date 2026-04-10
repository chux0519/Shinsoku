import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechTranscriber: NSObject, ObservableObject {
    enum AuthorizationState {
        case unknown
        case ready
        case denied
        case restricted

        var description: String {
            switch self {
            case .unknown:
                return "Permissions not requested yet."
            case .ready:
                return "Microphone and speech recognition are ready."
            case .denied:
                return "Microphone or speech recognition permission was denied."
            case .restricted:
                return "Speech recognition is restricted on this device."
            }
        }
    }

    @Published var authorizationState: AuthorizationState = .unknown
    @Published var transcript: String = ""
    @Published var isRecording = false
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    func refreshAuthorizationState() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        guard audioStatus == .authorized else {
            authorizationState = audioStatus == .restricted ? .restricted : .denied
            return
        }

        switch speechStatus {
        case .authorized:
            authorizationState = .ready
        case .denied:
            authorizationState = .denied
        case .restricted:
            authorizationState = .restricted
        case .notDetermined:
            authorizationState = .unknown
        @unknown default:
            authorizationState = .restricted
        }
    }

    func requestPermissions() async {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        let audioGranted = await AVCaptureDevice.requestAccess(for: .audio)

        if !audioGranted {
            authorizationState = .denied
            return
        }

        switch speechStatus {
        case .authorized:
            authorizationState = .ready
        case .denied:
            authorizationState = .denied
        case .restricted:
            authorizationState = .restricted
        case .notDetermined:
            authorizationState = .unknown
        @unknown default:
            authorizationState = .restricted
        }

        refreshAuthorizationState()
    }

    func start(localeIdentifier: String?) {
        guard authorizationState == .ready else {
            errorMessage = "Speech permissions are not ready."
            return
        }

        stop(resetTranscript: false)

        let locale = localeIdentifier.map { Locale(identifier: $0) } ?? .current
        recognizer = SFSpeechRecognizer(locale: locale)
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognizer is unavailable."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request
        transcript = ""
        errorMessage = nil

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            try audioEngine.start()
        } catch {
            errorMessage = error.localizedDescription
            cleanup()
            return
        }

        isRecording = true
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.transcript = result.bestTranscription.formattedString
            }
            if let error {
                self.errorMessage = error.localizedDescription
                self.stop(resetTranscript: false)
                return
            }
            if result?.isFinal == true {
                self.stop(resetTranscript: false)
            }
        }
    }

    func stop(resetTranscript: Bool = false) {
        isRecording = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        cleanup()
        if resetTranscript {
            transcript = ""
        }
    }

    private func cleanup() {
        request = nil
        task = nil
        recognizer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
