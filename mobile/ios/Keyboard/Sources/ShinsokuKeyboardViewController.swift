import UIKit

final class ShinsokuKeyboardViewController: UIInputViewController {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let profileLabel = UILabel()
    private let latestDraftLabel = UILabel()
    private let insertButton = UIButton(type: .system)
    private let previousButton = UIButton(type: .system)
    private let nextDraftButton = UIButton(type: .system)
    private let nextKeyboardButton = UIButton(type: .system)
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
        latestDraftLabel.translatesAutoresizingMaskIntoConstraints = false
        insertButton.translatesAutoresizingMaskIntoConstraints = false
        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = "Shinsoku"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        subtitleLabel.text = "Insert a saved draft"
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel

        profileLabel.font = .systemFont(ofSize: 13, weight: .medium)
        profileLabel.textColor = .secondaryLabel

        latestDraftLabel.numberOfLines = 4
        latestDraftLabel.font = .systemFont(ofSize: 17, weight: .regular)
        latestDraftLabel.text = "Open the Shinsoku app to create a draft."

        previousButton.configuration = .tinted()
        previousButton.configuration?.title = "Previous"
        previousButton.addTarget(self, action: #selector(showPreviousDraft), for: .touchUpInside)

        insertButton.configuration = .filled()
        insertButton.configuration?.title = "Insert"
        insertButton.addTarget(self, action: #selector(insertCurrentDraft), for: .touchUpInside)

        nextDraftButton.configuration = .tinted()
        nextDraftButton.configuration?.title = "Next draft"
        nextDraftButton.addTarget(self, action: #selector(showNextDraft), for: .touchUpInside)

        nextKeyboardButton.configuration = .tinted()
        nextKeyboardButton.configuration?.title = "Next keyboard"
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(profileLabel)
        stackView.addArrangedSubview(latestDraftLabel)

        let draftRow = UIStackView(arrangedSubviews: [previousButton, insertButton, nextDraftButton])
        draftRow.axis = .horizontal
        draftRow.spacing = 12
        draftRow.distribution = .fillEqually
        stackView.addArrangedSubview(draftRow)

        let buttonRow = UIStackView(arrangedSubviews: [nextKeyboardButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 12
        buttonRow.distribution = .fillEqually
        stackView.addArrangedSubview(buttonRow)

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18),
            previousButton.heightAnchor.constraint(equalToConstant: 46),
            insertButton.heightAnchor.constraint(equalToConstant: 46),
            nextDraftButton.heightAnchor.constraint(equalToConstant: 46),
            nextKeyboardButton.heightAnchor.constraint(equalToConstant: 46),
        ])
    }

    private func reloadDraft() {
        let profile = VoiceProfileStore.loadSelectedProfile()
        profileLabel.text = profile.title

        drafts = DraftStore.loadDrafts()
        currentDraftIndex = min(currentDraftIndex, max(drafts.count - 1, 0))
        guard let draft = drafts[safe: currentDraftIndex] else {
            latestDraftLabel.text = "Open the Shinsoku app, dictate a phrase, then come back here to insert it."
            insertButton.isEnabled = false
            previousButton.isEnabled = false
            nextDraftButton.isEnabled = false
            return
        }
        latestDraftLabel.text = draft.text
        insertButton.isEnabled = true
        previousButton.isEnabled = drafts.count > 1
        nextDraftButton.isEnabled = drafts.count > 1
    }

    @objc
    private func insertCurrentDraft() {
        guard let draft = drafts[safe: currentDraftIndex] else { return }
        textDocumentProxy.insertText(draft.text)
    }

    @objc
    private func showPreviousDraft() {
        guard !drafts.isEmpty else { return }
        currentDraftIndex = (currentDraftIndex - 1 + drafts.count) % drafts.count
        if let draft = drafts[safe: currentDraftIndex] {
            latestDraftLabel.text = draft.text
        }
    }

    @objc
    private func showNextDraft() {
        guard !drafts.isEmpty else { return }
        currentDraftIndex = (currentDraftIndex + 1) % drafts.count
        if let draft = drafts[safe: currentDraftIndex] {
            latestDraftLabel.text = draft.text
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
