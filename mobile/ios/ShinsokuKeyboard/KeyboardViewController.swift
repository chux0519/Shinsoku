import UIKit

final class KeyboardViewController: UIInputViewController {
    private let accentColor = UIColor(red: 0.0, green: 0.48, blue: 0.52, alpha: 1.0)
    private let hint = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemGroupedBackground
        buildKeyboard()
    }

    private func buildKeyboard() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8

        let title = UILabel()
        title.text = "Shinsoku"
        title.font = .preferredFont(forTextStyle: .headline)
        title.textColor = .label

        let subtitle = UILabel()
        subtitle.text = "Voice input"
        subtitle.font = .preferredFont(forTextStyle: .caption1)
        subtitle.textColor = .secondaryLabel

        let titleStack = UIStackView(arrangedSubviews: [title, subtitle])
        titleStack.axis = .vertical
        titleStack.spacing = 1

        let spacer = UIView()
        header.addArrangedSubview(titleStack)
        header.addArrangedSubview(spacer)

        let controls = UIStackView()
        controls.axis = .horizontal
        controls.spacing = 8
        controls.distribution = .fillEqually

        controls.addArrangedSubview(makeButton(title: "Dictate", image: "mic.fill", action: #selector(openDictationApp)))
        controls.addArrangedSubview(makeButton(title: "Paste", image: "text.cursor", action: #selector(pasteLatestText)))
        controls.addArrangedSubview(makeButton(title: "Next", image: "globe", action: #selector(nextKeyboard)))

        hint.text = "Open Shinsoku, record, then paste the latest text here."
        hint.font = .preferredFont(forTextStyle: .footnote)
        hint.textColor = .secondaryLabel
        hint.numberOfLines = 2

        stack.addArrangedSubview(header)
        stack.addArrangedSubview(controls)
        stack.addArrangedSubview(hint)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -10),
            controls.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func makeButton(title: String, image: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: image), for: .normal)
        button.tintColor = .white
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = accentColor
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .preferredFont(forTextStyle: .callout)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        button.semanticContentAttribute = .forceLeftToRight
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func pasteLatestText() {
        guard let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            hint.text = "No Shinsoku text is available yet."
            return
        }

        textDocumentProxy.insertText(text + " ")
        hint.text = "Inserted latest Shinsoku text."
    }

    @objc private func nextKeyboard() {
        advanceToNextInputMode()
    }

    @objc private func openDictationApp() {
        guard let url = URL(string: "shinsoku://dictation") else {
            return
        }
        extensionContext?.open(url, completionHandler: nil)
    }
}
