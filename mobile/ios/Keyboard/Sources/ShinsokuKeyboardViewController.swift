import UIKit

final class ShinsokuKeyboardViewController: UIInputViewController {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let profileLabel = UILabel()
    private let latestDraftLabel = UILabel()
    private let insertButton = UIButton(type: .system)
    private let nextKeyboardButton = UIButton(type: .system)
    private let stackView = UIStackView()

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

        insertButton.configuration = .filled()
        insertButton.configuration?.title = "Insert latest"
        insertButton.addTarget(self, action: #selector(insertLatestDraft), for: .touchUpInside)

        nextKeyboardButton.configuration = .tinted()
        nextKeyboardButton.configuration?.title = "Next keyboard"
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(profileLabel)
        stackView.addArrangedSubview(latestDraftLabel)

        let buttonRow = UIStackView(arrangedSubviews: [insertButton, nextKeyboardButton])
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
            insertButton.heightAnchor.constraint(equalToConstant: 46),
            nextKeyboardButton.heightAnchor.constraint(equalToConstant: 46),
        ])
    }

    private func reloadDraft() {
        let profile = VoiceProfileStore.loadSelectedProfile()
        profileLabel.text = profile.title

        if let draft = DraftStore.loadDrafts().first {
            latestDraftLabel.text = draft.text
            insertButton.isEnabled = true
        } else {
            latestDraftLabel.text = "Open the Shinsoku app, dictate a phrase, then come back here to insert it."
            insertButton.isEnabled = false
        }
    }

    @objc
    private func insertLatestDraft() {
        guard let draft = DraftStore.loadDrafts().first else { return }
        textDocumentProxy.insertText(draft.text)
    }
}
