import SwiftUI
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

        let primaryControls = UIStackView()
        primaryControls.axis = .horizontal
        primaryControls.spacing = 8
        primaryControls.distribution = .fillEqually

        primaryControls.addArrangedSubview(makeButton(title: "Record", image: "mic.fill", action: #selector(openDictationApp), style: .primary))
        primaryControls.addArrangedSubview(makeButton(title: "Paste", image: "doc.on.clipboard", action: #selector(pasteLatestText), style: .primary))

        let editingControls = UIStackView()
        editingControls.axis = .horizontal
        editingControls.spacing = 8
        editingControls.distribution = .fillEqually

        editingControls.addArrangedSubview(makeButton(title: "Return", image: "return", action: #selector(insertNewline), style: .secondary))
        editingControls.addArrangedSubview(makeButton(title: "Delete", image: "delete.left", action: #selector(deleteBackward), style: .secondary))
        editingControls.addArrangedSubview(makeButton(title: "Next", image: "globe", action: #selector(nextKeyboard), style: .secondary))

        hint.text = "Record in Shinsoku, then paste the latest text here. Enable Full Access for clipboard paste."
        hint.font = .preferredFont(forTextStyle: .footnote)
        hint.textColor = .secondaryLabel
        hint.numberOfLines = 2

        stack.addArrangedSubview(header)
        stack.addArrangedSubview(primaryControls)
        stack.addArrangedSubview(editingControls)
        stack.addArrangedSubview(hint)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -10),
            primaryControls.heightAnchor.constraint(equalToConstant: 44),
            editingControls.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private enum ButtonStyle {
        case primary
        case secondary
    }

    private func makeButton(title: String, image: String, action: Selector, style: ButtonStyle) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: image), for: .normal)
        switch style {
        case .primary:
            button.tintColor = .white
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = accentColor
        case .secondary:
            button.tintColor = accentColor
            button.setTitleColor(.label, for: .normal)
            button.backgroundColor = UIColor.secondarySystemGroupedBackground
        }
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
            hint.text = "No Shinsoku text is available. Record first and allow Full Access for clipboard paste."
            return
        }

        textDocumentProxy.insertText(text)
        hint.text = "Inserted latest Shinsoku text."
    }

    @objc private func insertNewline() {
        textDocumentProxy.insertText("\n")
        hint.text = "Inserted new line."
    }

    @objc private func deleteBackward() {
        textDocumentProxy.deleteBackward()
        hint.text = "Deleted one character."
    }

    @objc private func nextKeyboard() {
        advanceToNextInputMode()
    }

    @objc private func openDictationApp() {
        guard let url = URL(string: "shinsoku://dictation") else {
            return
        }
        hint.text = "Opening Shinsoku to record."
        if #available(iOS 14.0, *) {
            EnvironmentValues().openURL(url) { [weak self] accepted in
                if accepted {
                    self?.hint.text = "Opening Shinsoku to record."
                    return
                }
                self?.openWithExtensionContext(url)
            }
            return
        }
        openWithExtensionContext(url)
    }

    private func openWithExtensionContext(_ url: URL) {
        extensionContext?.open(url) { [weak self] completed in
            if completed {
                self?.hint.text = "Opening Shinsoku to record."
                return
            }
            self?.hint.text = "Open Shinsoku from the Home Screen, then return here to paste."
        }
    }
}
