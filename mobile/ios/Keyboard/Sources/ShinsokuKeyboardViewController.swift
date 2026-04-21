import UIKit
import Combine

final class ShinsokuKeyboardViewController: UIInputViewController {
    private let profileLabel = UILabel()
    private let metaLabel = UILabel()
    private let statusLabel = UILabel()
    private let latestDraftLabel = UILabel()
    private let profileButton = UIButton(type: .system)
    private let backspaceButton = UIButton(type: .system)
    private let spaceButton = UIButton(type: .system)
    private let enterButton = UIButton(type: .system)
    private let moreButton = UIButton(type: .system)
    private let micButton = UIButton(type: .system)
    private let insertButton = UIButton(type: .system)
    private let insertAndClearButton = UIButton(type: .system)
    private let previousButton = UIButton(type: .system)
    private let nextDraftButton = UIButton(type: .system)
    private let refreshButton = UIButton(type: .system)
    private let nextKeyboardButton = UIButton(type: .system)
    private let stackView = UIStackView()
    private let transcriber = SpeechTranscriber()
    private var cancellables: Set<AnyCancellable> = []
    private var drafts: [StoredDraft] = []
    private var currentDraftIndex = 0
    private var activeRecognitionProfile: VoiceProfile?
    private var pendingRecognitionText: String?
    private var deliveredRecognitionText: String?
    private var flowPollTimer: Timer?
    private var backspaceRepeatTimer: Timer?
    private var spaceTrackingLastLocation: CGPoint?
    private var spaceTrackingRemainder: CGPoint = .zero
    private var hiddenButtonConfigurations: [(UIButton, UIButton.Configuration?)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureLayout()
        bindTranscriber()
        reloadDraft()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadDraft()
        startFlowPolling()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        flowPollTimer?.invalidate()
        flowPollTimer = nil
        stopBackspaceRepeat()
    }

    private func configureLayout() {
        profileLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        latestDraftLabel.translatesAutoresizingMaskIntoConstraints = false
        profileButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.translatesAutoresizingMaskIntoConstraints = false
        insertButton.translatesAutoresizingMaskIntoConstraints = false
        insertAndClearButton.translatesAutoresizingMaskIntoConstraints = false
        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        profileLabel.font = .systemFont(ofSize: 13, weight: .medium)
        profileLabel.textColor = .secondaryLabel

        metaLabel.font = .systemFont(ofSize: 12, weight: .regular)
        metaLabel.textColor = .tertiaryLabel

        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 2

        latestDraftLabel.numberOfLines = 2
        latestDraftLabel.font = .systemFont(ofSize: 15, weight: .regular)
        latestDraftLabel.text = "Open the Shinsoku app to create a draft."
        latestDraftLabel.backgroundColor = .tertiarySystemBackground
        latestDraftLabel.layer.cornerRadius = 12
        latestDraftLabel.layer.masksToBounds = true
        latestDraftLabel.textAlignment = .left
        latestDraftLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        profileButton.configuration = outlineConfiguration(title: "Mode")
        profileButton.showsMenuAsPrimaryAction = true

        backspaceButton.configuration = iconConfiguration(systemName: "delete.left")
        backspaceButton.accessibilityLabel = "Backspace"
        backspaceButton.addTarget(self, action: #selector(startBackspaceRepeat), for: .touchDown)
        backspaceButton.addTarget(
            self,
            action: #selector(stopBackspaceRepeat),
            for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit]
        )

        spaceButton.configuration = outlineConfiguration(title: "space")
        spaceButton.addTarget(self, action: #selector(insertSpace), for: .touchUpInside)
        let spaceTrackingGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleSpaceTracking(_:)))
        spaceTrackingGesture.minimumPressDuration = 0.28
        spaceTrackingGesture.cancelsTouchesInView = true
        spaceButton.addGestureRecognizer(spaceTrackingGesture)

