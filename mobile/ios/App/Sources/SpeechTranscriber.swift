import AVFoundation
import Darwin
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
    @Published var isProcessing = false
    @Published var errorMessage: String?

    private let providerClient = IOSRemoteProviderClient()
    private var systemSession: SystemSpeechSession?
    private var batchRecorder: PCMBufferRecorder?
    private var sonioxSession: SonioxStreamingSession?
    private var bailianSession: BailianStreamingSession?
    private var activeProfile: VoiceProfile?
    private var activeProvider: VoiceRecognitionProvider?
    private var processingTask: Task<Void, Never>?

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

    func start(profile: VoiceProfile) {
        processingTask?.cancel()
        stop(resetTranscript: false)

        activeProfile = profile
        let providerConfig = VoiceProviderConfigStore.loadProviderConfig()
        activeProvider = providerConfig.activeRecognitionProvider
        transcript = ""
        errorMessage = nil
        isProcessing = false

        if let message = RecognitionProviderDiagnostics.requireReady(providerConfig),
           providerConfig.activeRecognitionProvider != .androidSystem {
            errorMessage = message
            return
        }

        switch providerConfig.activeRecognitionProvider {
        case .androidSystem:
            startSystemSpeech(profile: profile)
        case .openAiCompatible:
            startOpenAiCompatible(profile: profile, config: providerConfig)
        case .soniox:
            startSonioxStreaming(profile: profile, config: providerConfig)
        case .bailian:
            startBailianStreaming(profile: profile, config: providerConfig)
        }
    }

    func stop(resetTranscript: Bool = false) {
        let previousProvider = activeProvider
        let profile = activeProfile
        activeProvider = nil
        activeProfile = nil

        switch previousProvider {
        case .androidSystem:
            let rawText = transcript
            systemSession?.stop()
            systemSession = nil
            isRecording = false
            if let profile,
               !resetTranscript,
               !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                finalizeTranscript(rawText, profile: profile)
            }
        case .openAiCompatible:
            let recorder = batchRecorder
            batchRecorder = nil
            isRecording = false
            guard let profile else {
                recorder?.cancel()
                break
            }
            if resetTranscript {
                recorder?.cancel()
            } else if let recorder {
                do {
                    let wavData = try recorder.stopAndBuildWavData()
                    finalizeOpenAiBatchRecording(wavData: wavData, profile: profile)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        case .soniox:
            let session = sonioxSession
            sonioxSession = nil
            isRecording = false
            if resetTranscript {
                isProcessing = false
                session?.cancel()
            } else {
                isProcessing = true
                session?.stop()
            }
        case .bailian:
            let session = bailianSession
            bailianSession = nil
            isRecording = false
            if resetTranscript {
                isProcessing = false
                session?.cancel()
            } else {
                isProcessing = true
                session?.stop()
            }
        case .none:
            break
        }

        if resetTranscript {
            transcript = ""
            errorMessage = nil
        }
    }

    private func startSystemSpeech(profile: VoiceProfile) {
        guard authorizationState == .ready else {
            errorMessage = "Speech permissions are not ready."
            return
        }

        let locale = profile.languageTag.map(Locale.init(identifier:)) ?? .current
        let session = SystemSpeechSession(locale: locale)
        systemSession = session
        isRecording = true

        do {
            try session.start(
                onPartial: { [weak self] text in
                    Task { @MainActor [weak self] in
                        self?.transcript = text
                    }
                },
                onFinal: { [weak self] text in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.systemSession = nil
                        self.isRecording = false
                        self.finalizeTranscript(text, profile: profile)
                    }
                },
                onError: { [weak self] message in
                    Task { @MainActor [weak self] in
                        self?.isRecording = false
                        self?.systemSession = nil
                        self?.errorMessage = message
                    }
                }
            )
        } catch {
            isRecording = false
            systemSession = nil
            errorMessage = error.localizedDescription
        }
    }

    private func startOpenAiCompatible(profile: VoiceProfile, config: VoiceProviderConfig) {
        guard authorizationState == .ready || authorizationState == .unknown else {
            errorMessage = "Microphone permission is not ready."
            return
        }
        guard !config.openAiRecognition.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "OpenAI-compatible API key is missing."
            return
        }
        guard !config.openAiRecognition.transcriptionModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "OpenAI-compatible transcription model is missing."
            return
        }

        let recorder = PCMBufferRecorder()
        do {
            try recorder.start()
            batchRecorder = recorder
            isRecording = true
            transcript = "Listening…"
        } catch {
            batchRecorder = nil
            errorMessage = error.localizedDescription
        }
    }

    private func startSonioxStreaming(profile: VoiceProfile, config: VoiceProviderConfig) {
        let session = SonioxStreamingSession(
            profile: profile,
            config: config.soniox,
            onReady: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.isRecording = true
                    self?.transcript = "Listening…"
                    self?.errorMessage = nil
                }
            },
            onPartial: { [weak self] text in
                Task { @MainActor [weak self] in
                    self?.transcript = text
                }
            },
            onFinal: { [weak self] text in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isRecording = false
                    self.isProcessing = false
                    self.sonioxSession = nil
                    self.finalizeTranscript(text, profile: profile)
                }
            },
            onError: { [weak self] message in
                Task { @MainActor [weak self] in
                    self?.isRecording = false
                    self?.isProcessing = false
                    self?.sonioxSession = nil
                    self?.errorMessage = message
                }
            }
        )
        sonioxSession = session
        session.start()
    }

    private func startBailianStreaming(profile: VoiceProfile, config: VoiceProviderConfig) {
        let session = BailianStreamingSession(
            config: config.bailian,
            onReady: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.isRecording = true
                    self?.transcript = "Listening…"
                    self?.errorMessage = nil
                }
            },
            onPartial: { [weak self] text in
                Task { @MainActor [weak self] in
                    self?.transcript = text
                }
            },
            onFinal: { [weak self] text in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isRecording = false
                    self.isProcessing = false
                    self.bailianSession = nil
                    self.finalizeTranscript(text, profile: profile)
                }
            },
            onError: { [weak self] message in
                Task { @MainActor [weak self] in
                    self?.isRecording = false
                    self?.isProcessing = false
                    self?.bailianSession = nil
                    self?.errorMessage = message
                }
            }
        )
        bailianSession = session
        session.start()
    }

    private func finalizeOpenAiBatchRecording(wavData: Data, profile: VoiceProfile) {
        let providerConfig = VoiceProviderConfigStore.loadProviderConfig()
        isProcessing = true
        transcript = "Transcribing…"
        errorMessage = nil

        processingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let rawText = try await providerClient.transcribeWithOpenAiCompatible(
                    wavData: wavData,
                    profile: profile,
                    config: providerConfig.openAiRecognition
                )
                await MainActor.run {
                    self.finalizeTranscript(rawText, profile: profile)
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func finalizeTranscript(_ rawText: String, profile: VoiceProfile) {
        let cleaned = NativeTranscriptCleanup.cleanupTranscript(rawText)
        if cleaned.isEmpty {
            transcript = ""
            isProcessing = false
            return
        }

        let runtimeConfig = VoiceRuntimeConfigStore.loadRuntimeConfig()
        transcript = cleaned
        errorMessage = nil

        guard runtimeConfig.postProcessingConfig.mode == .providerAssisted else {
            isProcessing = false
            return
        }

        isProcessing = true
        processingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let refined = try await providerClient.refineTranscript(
                    rawText: cleaned,
                    profile: profile,
                    config: runtimeConfig.providerConfig.openAiPostProcessing
                )
                await MainActor.run {
                    self.transcript = refined.isEmpty ? cleaned : refined
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.transcript = cleaned
                    self.errorMessage = "Post-processing failed. Falling back to local cleanup."
                    self.isProcessing = false
                }
            }
        }
    }
}

