import UIKit

final class ShinsokuKeyboardViewController: UIInputViewController {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let micButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureLayout()
    }

    private func configureLayout() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        micButton.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = "Shinsoku"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        subtitleLabel.text = "Keyboard scaffold"
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel

        micButton.configuration = .filled()
        micButton.configuration?.title = "Mic"

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(micButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            micButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            micButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            micButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18),
            micButton.widthAnchor.constraint(equalToConstant: 132),
            micButton.heightAnchor.constraint(equalToConstant: 48),
        ])
    }
}