        enterButton.configuration = iconConfiguration(systemName: "return")
        enterButton.accessibilityLabel = "Enter"
        enterButton.addTarget(self, action: #selector(insertNewline), for: .touchUpInside)

        moreButton.configuration = outlineConfiguration(title: "More")
        moreButton.showsMenuAsPrimaryAction = true

        micButton.configuration = filledConfiguration(title: "Mic")
        micButton.addTarget(self, action: #selector(toggleVoiceInput), for: .touchUpInside)

        previousButton.configuration = outlineConfiguration(title: "Prev")
        previousButton.addTarget(self, action: #selector(showPreviousDraft), for: .touchUpInside)

        insertButton.configuration = filledConfiguration(title: "Insert")
        insertButton.addTarget(self, action: #selector(insertCurrentDraft), for: .touchUpInside)

        insertAndClearButton.configuration = outlineConfiguration(title: "Insert & remove")
        insertAndClearButton.addTarget(self, action: #selector(insertAndRemoveCurrentDraft), for: .touchUpInside)

        nextDraftButton.configuration = outlineConfiguration(title: "Next")
        nextDraftButton.addTarget(self, action: #selector(showNextDraft), for: .touchUpInside)

        refreshButton.configuration = outlineConfiguration(title: "Refresh")
        refreshButton.addTarget(self, action: #selector(refreshDrafts), for: .touchUpInside)

        nextKeyboardButton.configuration = iconConfiguration(systemName: "globe")
        nextKeyboardButton.accessibilityLabel = "Next keyboard"
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        stackView.axis = .vertical
        stackView.spacing = 6
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = .init(top: 9, leading: 10, bottom: 9, trailing: 10)

        let leftColumn = UIStackView(arrangedSubviews: [
            profileButton,
            moreButton,
        ])
        leftColumn.axis = .vertical
        leftColumn.spacing = 8
        leftColumn.alignment = .fill
        leftColumn.distribution = .fillEqually

        let centerColumn = UIStackView(arrangedSubviews: [
            micButton,
            spaceButton,
        ])
        centerColumn.axis = .vertical
        centerColumn.spacing = 8
        centerColumn.alignment = .fill
        centerColumn.distribution = .fill

        let rightColumn = UIStackView(arrangedSubviews: [
            backspaceButton,
            enterButton,
        ])
        rightColumn.axis = .vertical
        rightColumn.spacing = 8
        rightColumn.alignment = .fill
        rightColumn.distribution = .fillEqually

        let keyboardRow = UIStackView(arrangedSubviews: [
            leftColumn,
            centerColumn,
            rightColumn,
        ])
        keyboardRow.axis = .horizontal
        keyboardRow.spacing = 10
        keyboardRow.alignment = .fill
        keyboardRow.distribution = .fill
        stackView.addArrangedSubview(keyboardRow)

        [centerColumn].forEach {
            $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        [leftColumn, rightColumn, backspaceButton, enterButton, moreButton, micButton].forEach {
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            micButton.heightAnchor.constraint(equalToConstant: 66),
            spaceButton.heightAnchor.constraint(equalToConstant: 38),
            leftColumn.widthAnchor.constraint(equalToConstant: 64),
            rightColumn.widthAnchor.constraint(equalToConstant: 52),
        ])

        view.backgroundColor = .systemBackground
        stackView.backgroundColor = .systemBackground
    }

    private func reloadDraft() {
        let profile = VoiceProfileStore.loadSelectedProfile()
        profileLabel.text = profile.title
        profileButton.configuration?.title = "Mode"
        profileButton.menu = profileMenu(selectedProfile: profile)
        moreButton.menu = moreMenu()
        updateMicButton()

        drafts = DraftStore.loadDrafts()
        let diagnostics = DraftStore.diagnostics()
        currentDraftIndex = min(currentDraftIndex, max(drafts.count - 1, 0))
        statusLabel.text = diagnosticsStatusText(for: diagnostics)

        guard let draft = drafts[safe: currentDraftIndex] else {
            latestDraftLabel.text = hasFullAccess
                ? "No draft yet. Open Shinsoku, dictate, then save a draft."
                : "Enable Full Access to read shared drafts from the app."
            metaLabel.text = hasFullAccess ? "No shared drafts yet" : "Full Access is off"
            insertButton.isEnabled = false
            previousButton.isEnabled = false
            nextDraftButton.isEnabled = false
            return
        }
        latestDraftLabel.text = draft.text
        let draftProfile = VoiceProfile.defaults.first(where: { $0.id == draft.profileID })?.title ?? draft.profileID
        metaLabel.text = "\(draftProfile) · \(currentDraftIndex + 1)/\(drafts.count) · \(DisplayFormatting.relativeTimestamp(for: draft.updatedAt))"
        insertButton.isEnabled = true
        previousButton.isEnabled = drafts.count > 1
        nextDraftButton.isEnabled = drafts.count > 1
    }

    private func diagnosticsStatusText(for diagnostics: SharedStorageDiagnostics) -> String {
        var parts: [String] = []
        parts.append(hasFullAccess ? "Full Access on" : "Full Access off")
        parts.append(diagnostics.isUsingSharedDefaults ? "Shared drafts ready" : "Using fallback storage")
        return parts.joined(separator: " · ")
    }

    @objc
    private func insertCurrentDraft() {
        if let pendingRecognitionText {
            commitRecognizedText(pendingRecognitionText)
            clearPendingRecognition()
            return
        }
        guard let draft = drafts[safe: currentDraftIndex] else { return }
        let profile = VoiceProfileStore.loadSelectedProfile()
        textDocumentProxy.insertText(draft.text + profile.commitSuffix)
    }

    @objc
    private func insertAndRemoveCurrentDraft() {
        if let pendingRecognitionText {
            commitRecognizedText(pendingRecognitionText)
            clearPendingRecognition()
            return
        }
        guard let draft = drafts[safe: currentDraftIndex] else { return }
        insertCurrentDraft()
        DraftStore.remove(id: draft.id)
        drafts = DraftStore.loadDrafts()
        currentDraftIndex = 0
        reloadDraft()
    }

    @objc
    private func showPreviousDraft() {
        guard !drafts.isEmpty else { return }
        currentDraftIndex = (currentDraftIndex - 1 + drafts.count) % drafts.count
        reloadDraft()
    }

    @objc
    private func showNextDraft() {
        guard !drafts.isEmpty else { return }
        currentDraftIndex = (currentDraftIndex + 1) % drafts.count
        reloadDraft()
    }

    @objc
    private func refreshDrafts() {
        reloadDraft()
    }

    @objc
    private func toggleVoiceInput() {
        let snapshot = FlowSessionStore.loadSnapshot()
        switch snapshot.phase {
        case .starting:
            FlowSessionStore.reset()
            pendingRecognitionText = nil
            deliveredRecognitionText = nil
            activeRecognitionProfile = nil
            reloadDraft()
            statusLabel.text = "Flow cancelled"
            latestDraftLabel.text = "Tap Mic to start again."
            metaLabel.text = "No active recording"
            return
        case .recording, .processing:
            FlowSessionStore.requestStop(sessionID: snapshot.id)
            statusLabel.text = "Stopping Flow"
            metaLabel.text = "Waiting for Shinsoku to finish"
            updateMicButton()
            return
        case .done:
            FlowSessionStore.reset()
            pendingRecognitionText = nil
            deliveredRecognitionText = nil
            activeRecognitionProfile = nil
            reloadDraft()
        case .failed, .idle:
            break
        }

        pendingRecognitionText = nil
        deliveredRecognitionText = nil
        let profile = VoiceProfileStore.loadSelectedProfile()
        activeRecognitionProfile = profile
        let request = FlowSessionStore.requestStart(profileID: profile.id)
        latestDraftLabel.text = "Opening Shinsoku to start microphone..."
        metaLabel.text = "\(recognitionMode().title) · \(profile.behaviorSummary)"
        statusLabel.text = "Starting Flow"
        updateMicButton()
        openContainerURL(URL(string: "shinsoku://flow/start?id=\(request.id.uuidString)")!)
    }

    @objc
    private func deleteBackward() {
        textDocumentProxy.deleteBackward()
    }

    @objc
    private func startBackspaceRepeat() {
        stopBackspaceRepeat()
        deleteBackward()
        backspaceRepeatTimer = Timer.scheduledTimer(withTimeInterval: 0.36, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.deleteBackward()
            self.backspaceRepeatTimer = Timer.scheduledTimer(withTimeInterval: 0.055, repeats: true) { [weak self] _ in
                self?.deleteBackward()
            }
        }
    }

    @objc
    private func stopBackspaceRepeat() {
        backspaceRepeatTimer?.invalidate()
        backspaceRepeatTimer = nil
    }

    @objc
    private func insertSpace() {
        textDocumentProxy.insertText(" ")
    }

    @objc
    private func insertNewline() {
        textDocumentProxy.insertText("\n")
    }

    @objc
    private func handleSpaceTracking(_ sender: UILongPressGestureRecognizer) {
        let location = sender.location(in: view)
        switch sender.state {
        case .began:
            spaceTrackingLastLocation = location
            spaceTrackingRemainder = .zero
            hideKeyLabelsForSpaceTracking()
        case .changed:
            guard let lastLocation = spaceTrackingLastLocation else {
                spaceTrackingLastLocation = location
                return
            }
            moveCursorForSpaceTracking(from: lastLocation, to: location)
            spaceTrackingLastLocation = location
        case .ended, .cancelled, .failed:
            spaceTrackingLastLocation = nil
            spaceTrackingRemainder = .zero
            restoreKeyLabelsAfterSpaceTracking()
        default:
            break
        }
    }

    private func moveCursorForSpaceTracking(from start: CGPoint, to end: CGPoint) {
        spaceTrackingRemainder.x += end.x - start.x

        let horizontalSteps = Int(spaceTrackingRemainder.x / 12)

        if horizontalSteps != 0 {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: horizontalSteps)
            spaceTrackingRemainder.x -= CGFloat(horizontalSteps * 12)
        }
    }

    private func hideKeyLabelsForSpaceTracking() {
        let buttons = [profileButton, moreButton, micButton, spaceButton, backspaceButton, enterButton]
        hiddenButtonConfigurations = buttons.map { ($0, $0.configuration) }
        for button in buttons {
            button.configuration?.title = ""
            button.configuration?.image = nil
        }
    }

    private func restoreKeyLabelsAfterSpaceTracking() {
        for (button, configuration) in hiddenButtonConfigurations {
            button.configuration = configuration
        }
        hiddenButtonConfigurations.removeAll()
        updateMicButton()
    }

    private func selectProfile(_ profile: VoiceProfile) {
        VoiceProfileStore.saveSelectedProfile(profile)
        reloadDraft()
    }

    private func cycleProfile() {
        let profiles = VoiceProfile.defaults
        let current = VoiceProfileStore.loadSelectedProfile()
        guard let index = profiles.firstIndex(of: current) else {
            VoiceProfileStore.saveSelectedProfile(profiles[0])
            reloadDraft()
            return
        }
        let next = profiles[(index + 1) % profiles.count]
        VoiceProfileStore.saveSelectedProfile(next)
        reloadDraft()
    }

    private func profileMenu(selectedProfile: VoiceProfile) -> UIMenu {
        UIMenu(title: "Profile", children: VoiceProfile.defaults.map { profile in
            UIAction(
                title: profile.title,
                state: profile.id == selectedProfile.id ? .on : .off
            ) { [weak self] _ in
                self?.selectProfile(profile)
            }
        })
    }

    private func moreMenu() -> UIMenu {
        UIMenu(title: "Shinsoku", children: [
            UIAction(title: "Insert latest", image: UIImage(systemName: "text.insert")) { [weak self] _ in
                self?.insertCurrentDraft()
            },
            UIAction(title: "Paste clipboard", image: UIImage(systemName: "doc.on.clipboard")) { [weak self] _ in
                self?.insertClipboardContents()
            },
            UIAction(title: "Hide keyboard", image: UIImage(systemName: "keyboard.chevron.compact.down")) { [weak self] _ in
                self?.hideKeyboard()
            },
            UIAction(title: "Open drafts", image: UIImage(systemName: "doc.text")) { [weak self] _ in
                self?.openContainerApp()
            },
            UIAction(title: "Settings", image: UIImage(systemName: "gearshape")) { [weak self] _ in
                self?.openSettings()
            },
            UIAction(title: "Home", image: UIImage(systemName: "house")) { [weak self] _ in
                self?.openHome()
            },
            UIAction(title: "Refresh drafts", image: UIImage(systemName: "arrow.clockwise")) { [weak self] _ in
                self?.refreshDrafts()
            },
            UIAction(title: "Next keyboard", image: UIImage(systemName: "globe")) { [weak self] _ in
                self?.advanceToNextInputMode()
            },
        ])
    }

    @objc
    private func hideKeyboard() {
        dismissKeyboard()
        view.endEditing(true)
    }

    @objc
    private func insertClipboardContents() {
        guard let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            statusLabel.text = "Clipboard is empty"
            metaLabel.text = "Copy text first, then try again"
            return
        }
        textDocumentProxy.insertText(text)
        statusLabel.text = "Clipboard pasted"
        metaLabel.text = "Inserted from system clipboard"
    }

    @objc
    private func openContainerApp() {
        clearFinishedFlowBeforeNavigation()
        guard let url = URL(string: "shinsoku://drafts") else { return }
        openContainerURL(url)
    }

    @objc
    private func openSettings() {
        clearFinishedFlowBeforeNavigation()
        guard let url = URL(string: "shinsoku://settings") else { return }
        openContainerURL(url)
    }

    @objc
    private func openHome() {
        clearFinishedFlowBeforeNavigation()
        guard let url = URL(string: "shinsoku://home") else { return }
        openContainerURL(url)
    }

    private func clearFinishedFlowBeforeNavigation() {
        switch FlowSessionStore.loadSnapshot().phase {
        case .idle, .done, .failed:
            FlowSessionStore.reset()
            pendingRecognitionText = nil
            deliveredRecognitionText = nil
            activeRecognitionProfile = nil
        case .starting, .recording, .processing:
            break
        }
    }

    private func openContainerURL(_ url: URL) {
        extensionContext?.open(url) { [weak self] success in
            guard !success else { return }
            DispatchQueue.main.async {
                self?.openContainerURLViaResponderChain(url)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.openContainerURLViaResponderChain(url)
        }
    }

    private func openContainerURLViaResponderChain(_ url: URL) {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: selector) {
                _ = current.perform(selector, with: url)
                return
            }
            responder = current.next
        }
    }

    private func bindTranscriber() {
        transcriber.refreshAuthorizationState()
        transcriber.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateFromTranscriber()
                }
            }
            .store(in: &cancellables)
    }

    private func startFlowPolling() {
        flowPollTimer?.invalidate()
        flowPollTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            self?.updateFromFlowSession()
        }
        updateFromFlowSession()
    }