private final class SystemSpeechSession {
    private let audioEngine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    init(locale: Locale) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    func start(
        onPartial: @escaping (String) -> Void,
        onFinal: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) throws {
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "SpeechTranscriber", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Speech recognizer is unavailable."
            ])
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            throw AudioRecordingErrorFormatter.error(from: error)
        }

        task = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    onFinal(text)
                } else {
                    onPartial(text)
                }
            }
            if let error {
                onError(error.localizedDescription)
            }
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private final class PCMBufferRecorder {
    private let audioEngine = AVAudioEngine()
    private let destinationFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!
    private var pcmBuffer = Data()
    private var converter: AVAudioConverter?
    private var isRunning = false

    func start(onChunk: ((Data) -> Void)? = nil) throws {
        pcmBuffer.removeAll(keepingCapacity: true)

        let inputNode = audioEngine.inputNode
        let sourceFormat = inputNode.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: sourceFormat, to: destinationFormat)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: sourceFormat) { [weak self] buffer, _ in
            self?.append(buffer: buffer, onChunk: onChunk)
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            converter = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            throw AudioRecordingErrorFormatter.error(from: error)
        }
        isRunning = true
    }

    func stopAndBuildWavData() throws -> Data {
        guard isRunning else {
            throw NSError(domain: "SpeechTranscriber", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Recording session is not active."
            ])
        }
        stopEngine()
        return buildWavData(from: pcmBuffer, sampleRateHz: 16_000, channelCount: 1, bitsPerSample: 16)
    }

    func cancel() {
        stopEngine()
        pcmBuffer.removeAll(keepingCapacity: false)
    }

    private func stopEngine() {
        isRunning = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        converter = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func append(buffer: AVAudioPCMBuffer, onChunk: ((Data) -> Void)?) {
        guard let converter else { return }
        let ratio = destinationFormat.sampleRate / buffer.format.sampleRate
        let outputCapacity = max(1, AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1)
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: destinationFormat,
            frameCapacity: outputCapacity
        ) else {
            return
        }

        var consumed = false
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard conversionError == nil else { return }
        guard status == .haveData || status == .inputRanDry else { return }
        guard let channelData = outputBuffer.int16ChannelData?.pointee else { return }
        let frameCount = Int(outputBuffer.frameLength)
        let chunk = Data(bytes: channelData, count: frameCount * MemoryLayout<Int16>.size)
        pcmBuffer.append(chunk)
        onChunk?(chunk)
    }

    private func buildWavData(
        from pcmData: Data,
        sampleRateHz: Int,
        channelCount: Int,
        bitsPerSample: Int
    ) -> Data {
        let byteRate = sampleRateHz * channelCount * bitsPerSample / 8
        let blockAlign = channelCount * bitsPerSample / 8
        let chunkSize = 36 + pcmData.count
        var header = Data()
        header.append("RIFF".data(using: .ascii)!)
        header.append(UInt32(chunkSize).littleEndianData)
        header.append("WAVE".data(using: .ascii)!)
        header.append("fmt ".data(using: .ascii)!)
        header.append(UInt32(16).littleEndianData)
        header.append(UInt16(1).littleEndianData)
        header.append(UInt16(channelCount).littleEndianData)
        header.append(UInt32(sampleRateHz).littleEndianData)
        header.append(UInt32(byteRate).littleEndianData)
        header.append(UInt16(blockAlign).littleEndianData)
        header.append(UInt16(bitsPerSample).littleEndianData)
        header.append("data".data(using: .ascii)!)
        header.append(UInt32(pcmData.count).littleEndianData)
        header.append(pcmData)
        return header
    }
}

