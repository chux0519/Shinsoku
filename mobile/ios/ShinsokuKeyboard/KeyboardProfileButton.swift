import UIKit

/// profile-01 P3: the active profile name in the status row (DESIGN.md §6). Secondary text, one line,
/// truncates; drawn 28 pt high inside the status row with a 44 pt hit area. Tap cycles (handled by the
/// controller); long-press opens `menu` (the profile list). Read-only (no Full Access, PR4): a lock glyph and no
/// menu.
final class KeyboardProfileButton: UIButton {
    /// Extra hit area beyond the drawn button, so the 28 pt status row still gives a 44 pt target.
    var hitOutset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

    init() {
        super.init(frame: .zero)
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)
        config.imagePadding = 4
        config.titleLineBreakMode = .byTruncatingTail
        config.baseForegroundColor = KeyboardTheme.textSecondary
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = KeyboardTheme.statusFont
            return attributes
        }
        configuration = config
        showsMenuAsPrimaryAction = false
        titleLabel?.lineBreakMode = .byTruncatingTail
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// `readOnly`: lock glyph before the name; otherwise a small up/down chevron after it.
    func show(name: String, readOnly: Bool) {
        guard var config = configuration else { return }
        config.title = name
        config.image = UIImage(systemName: readOnly ? "lock.fill" : "chevron.up.chevron.down")
        config.imagePlacement = readOnly ? .leading : .trailing
        configuration = config
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.inset(by: UIEdgeInsets(
            top: -hitOutset.top, left: -hitOutset.left, bottom: -hitOutset.bottom, right: -hitOutset.right
        )).contains(point)
    }
}

extension FieldKind {
    /// Field kind from what the host tells the keyboard. First match wins:
    /// email (keyboard or content type) → url (URL keyboard) → search (web-search keyboard, e.g. Safari's
    /// address bar, or a search/Google/Yahoo return key) → url (URL content type) → message (Send return key)
    /// → other.
    static func detect(
        keyboardType: UIKeyboardType?, textContentType: UITextContentType?, returnKeyType: UIReturnKeyType?
    ) -> FieldKind {
        if keyboardType == .emailAddress || textContentType == .emailAddress { return .email }
        if keyboardType == .URL { return .url }
        if keyboardType == .webSearch { return .search }
        switch returnKeyType {
        case .search, .google, .yahoo: return .search
        default: break
        }
        if textContentType == .URL { return .url }
        if returnKeyType == .send { return .message }
        return .other
    }

    static func detect(_ proxy: UITextDocumentProxy) -> FieldKind {
        detect(keyboardType: proxy.keyboardType, textContentType: proxy.textContentType,
               returnKeyType: proxy.returnKeyType)
    }
}