    private func updateFromFlowSession() {
        let snapshot = FlowSessionStore.loadSnapshot()
        guard snapshot.phase != .idle else {
            updateMicButton()
            return
        }

        updateMicButton()
        switch snapshot.phase {
        case .starting:
            statusLabel.text = "Starting Flow"
            latestDraftLabel.text = "Switching to Shinsoku to activate the microphone..."
            metaLabel.text = "Swipe back after recording starts"
        case .recording:
            statusLabel.text = "Flow recording"
            latestDraftLabel.text = snapshot.partialText.isEmpty ? "Listening..." : snapshot.partialText
            metaLabel.text = "Tap Stop when finished"
        case .processing:
            statusLabel.text = "Flow processing"
            latestDraftLabel.text = snapshot.partialText.isEmpty ? "Processing..." : snapshot.partialText
            metaLabel.text = "Finalizing transcript"
        case .done:
            statusLabel.text = "Flow ready"
            latestDraftLabel.text = snapshot.finalText.isEmpty ? "No transcript returned." : snapshot.finalText
            let finalText = snapshot.finalText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !finalText.isEmpty else {
                metaLabel.text = "No final transcript"
                pendingRecognitionText = nil
                insertButton.isEnabled = false
                return
            }

            let profile = VoiceProfileStore.loadSelectedProfile()
            if profile.autoCommit, deliveredRecognitionText != finalText {
                deliveredRecognitionText = finalText
                commitRecognizedText(finalText)
                FlowSessionStore.reset()
                reloadDraft()
                return
            }

            metaLabel.text = "Copied to clipboard · More has insert fallback"
            pendingRecognitionText = finalText
            insertButton.isEnabled = false
        case .failed:
            statusLabel.text = "Flow failed"
            latestDraftLabel.text = snapshot.errorMessage.isEmpty ? "Flow failed." : snapshot.errorMessage
            metaLabel.text = "Tap Mic to retry"
        case .idle:
            break
        }
    }