private enum AudioRecordingErrorFormatter {
    static func error(from error: Error) -> NSError {
        let nsError = error as NSError
        let code = UInt32(bitPattern: Int32(nsError.code))
        let fourCC = fourCharacterCode(code)
        var message = nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty {
            message = "Audio recording failed."
        }

        if fourCC == "!rec" {
            message = "Microphone recording is not available in this context. iOS blocks custom keyboard extensions from accessing the device microphone; use the Shinsoku app to record, then insert the draft from the keyboard."
        } else if !fourCC.isEmpty {
            message += " (AudioSession \(fourCC))"
        }

        return NSError(domain: "SpeechTranscriber.AudioRecording", code: nsError.code, userInfo: [
            NSLocalizedDescriptionKey: message
        ])
    }

    private static func fourCharacterCode(_ code: UInt32) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff),
        ]
        guard bytes.allSatisfy({ $0 >= 32 && $0 <= 126 }) else {
            return ""
        }
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
}

private final class AudioChunkRingBuffer {
    private let maxBytes: Int
    private var chunks: [Data] = []
    private var byteCount = 0

    init(maxBytes: Int) {
        self.maxBytes = max(1, maxBytes)
    }

    func append(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        chunks.append(chunk)
        byteCount += chunk.count
        trimToCapacity()
    }

    func drain() -> [Data] {
        let output = chunks
        removeAll()
        return output
    }

    func removeAll() {
        chunks.removeAll(keepingCapacity: true)
        byteCount = 0
    }

    private func trimToCapacity() {
        while byteCount > maxBytes, !chunks.isEmpty {
            byteCount -= chunks.removeFirst().count
        }
    }
}

private enum StreamingRecognitionConstants {
    static let readyTimeoutSeconds: UInt64 = 10
    static let pendingAudioBytes = 16_000 * 2 * 10
}

