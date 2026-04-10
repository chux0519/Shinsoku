import UIKit

final class ShinsokuKeyboardViewController: UIInputViewController {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let profileLabel = UILabel()
    private let metaLabel = UILabel()
    private let statusLabel = UILabel()
    private let latestDraftLabel = UILabel()
    private let profileButton = UIButton(type: .system)
    private let insertButton = UIButton(type: .system)
    private let insertAndClearButton = UIButton(type: .system)
    private let openAppButton = UIButton(type: .system)
    private let openSettingsButton = UIButton(type: .system)
    private let previousButton = UIButton(type: .system)
    private let nextDraftButton = UIButton(type: .system)
    private let refreshButton = UIButton(type: .system)
    private let nextKeyboardButton = UIButton(type: .system)
    private let openHomeButton = UIButton(type: .system)
    private let stackView = UIStackView()
    private var drafts: [StoredDraft] = []
    private var currentDraftIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureLayout()
        reloadDraft()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadDraft()
    }

    private func configureLayout() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        profileLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        latestDraftLabel.translatesAutoresizingMaskIntoConstraints = false
        profileButton.translatesAutoresizingMaskIntoConstraints = false
        insertButton.translatesAutoresizingMaskIntoConstraints = false
        insertAndClearButton.translatesAutoresizingMaskIntoConstraints = false
        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = "Shinsoku"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        subtitleLabel.text = "Insert a saved draft"
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel

        profileLabel.font = .systemFont(ofSize: 13, weight: .medium)
        profileLabel.textColor = .secondaryLabel

        metaLabel.font = .systemFont(ofSize: 12, weight: .regular)
        metaLabel.textColor = .tertiaryLabel

        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 2

        latestDraftLabel.numberOfLines = 5
        latestDraftLabel.font = .systemFont(ofSize: 17, weight: .regular)
        latestDraftLabel.text = "Open the Shinsoku app to create a draft."
        latestDraftLabel.backgroundColor = .secondarySystemBackground
        latestDraftLabel.layer.cornerRadius = 18
        latestDraftLabel.layer.masksToBounds = true
        latestDraftLabel.textAlignment = .left
        latestDraftLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        profileButton.configuration = filledCapsuleConfiguration(title: "Cycle profile")
        profileButton.addTarget(self, action: #selector(cycleProfile), for: .touchUpInside)

        previousButton.configuration = outlineConfiguration(title: "Previous")
        previousButton.addTarget(self, action: #selector(showPreviousDraft), for: .touchUpInside)

        insertButton.configuration = filledCapsuleConfiguration(title: "Insert")
        insertButton.addTarget(self, action: #selector(insertCurrentDraft), for: .touchUpInside)

        insertAndClearButton.configuration = outlineConfiguration(title: "Insert & remove")
        insertAndClearButton.addTarget(self, action: #selector(insertAndRemoveCurrentDraft), for: .touchUpInside)

        nextDraftButton.configuration = outlineConfiguration(title: "Next draft")
        nextDraftButton.addTarget(self, action: #selector(showNextDraft), for: .touchUpInside)

        openAppButton.configuration = outlineConfiguration(title: "Open drafts")
        openAppButton.addTarget(self, action: #selector(openContainerApp), for: .touchUpInside)

        openSettingsButton.configuration = outlineConfiguration(title: "Settings")
        openSettingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)

        refreshButton.configuration = outlineConfiguration(title: "Refresh")
        refreshButton.addTarget(self, action: #selector(refreshDrafts), for: .touchUpInside)

        openHomeButton.configuration = outlineConfiguration(title: "Home")
        openHomeButton.addTarget(self, action: #selector(openHome), for: .touchUpInside)

        nextKeyboardButton.configuration = outlineConfiguration(title: "Next keyboard")
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = .init(top: 18, leading: 18, bottom: 18, trailing: 18)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)

        let profileRow = UIStackView(arrangedSubviews: [profileLabel, profileButton])
        profileRow.axis = .horizontal
        profileRow.spacing = 12
        profileRow.alignment = .center
        stackView.addArrangedSubview(profileRow)

        stackView.addArrangedSubview(metaLabel)
        stackView.addArrangedSubview(statusLabel)
        stackView.addArrangedSubview(latestDraftLabel)

        let draftRow = UIStackView(arrangedSubviews: [previousButton, insertButton, nextDraftButton])
        draftRow.axis = .horizontal
        draftRow.spacing = 10
        draftRow.distribution = .fillEqually
        stackView.addArrangedSubview(draftRow)

        let utilityRow = UIStackView(arrangedSubviews: [insertAndClearButton, openAppButton, openHomeButton])
        utilityRow.axis = .horizontal
        utilityRow.spacing = 10
        utilityRow.distribution = .fillEqually
        stackView.addArrangedSubview(utilityRow)

        let keyboardRow = UIStackView(arrangedSubviews: [openSettingsButton, refreshButton, nextKeyboardButton])
        keyboardRow.axis = .horizontal
        keyboardRow.spacing = 10
        keyboardRow.distribution = .fillEqually
        stackView.addArrangedSubview(keyboardRow)

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            latestDraftLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 96),
            previousButton.heightAnchor.constraint(equalToConstant: 42),
            insertButton.heightAnchor.constraint(equalToConstant: 42),
            nextDraftButton.heightAnchor.constraint(equalToConstant: 42),
            insertAndClearButton.heightAnchor.constraint(equalToConstant: 42),
            openAppButton.heightAnchor.constraint(equalToConstant: 42),
            openHomeButton.heightAnchor.constraint(equalToConstant: 42),
            openSettingsButton.heightAnchor.constraint(equalToConstant: 42),
            refreshButton.heightAnchor.constraint(equalToConstant: 42),
            nextKeyboardButton.heightAnchor.constraint(equalToConstant: 42),
        ])

        view.backgroundColor = .secondarySystemBackground
        stackView.backgroundColor = .systemBackground
        stackView.layer.cornerRadius = 22
        stackView.layer.cornerCurve = .continuous
        stackView.layer.masksToBounds = true
    }

    private func reloadDraft() {
        let profile = VoiceProfileStore.loadSelectedProfile()
        profileLabel.text = profile.title
        profileButton.configuration?.title = "Mode: \(profile.mode.title)"

        drafts = DraftStore.loadDrafts()
        let diagnostics = DraftStore.diagnostics()
        currentDraftIndex = min(currentDraftIndex, max(drafts.count - 1, 0))
        statusLabel.text = diagnosticsStatusText(for: diagnostics)
        openAppButton.isEnabled = hasFullAccess
        openSettingsButton.isEnabled = hasFullAccess

        guard let draft = drafts[safe: currentDraftIndex] else {
            latestDraftLabel.text = hasFullAccess
                ? "Open the Shinsoku app, dictate a phrase, save a draft, then come back here to insert it."
                : "Enable Full Access for Shinsoku Keyboard, then create a draft in the app to keep the keyboard in sync."
            metaLabel.text = hasFullAccess ? "No shared drafts yet" : "Full Access is off"
            insertButton.isEnabled = false
            insertAndClearButton.isEnabled = false
            previousButton.isEnabled = false
            nextDraftButton.isEnabled = false
            return
        }
        latestDraftLabel.text = draft.text
        metaLabel.text = "\(profile.title) · \(currentDraftIndex + 1)/\(drafts.count) · \(DisplayFormatting.relativeTimestamp(for: draft.updatedAt))"
        insertButton.isEnabled = true
        insertAndClearButton.isEnabled = true
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
        guard let draft = drafts[safe: currentDraftIndex] else { return }
        let profile = VoiceProfileStore.loadSelectedProfile()
        textDocumentProxy.insertText(draft.text + profile.commitSuffix)
    }

    @objc
    private func insertAndRemoveCurrentDraft() {
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

    @objc
    private func openContainerApp() {
        guard let url = URL(string: "shinsoku://drafts") else { return }
        openURL(url)
    }

    @objc
    private func openSettings() {
        guard let url = URL(string: "shinsoku://settings") else { return }
        openURL(url)
    }

    @objc
    private func openHome() {
        guard let url = URL(string: "shinsoku://home") else { return }
        openURL(url)
    }

    private func openURL(_ url: URL) {
        extensionContext?.open(url) { _ in }
    }

    private func filledCapsuleConfiguration(title: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = .label
        configuration.baseForegroundColor = .systemBackground
        return configuration
    }

    private func outlineConfiguration(title: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.bordered()
        configuration.title = title
        configuration.cornerStyle = .capsule
        return configuration
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