    private func updateFromTranscriber() {
        updateMicButton()

        if let error = transcriber.errorMessage, !error.isEmpty {
            statusLabel.text = error
            latestDraftLabel.text = error
            metaLabel.text = "Voice input failed"
            insertButton.isEnabled = pendingRecognitionText != nil
            insertAndClearButton.isEnabled = pendingRecognitionText != nil
            return
        }

        if transcriber.isRecording {
            statusLabel.text = recognitionMode().isStreaming ? "Streaming" : "Listening"
            latestDraftLabel.text = transcriber.transcript.isEmpty ? "Listening..." : transcriber.transcript
            let profileSummary = activeRecognitionProfile?.behaviorSummary ?? VoiceProfileStore.loadSelectedProfile().behaviorSummary
            metaLabel.text = "\(recognitionMode().title) · \(profileSummary)"
            return
        }

        if transcriber.isProcessing {
            statusLabel.text = "Processing"
            latestDraftLabel.text = transcriber.transcript.isEmpty ? "Processing..." : transcriber.transcript
            metaLabel.text = "Transcribing and applying post-processing"
            return
        }

        let text = transcriber.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              text != "Listening...",
              text != "Transcribing...",
              deliveredRecognitionText != text else {
            return
        }

        deliveredRecognitionText = text
        let profile = activeRecognitionProfile ?? VoiceProfileStore.loadSelectedProfile()
        if profile.autoCommit {
            commitRecognizedText(text)
            clearPendingRecognition()
        } else {
            pendingRecognitionText = text
            latestDraftLabel.text = text
            metaLabel.text = "Copied to clipboard · \(profile.title)"
            insertButton.isEnabled = false
            insertAndClearButton.isEnabled = true
        }
    }