private enum RecognitionEndpointDebug {
    static func describe(_ endpoint: String) -> String {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            return "Endpoint: \(trimmed.isEmpty ? "(empty)" : trimmed)"
        }

        var parts = ["Endpoint: \(trimmed.isEmpty ? "(empty)" : trimmed)"]
        if let host = url.host, !host.isEmpty {
            parts.append("Host: \(host)")
        }
        if let scheme = url.scheme, !scheme.isEmpty {
            parts.append("Scheme: \(scheme)")
        }
        return parts.joined(separator: " • ")
    }

    static func formatFailure(providerName: String, endpoint: String, error: Error) -> String {
        let nsError = error as NSError
        let message = nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(providerName) request failed (\(type(of: error))): \(message.isEmpty ? "Unknown error." : message)\n\(describe(endpoint))"
    }
}

private enum NetworkPreflight {
    static func resolveEndpoint(_ endpoint: String) -> String {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let host = url.host, !host.isEmpty else {
            return "Endpoint host could not be parsed.\n\(RecognitionEndpointDebug.describe(endpoint))"
        }

        var hints = addrinfo(
            ai_flags: AI_DEFAULT,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var result: UnsafeMutablePointer<addrinfo>?
        let code = getaddrinfo(host, nil, &hints, &result)
        defer {
            if let result {
                freeaddrinfo(result)
            }
        }

        guard code == 0 else {
            let message = String(cString: gai_strerror(code))
            return "DNS preflight failed (\(code)): \(message)\n\(RecognitionEndpointDebug.describe(endpoint))"
        }

        return "DNS resolved successfully.\n\(RecognitionEndpointDebug.describe(endpoint))"
    }
}

private final class SonioxStreamingSession {
    private let profile: VoiceProfile
    private let config: SonioxProviderConfig
    private let onReady: @Sendable () -> Void
    private let onPartial: @Sendable (String) -> Void
    private let onFinal: @Sendable (String) -> Void
    private let onError: @Sendable (String) -> Void
    private let recorder = PCMBufferRecorder()
    private var accumulator = SonioxTranscriptAccumulator()

    private var socket: URLSessionWebSocketTask?
    private var finalized = false
    private var finalDelivered = false
    private var finalCandidateText = ""
    private var lastPartialText = ""
    private var streamReady = false
    private var pendingAudio = AudioChunkRingBuffer(maxBytes: StreamingRecognitionConstants.pendingAudioBytes)
    private var readyTimeoutTask: Task<Void, Never>?
    private let lock = NSLock()

    init(
        profile: VoiceProfile,
        config: SonioxProviderConfig,
        onReady: @escaping @Sendable () -> Void,
        onPartial: @escaping @Sendable (String) -> Void,
        onFinal: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (String) -> Void
    ) {
        self.profile = profile
        self.config = config
        self.onReady = onReady
        self.onPartial = onPartial
        self.onFinal = onFinal
        self.onError = onError
    }

    func start() {
        guard let url = URL(string: config.url) else {
            onError("Invalid Soniox endpoint.")
            return
        }

        do {
            try recorder.start { [weak self] chunk in
                self?.enqueueAudio(chunk)
            }
        } catch {
            onError(error.localizedDescription)
            return
        }

        onReady()
        socket = URLSession.shared.webSocketTask(with: url)
        socket?.resume()
        scheduleReadyTimeout()
        receiveNext()
        Task {
            await sendStartMessage()
        }
    }

    func stop() {
        guard !finalized else { return }
        finalized = true
        recorder.cancel()
        let ready = withStateLock { streamReady }
        if ready {
            Task { await sendFinalize() }
        }
    }

    func cancel() {
        finalized = true
        recorder.cancel()
        withStateLock {
            pendingAudio.removeAll()
            streamReady = false
        }
        readyTimeoutTask?.cancel()
        readyTimeoutTask = nil
        socket?.cancel(with: .normalClosure, reason: nil)
    }

    private func enqueueAudio(_ chunk: Data) {
        let (ready, socket): (Bool, URLSessionWebSocketTask?) = withStateLock {
            let ready = streamReady
            if !ready {
                pendingAudio.append(chunk)
            }
            return (ready, self.socket)
        }

        guard ready, let socket else { return }
        Task {
            do {
                try await socket.send(.data(chunk))
            } catch {
                fail(endpointFailure(error))
            }
        }
    }

