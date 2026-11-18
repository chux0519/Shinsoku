import UIKit

/// One key of the Shinsoku keyboard (mirrors `SkKey` in DESIGN.md §5).
/// Pressed state is a fill change; disabled keys keep their size but dim their content.
final class KeyboardKey: UIControl {
    enum Style {
        case raised
        case accent
    }

    let style: Style
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let stack = UIStackView()

    init(style: Style, symbol: String?, title: String?, axis: NSLayoutConstraint.Axis = .horizontal) {
        self.style = style
        super.init(frame: .zero)
        layer.cornerRadius = KeyboardTheme.controlRadius
        layer.cornerCurve = .continuous

        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.font = style == .accent ? KeyboardTheme.keyTitleFont : KeyboardTheme.keyFont
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        titleLabel.textAlignment = .center
        detailLabel.font = KeyboardTheme.captionFont
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.textAlignment = .center
        detailLabel.isHidden = true

        stack.axis = axis
        stack.alignment = .center
        stack.spacing = axis == .horizontal ? 6 : 2
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
        ])
        setSymbol(symbol)
        setTitle(title)
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(detailLabel)

        isAccessibilityElement = true
        accessibilityTraits = .keyboardKey
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func setSymbol(_ name: String?, pointSize: CGFloat = 17) {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        iconView.image = name.flatMap { UIImage(systemName: $0, withConfiguration: config) }
        iconView.isHidden = iconView.image == nil
    }

    func setTitle(_ title: String?) {
        titleLabel.text = title
        titleLabel.isHidden = (title ?? "").isEmpty
    }

    func setDetail(_ detail: String?) {
        detailLabel.text = detail
        detailLabel.isHidden = (detail ?? "").isEmpty
    }

    override var isHighlighted: Bool {
        didSet { updateAppearance() }
    }

    /// Dimmed keys still receive taps (so they can explain why nothing happened) but look disabled.
    var isDimmed = false {
        didSet { updateAppearance() }
    }

    /// Extra hit area beyond the visible key, for keys drawn smaller than 44 pt.
    var hitOutset: UIEdgeInsets = .zero

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.inset(by: UIEdgeInsets(
            top: -hitOutset.top, left: -hitOutset.left, bottom: -hitOutset.bottom, right: -hitOutset.right
        )).contains(point)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateAppearance()
    }

    private func updateAppearance() {
        let foreground: UIColor
        let secondary: UIColor
        switch style {
        case .raised:
            backgroundColor = isHighlighted ? KeyboardTheme.raisedPressed : KeyboardTheme.raised
            foreground = isDimmed ? KeyboardTheme.textTertiary : KeyboardTheme.text
            secondary = isDimmed ? KeyboardTheme.textTertiary : KeyboardTheme.textSecondary
        case .accent:
            backgroundColor = isHighlighted ? KeyboardTheme.accentPressed : KeyboardTheme.accent
            foreground = KeyboardTheme.onAccent
            secondary = KeyboardTheme.onAccent
        }
        iconView.tintColor = foreground
        titleLabel.textColor = foreground
        detailLabel.textColor = secondary
    }
}