    private func updateMicButton() {
        switch FlowSessionStore.loadSnapshot().phase {
        case .starting, .recording, .processing:
            micButton.configuration?.title = "Stop"
        case .done:
            micButton.configuration?.title = "Mic"
        case .failed:
            micButton.configuration?.title = "Retry"
        case .idle:
            micButton.configuration?.title = "Mic"
        }
    }

    private func recognitionMode() -> (title: String, isStreaming: Bool) {
        switch VoiceProviderConfigStore.loadProviderConfig().activeRecognitionProvider {
        case .androidSystem:
            return ("Apple Speech", false)
        case .openAiCompatible:
            return ("OpenAI batch", false)
        case .soniox:
            return ("Soniox streaming", true)
        case .bailian:
            return ("Bailian streaming", true)
        }
    }

    private func commitRecognizedText(_ text: String) {
        let profile = activeRecognitionProfile ?? VoiceProfileStore.loadSelectedProfile()
        textDocumentProxy.insertText(text + profile.commitSuffix)
    }

    private func clearPendingRecognition() {
        pendingRecognitionText = nil
        deliveredRecognitionText = nil
        activeRecognitionProfile = nil
        FlowSessionStore.reset()
        transcriber.stop(resetTranscript: true)
        reloadDraft()
    }

    private func filledConfiguration(title: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 7, leading: 12, bottom: 7, trailing: 12)
        configuration.baseBackgroundColor = .label
        configuration.baseForegroundColor = .systemBackground
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 15, weight: .semibold)
            return outgoing
        }
        return configuration
    }

    private func outlineConfiguration(title: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 7, leading: 10, bottom: 7, trailing: 10)
        configuration.baseForegroundColor = .label
        configuration.background.backgroundColor = keyBackgroundColor
        configuration.background.strokeColor = keyStrokeColor
        configuration.background.strokeWidth = 0.8
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 13, weight: .semibold)
            return outgoing
        }
        return configuration
    }

    private func iconConfiguration(systemName: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: systemName)
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 7, leading: 10, bottom: 7, trailing: 10)
        configuration.baseForegroundColor = .label
        configuration.background.backgroundColor = keyBackgroundColor
        configuration.background.strokeColor = keyStrokeColor
        configuration.background.strokeWidth = 0.8
        return configuration
    }

    private var keyBackgroundColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.10)
                : UIColor(white: 0.0, alpha: 0.045)
        }
    }

    private var keyStrokeColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.12)
                : UIColor(white: 0.0, alpha: 0.08)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