    private func receiveNext() {
        guard let socket else { return }
        Task {
            do {
                let message = try await socket.receive()
                switch message {
                case .string(let text):
                    handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleMessage(text)
                    }
                @unknown default:
                    break
                }
                receiveNext()
            } catch {
                if finalized && !finalDelivered && !finalCandidateText.isEmpty {
                    finalDelivered = true
                    onFinal(finalCandidateText)
                } else if !finalDelivered {
                    fail(endpointFailure(error))
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            fail("Invalid Soniox message.")
            return
        }

        let update = accumulator.consume(payload)
        if let errorMessage = update.errorMessage {
            fail(errorMessage)
            return
        }
        if !update.partialText.isEmpty && update.partialText != lastPartialText && !finalDelivered {
            lastPartialText = update.partialText
            onPartial(update.partialText)
        }
        let candidateText = update.finalText.isEmpty ? update.partialText : update.finalText
        finalCandidateText = candidateText
        if update.finished && !candidateText.isEmpty && !finalDelivered {
            finalDelivered = true
            onFinal(candidateText)
            socket?.cancel(with: .normalClosure, reason: nil)
        }
    }

    private func sendStartMessage() async {
        var start: [String: Any] = [
            "api_key": config.apiKey,
            "model": config.model,
            "audio_format": "s16le",
            "num_channels": 1,
            "sample_rate": 16_000,
        ]
        if let languageTag = profile.languageTag, !languageTag.isEmpty {
            start["language_hints"] = [languageTag]
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: start)
            guard let text = String(data: data, encoding: .utf8) else {
                fail("Failed to encode Soniox start message.")
                return
            }
            try await socket?.send(.string(text))
            let state: ([Data], URLSessionWebSocketTask?, Bool) = withStateLock {
                streamReady = true
                readyTimeoutTask?.cancel()
                readyTimeoutTask = nil
                let pending = pendingAudio.drain()
                return (pending, self.socket, finalized)
            }
            let pending = state.0
            let socket = state.1
            let shouldFinalize = state.2
            for chunk in pending {
                try await socket?.send(.data(chunk))
            }
            if shouldFinalize {
                await sendFinalize()
            }
        } catch {
            fail(endpointFailure(error))
        }
    }

    private func sendFinalize() async {
        do {
            try await socket?.send(.string("{\"type\":\"finalize\"}"))
            try await socket?.send(.data(Data()))
        } catch {
            fail(endpointFailure(error))
        }
    }

    private func fail(_ message: String) {
        if !finalDelivered {
            onError(message)
        }
        cancel()
    }

    private func scheduleReadyTimeout() {
        readyTimeoutTask?.cancel()
        readyTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: StreamingRecognitionConstants.readyTimeoutSeconds * 1_000_000_000)
            guard let self else { return }
            let shouldFail = self.withStateLock {
                !self.streamReady && !self.finalized && !self.finalDelivered
            }
            if shouldFail {
                self.fail(
                    "Soniox stream did not become ready within \(StreamingRecognitionConstants.readyTimeoutSeconds)s.\n" +
                    RecognitionEndpointDebug.describe(self.config.url) + "\n" +
                    NetworkPreflight.resolveEndpoint(self.config.url)
                )
            }
        }
    }

    private func endpointFailure(_ error: Error) -> String {
        RecognitionEndpointDebug.formatFailure(providerName: "Soniox", endpoint: config.url, error: error) +
            "\n" + NetworkPreflight.resolveEndpoint(config.url)
    }

    private func withStateLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class BailianStreamingSession {
    private let config: BailianProviderConfig
    private let onReady: @Sendable () -> Void
    private let onPartial: @Sendable (String) -> Void
    private let onFinal: @Sendable (String) -> Void
    private let onError: @Sendable (String) -> Void
    private let recorder = PCMBufferRecorder()
    private var accumulator = BailianTranscriptAccumulator()
    private let taskId = "ios-\(String(Int(Date().timeIntervalSince1970), radix: 16))-\(UUID().uuidString.prefix(6).lowercased())"

    private var socket: URLSessionWebSocketTask?
    private var finalized = false
    private var finalDelivered = false
    private var streamReady = false
    private var pendingAudio = AudioChunkRingBuffer(maxBytes: StreamingRecognitionConstants.pendingAudioBytes)
    private var readyTimeoutTask: Task<Void, Never>?
    private let lock = NSLock()

    init(
        config: BailianProviderConfig,
        onReady: @escaping @Sendable () -> Void,
        onPartial: @escaping @Sendable (String) -> Void,
        onFinal: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (String) -> Void
    ) {
        self.config = config
        self.onReady = onReady
        self.onPartial = onPartial
        self.onFinal = onFinal
        self.onError = onError
    }

    func start() {
        guard let url = URL(string: config.url) else {
            onError("Invalid Bailian endpoint.")
            return
        }
        var request = URLRequest(url: url)
        request.setValue("bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        do {
            try recorder.start { [weak self] chunk in
                self?.enqueueAudio(chunk)
            }
        } catch {
            onError(error.localizedDescription)
            return
        }

        onReady()
        socket = URLSession.shared.webSocketTask(with: request)
        socket?.resume()
        scheduleReadyTimeout()
        receiveNext()
        Task {
            await sendRunTask()
        }
    }

    func stop() {
        guard !finalized else { return }
        finalized = true
        recorder.cancel()
        let ready = withStateLock { streamReady }
        if ready {
            Task { await sendFinishTask() }
        }
    }

    func cancel() {
        finalized = true
        recorder.cancel()
        withStateLock {
            pendingAudio.removeAll()
            streamReady = false
        }
        readyTimeoutTask?.cancel()
        readyTimeoutTask = nil
        socket?.cancel(with: .normalClosure, reason: nil)
    }

    private func enqueueAudio(_ chunk: Data) {
        let (ready, socket): (Bool, URLSessionWebSocketTask?) = withStateLock {
            let ready = streamReady
            if !ready {
                pendingAudio.append(chunk)
            }
            return (ready, self.socket)
        }

        guard ready, let socket else { return }
        Task {
            do {
                try await socket.send(.data(chunk))
            } catch {
                fail(endpointFailure(error))
            }
        }
    }

    private func receiveNext() {
        guard let socket else { return }
        Task {
            do {
                let message = try await socket.receive()
                switch message {
                case .string(let text):
                    handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleMessage(text)
                    }
                @unknown default:
                    break
                }
                receiveNext()
            } catch {
                if !finalDelivered {
                    fail(endpointFailure(error))
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            fail("Invalid Bailian message.")
            return
        }

        switch accumulator.consume(payload) {
        case .taskStarted:
            let state: ([Data], URLSessionWebSocketTask?, Bool) = withStateLock {
                streamReady = true
                readyTimeoutTask?.cancel()
                readyTimeoutTask = nil
                let pending = pendingAudio.drain()
                return (pending, self.socket, finalized)
            }
            let pending = state.0
            let socket = state.1
            let shouldFinish = state.2
            Task {
                do {
                    for chunk in pending {
                        try await socket?.send(.data(chunk))
                    }
                    if shouldFinish {
                        await sendFinishTask()
                    }
                } catch {
                    fail(endpointFailure(error))
                }
            }
        case .partial(let text):
            if !text.isEmpty {
                onPartial(text)
            }
        case .finished(let text):
            let finalText = text
            if !finalDelivered && !finalText.isEmpty {
                finalDelivered = true
                onFinal(finalText)
            } else if !finalDelivered {
                fail("No speech recognized.")
            }
            socket?.cancel(with: .normalClosure, reason: nil)
        case .failed(let message):
            fail(message)
        case .ignored:
            break
        }
    }

    private func sendRunTask() async {
        let body: [String: Any] = [
            "header": [
                "action": "run-task",
                "task_id": taskId,
                "streaming": "duplex",
            ],
            "payload": [
                "task_group": "audio",
                "task": "asr",
                "function": "recognition",
                "model": config.model,
                "parameters": [
                    "format": "pcm",
                    "sample_rate": 16_000,
                ],
                "input": [:],
            ],
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: body)
            guard let text = String(data: data, encoding: .utf8) else {
                fail("Failed to encode Bailian run-task.")
                return
            }
            try await socket?.send(.string(text))
        } catch {
            fail(endpointFailure(error))
        }
    }

    private func sendFinishTask() async {
        let body: [String: Any] = [
            "header": [
                "action": "finish-task",
                "task_id": taskId,
                "streaming": "duplex",
            ],
            "payload": [
                "input": [:],
            ],
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: body)
            guard let text = String(data: data, encoding: .utf8) else {
                fail("Failed to encode Bailian finish-task.")
                return
            }
            try await socket?.send(.string(text))
        } catch {
            fail(endpointFailure(error))
        }
    }

    private func fail(_ message: String) {
        if !finalDelivered {
            onError(message)
        }
        cancel()
    }

    private func scheduleReadyTimeout() {
        readyTimeoutTask?.cancel()
        readyTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: StreamingRecognitionConstants.readyTimeoutSeconds * 1_000_000_000)
            guard let self else { return }
            let shouldFail = self.withStateLock {
                !self.streamReady && !self.finalized && !self.finalDelivered
            }
            if shouldFail {
                self.fail(
                    "Bailian stream did not become ready within \(StreamingRecognitionConstants.readyTimeoutSeconds)s.\n" +
                    RecognitionEndpointDebug.describe(self.config.url) + "\n" +
                    NetworkPreflight.resolveEndpoint(self.config.url)
                )
            }
        }
    }

    private func endpointFailure(_ error: Error) -> String {
        RecognitionEndpointDebug.formatFailure(providerName: "Bailian", endpoint: config.url, error: error) +
            "\n" + NetworkPreflight.resolveEndpoint(config.url)
    }

    private func withStateLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private struct SonioxTranscriptAccumulator {
    struct Update {
        let partialText: String
        let finalText: String
        let finished: Bool
        let errorMessage: String?
    }

    private var aggregateTokens: [String: TimedToken] = [:]

    mutating func consume(_ payload: [String: Any]) -> Update {
        let errorCode = payload["error_code"] as? Int ?? 0
        let errorMessage = (payload["error_message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if errorCode != 0 || !(errorMessage ?? "").isEmpty {
            return Update(
                partialText: "",
                finalText: "",
                finished: true,
                errorMessage: errorMessage?.isEmpty == false ? errorMessage : "Soniox returned an error."
            )
        }

        if let tokens = payload["tokens"] as? [[String: Any]] {
            merge(tokens: tokens)
        }
        let partialText = render(finalsOnly: false)
        let finalText = render(finalsOnly: true)
        let finished = (payload["finished"] as? Bool) == true || hasFinToken(tokens: payload["tokens"] as? [[String: Any]])
        return Update(partialText: partialText, finalText: finalText, finished: finished, errorMessage: nil)
    }

    private mutating func merge(tokens: [[String: Any]]) {
        for token in tokens {
            let text = (token["text"] as? String ?? "")
            if text.isEmpty || text == "<fin>" {
                continue
            }
            let start = token["start_ms"] as? Int ?? 0
            let end = token["end_ms"] as? Int ?? 0
            let key = "\(start):\(end)"
            let existing = aggregateTokens[key]
            aggregateTokens[key] = TimedToken(
                text: text,
                isFinal: existing?.isFinal == true || ((token["is_final"] as? Bool) == true),
                startMs: start,
                endMs: end
            )
        }
    }

    private func render(finalsOnly: Bool) -> String {
        aggregateTokens.values
            .sorted { ($0.startMs, $0.endMs) < ($1.startMs, $1.endMs) }
            .map { finalsOnly && !$0.isFinal ? "" : $0.text }
            .joined()
    }

    private func hasFinToken(tokens: [[String: Any]]?) -> Bool {
        guard let tokens else { return false }
        return tokens.contains { ($0["text"] as? String) == "<fin>" }
    }

    private struct TimedToken {
        let text: String
        let isFinal: Bool
        let startMs: Int
        let endMs: Int
    }
}

private struct BailianTranscriptAccumulator {
    enum Event {
        case taskStarted
        case partial(String)
        case finished(String)
        case failed(String)
        case ignored
    }

    private var sentences: [Int: SentenceState] = [:]

    mutating func consume(_ payload: [String: Any]) -> Event {
        let header = payload["header"] as? [String: Any] ?? [:]
        let event = header["event"] as? String ?? ""
        switch event {
        case "task-failed":
            let message = (header["error_message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return .failed(message?.isEmpty == false ? message! : "Bailian returned task-failed.")
        case "task-started":
            return .taskStarted
        case "result-generated":
            guard let payloadBody = payload["payload"] as? [String: Any],
                  let output = payloadBody["output"] as? [String: Any],
                  let sentence = output["sentence"] as? [String: Any] else {
                return .ignored
            }
            let sentenceId = sentence["sentence_id"] as? Int ?? 0
            let text = sentence["text"] as? String ?? ""
            guard sentenceId > 0, !text.isEmpty else {
                return .ignored
            }
            sentences[sentenceId] = SentenceState(
                text: text,
                isFinal: (sentence["sentence_end"] as? Bool) == true
            )
            return .partial(render(finalsOnly: false))
        case "task-finished":
            let finals = render(finalsOnly: true)
            return .finished(finals.isEmpty ? render(finalsOnly: false) : finals)
        default:
            return .ignored
        }
    }

    private func render(finalsOnly: Bool) -> String {
        sentences.keys.sorted().compactMap { key in
            guard let sentence = sentences[key] else { return nil }
            if finalsOnly && !sentence.isFinal {
                return ""
            }
            return sentence.text
        }.joined()
    }

    private struct SentenceState {
        let text: String
        let isFinal: Bool
    }
}

private struct IOSRemoteProviderClient {
    private static let postProcessingTimeout: TimeInterval = 45
    private static let postProcessingMaxTokens = 256

    func transcribeWithOpenAiCompatible(
        wavData: Data,
        profile: VoiceProfile,
        config: OpenAiProviderConfig
    ) async throws -> String {
        let boundary = "ShinsokuBoundary-\(UUID().uuidString)"
        var body = Data()
        body.appendMultipartField(named: "model", value: config.transcriptionModel, boundary: boundary)
        if let languageTag = profile.languageTag?.split(separator: "-").first, !languageTag.isEmpty {
            body.appendMultipartField(named: "language", value: String(languageTag), boundary: boundary)
        }
        body.appendMultipartField(named: "response_format", value: "json", boundary: boundary)
        body.appendMultipartFile(
            named: "file",
            filename: "shinsoku.wav",
            contentType: "audio/wav",
            data: wavData,
            boundary: boundary
        )
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let endpoint = config.baseUrl.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/audio/transcriptions"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "SpeechTranscriber", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "Invalid OpenAI-compatible transcription endpoint."
            ])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.postProcessingTimeout
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        try validate(response: response, data: data, fallback: "OpenAI-compatible transcription failed.")
        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (payload?["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func refineTranscript(
        rawText: String,
        profile: VoiceProfile,
        config: OpenAiPostProcessingConfig
    ) async throws -> String {
        guard let promptPlan = NativeTransformPromptBuilder.build(
            rawTranscript: rawText,
            transform: profile.transform
        ) else {
            return rawText
        }

        let endpoint = config.baseUrl.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "SpeechTranscriber", code: -4, userInfo: [
                NSLocalizedDescriptionKey: "Invalid OpenAI-compatible post-processing endpoint."
            ])
        }

        var messages: [[String: String]] = []
        switch promptPlan.requestFormat {
        case .systemAndUser:
            messages = [
                ["role": "system", "content": promptPlan.systemPrompt],
                ["role": "user", "content": promptPlan.userContent],
            ]
        case .singleUserMessage:
            let mergedPrompt = promptPlan.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines) +
                "\n\n" + promptPlan.userContent
            messages = [["role": "user", "content": mergedPrompt]]
        }

        var requestBody: [String: Any] = [
            "model": config.model.isEmpty ? "gpt-5.4-nano" : config.model,
            "messages": messages,
            "stream": false,
            "max_tokens": Self.postProcessingMaxTokens,
            "temperature": 0.2,
        ]
        if isDashScopeCompatible(url: url) {
            requestBody["enable_thinking"] = false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.postProcessingTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, fallback: "OpenAI-compatible post-processing failed.")
        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = payload?["choices"] as? [[String: Any]]
        let firstChoice = choices?.first
        let message = firstChoice?["message"] as? [String: Any]
        return (message?["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func validate(response: URLResponse, data: Data, fallback: String) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200 ..< 300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "SpeechTranscriber", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: body?.isEmpty == false ? body! : fallback
            ])
        }
    }

    private func isDashScopeCompatible(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "dashscope.aliyuncs.com" ||
            host == "dashscope-intl.aliyuncs.com" ||
            host == "dashscope-us.aliyuncs.com"
    }
}

private extension Data {
    mutating func appendMultipartField(named name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipartFile(
        named name: String,
        filename: String,
        contentType: String,
        data: Data,
        boundary: String
    ) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}

private extension UInt16 {
    var littleEndianData: Data {
        withUnsafeBytes(of: self.littleEndian) { Data($0) }
    }
}

private extension UInt32 {
    var littleEndianData: Data {
        withUnsafeBytes(of: self.littleEndian) { Data($0) }
    }
}
