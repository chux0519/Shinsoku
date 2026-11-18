import OSLog
import SwiftUI
import UIKit

/// Shinsoku keyboard (DESIGN.md §6): status row, main row (Insert latest · Record · Delete), edit row
/// (Space · Return). No title row, no scrolling, no settings.
final class KeyboardViewController: UIInputViewController {
    private enum Status {
        case ready
        case latestReady
        case noLatest
        case needsFullAccess
        case inserted
        case insertedAgain
        case opening
        case openFailed

        var symbol: String {
            switch self {
            case .ready, .noLatest: return "mic"
            case .latestReady: return "text.badge.checkmark"
            case .needsFullAccess, .openFailed: return "exclamationmark.triangle"
            case .inserted, .insertedAgain: return "checkmark.circle"
            case .opening: return "arrow.up.forward.app"
            }
        }

        var text: String {
            switch self {
            case .ready: return "Ready"
            case .latestReady: return "Latest text ready"
            case .noLatest: return "Nothing yet — tap Record"
            case .needsFullAccess: return "Turn on Full Access to insert"
            case .inserted: return "Inserted"
            case .insertedAgain: return "Inserted again"
            case .opening: return "Opening Shinsoku…"
            case .openFailed: return "Open Shinsoku from the Home Screen"
            }
        }

        var tint: UIColor {
            switch self {
            case .needsFullAccess, .openFailed: return KeyboardTheme.warning
            case .inserted, .insertedAgain: return KeyboardTheme.success
            default: return KeyboardTheme.textSecondary
            }
        }
    }

    private let statusIcon = UIImageView()
    private let statusLabel = UILabel()
    private let globeKey = KeyboardKey(style: .raised, symbol: "globe", title: nil)
    private let insertKey = KeyboardKey(style: .raised, symbol: "text.insert", title: "Insert", axis: .vertical)
    private let recordKey = KeyboardKey(style: .accent, symbol: "mic.fill", title: "Record", axis: .vertical)
    private let deleteKey = KeyboardKey(style: .raised, symbol: "delete.left", title: nil)
    private let spaceKey = KeyboardKey(style: .raised, symbol: nil, title: "space")
    private let returnKey = KeyboardKey(style: .raised, symbol: nil, title: "return")

    private var heightConstraint: NSLayoutConstraint?
    private var latest = LatestTextStore.State.none

    private let deleteRepeater = KeyRepeater()
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private let insertFeedback = UINotificationFeedbackGenerator()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = KeyboardTheme.frame
        NotificationCenter.default.addObserver(
            self, selector: #selector(hostDidBecomeActive), name: .NSExtensionHostDidBecomeActive, object: nil
        )
        buildLayout()
        wireActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshState(reason: "viewWillAppear")
    }

    /// When the user comes back to the host app, the keyboard can stay on screen without a new
    /// viewWillAppear; re-read the App Group then too (the reason is logged).
    @objc private func hostDidBecomeActive() {
        refreshState(reason: "hostDidBecomeActive")
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        globeKey.isHidden = !needsInputModeSwitchKey
        heightConstraint?.constant = Self.preferredHeight(for: view.bounds.size, traits: traitCollection)
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateReturnKey()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        deleteRepeater.stop()
    }

    // MARK: Layout

    /// Matches the system keyboard: 216 pt on portrait phones (226 on wide ones), 176 in landscape.
    private static func preferredHeight(for size: CGSize, traits: UITraitCollection) -> CGFloat {
        if traits.verticalSizeClass == .compact {
            return 176
        }
        return size.width >= 400 ? 226 : 216
    }

    private func buildLayout() {
        let statusRow = UIStackView()
        statusRow.axis = .horizontal
        statusRow.alignment = .center
        statusRow.spacing = 6
        statusIcon.contentMode = .scaleAspectFit
        statusIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        statusIcon.setContentHuggingPriority(.required, for: .horizontal)
        statusLabel.font = KeyboardTheme.statusFont
        statusLabel.textColor = KeyboardTheme.textSecondary
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let statusSpacer = UIView()
        statusSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusRow.addArrangedSubview(statusIcon)
        statusRow.addArrangedSubview(statusLabel)
        statusRow.addArrangedSubview(statusSpacer)
        statusRow.addArrangedSubview(globeKey)
        statusRow.isAccessibilityElement = false
        statusLabel.accessibilityTraits = .updatesFrequently

        let mainRow = UIStackView(arrangedSubviews: [insertKey, recordKey, deleteKey])
        mainRow.axis = .horizontal
        mainRow.spacing = KeyboardTheme.spacing
        mainRow.alignment = .fill

        let editRow = UIStackView(arrangedSubviews: [spaceKey, returnKey])
        editRow.axis = .horizontal
        editRow.spacing = KeyboardTheme.spacing
        editRow.alignment = .fill

        let column = UIStackView(arrangedSubviews: [statusRow, mainRow, editRow])
        column.axis = .vertical
        column.spacing = KeyboardTheme.spacing
        column.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(column)

        let margin = KeyboardTheme.margin
        let height = view.heightAnchor.constraint(equalToConstant: 216)
        height.priority = .defaultHigh + 1
        heightConstraint = height

        // Edit row prefers 48 pt (never below 40); the main row takes the rest (never below 56).
        let editRowHeight = editRow.heightAnchor.constraint(equalToConstant: 48)
        editRowHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            height,
            column.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: margin),
            column.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -margin),
            column.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            column.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -margin),

            statusRow.heightAnchor.constraint(equalToConstant: KeyboardTheme.statusRowHeight),
            globeKey.widthAnchor.constraint(equalToConstant: 44),
            globeKey.heightAnchor.constraint(equalToConstant: KeyboardTheme.statusRowHeight),

            mainRow.heightAnchor.constraint(greaterThanOrEqualToConstant: KeyboardTheme.minRecordHeight),
            editRowHeight,
            editRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),

            // Record is the largest key; Insert and Delete share the rest.
            recordKey.widthAnchor.constraint(equalTo: mainRow.widthAnchor, multiplier: 0.42),
            insertKey.widthAnchor.constraint(equalTo: deleteKey.widthAnchor, multiplier: 1.4),

            returnKey.widthAnchor.constraint(equalTo: editRow.widthAnchor, multiplier: 0.3),
        ])

        // The globe key sits in the 28 pt status row; extend its hit area to 44 pt.
        globeKey.hitOutset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

        insertKey.accessibilityLabel = "Insert latest text"
        recordKey.accessibilityLabel = "Record"
        recordKey.accessibilityHint = "Opens Shinsoku to record"
        deleteKey.accessibilityLabel = "Delete"
        spaceKey.accessibilityLabel = "Space"
        returnKey.accessibilityLabel = "Return"
        globeKey.accessibilityLabel = "Next keyboard"
        recordKey.setSymbol("mic.fill", pointSize: 22)
        deleteKey.setSymbol("delete.left", pointSize: 20)
    }

    private func wireActions() {
        insertKey.addTarget(self, action: #selector(insertLatestText), for: .touchUpInside)
        recordKey.addTarget(self, action: #selector(recordTouchDown), for: .touchDown)
        recordKey.addTarget(self, action: #selector(openDictationApp), for: .touchUpInside)
        spaceKey.addTarget(self, action: #selector(insertSpace), for: .touchUpInside)
        returnKey.addTarget(self, action: #selector(insertReturn), for: .touchUpInside)
        globeKey.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        deleteKey.addTarget(self, action: #selector(deleteTouchDown), for: .touchDown)
        deleteKey.addTarget(self, action: #selector(deleteTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        deleteRepeater.onTick = { [weak self] wordMode in
            self?.deleteOnce(wordMode: wordMode)
        }
    }

    // MARK: State

    private func refreshState(reason: String) {
        updateReturnKey()
        guard hasFullAccess else {
            latest = .none
            updateInsertKey()
            setStatus(.needsFullAccess, announce: false)
            return
        }
        latest = LatestTextStore.state(reason: reason)
        updateInsertKey()
        setStatus(latest == .new ? .latestReady : .ready, announce: false)
    }

    /// Never shows the text itself: not on screen, not in accessibility values.
    private func updateInsertKey() {
        insertKey.isDimmed = !hasFullAccess || latest == .none
        insertKey.accessibilityLabel = "Insert latest text"
        switch (hasFullAccess, latest) {
        case (false, _): insertKey.accessibilityValue = "Needs Full Access"
        case (true, .new): insertKey.accessibilityValue = "New Shinsoku text"
        case (true, .inserted): insertKey.accessibilityValue = "Already inserted"
        case (true, .none): insertKey.accessibilityValue = "Nothing yet"
        }
    }

    private func updateReturnKey() {
        let title: String
        switch textDocumentProxy.returnKeyType ?? .default {
        case .go: title = "go"
        case .google, .yahoo, .search: title = "search"
        case .join: title = "join"
        case .next: title = "next"
        case .route: title = "route"
        case .send: title = "send"
        case .done: title = "done"
        case .emergencyCall: title = "call"
        case .continue: title = "continue"
        default: title = "return"
        }
        returnKey.setTitle(title)
        returnKey.accessibilityLabel = title.capitalized
    }

    private func setStatus(_ newStatus: Status, announce: Bool = true) {
        statusIcon.image = UIImage(systemName: newStatus.symbol)
        statusIcon.tintColor = newStatus.tint
        statusLabel.text = newStatus.text
        if announce {
            UIAccessibility.post(notification: .announcement, argument: newStatus.text)
        }
    }

    // MARK: Actions

    @objc private func insertLatestText() {
        guard hasFullAccess else {
            setStatus(.needsFullAccess)
            return
        }
        guard let entry = LatestTextStore.latest() else {
            latest = .none
            updateInsertKey()
            setStatus(.noLatest)
            return
        }
        let again = entry.id == LatestTextStore.lastInsertedId()
        let text = entry.text
        textDocumentProxy.insertText(text)
        LatestTextStore.markInserted(entry.id)
        latest = .inserted
        updateInsertKey()
        insertFeedback.notificationOccurred(.success)
        setStatus(again ? .insertedAgain : .inserted)
    }

    @objc private func insertSpace() {
        textDocumentProxy.insertText(" ")
    }

    @objc private func insertReturn() {
        textDocumentProxy.insertText("\n")
    }

    @objc private func deleteTouchDown() {
        deleteOnce(wordMode: false)
        deleteRepeater.start()
    }

    @objc private func deleteTouchUp() {
        deleteRepeater.stop()
    }

    private func deleteOnce(wordMode: Bool) {
        guard wordMode, let before = textDocumentProxy.documentContextBeforeInput, !before.isEmpty else {
            textDocumentProxy.deleteBackward()
            return
        }
        // Word mode: trailing whitespace plus the word before it.
        var count = 0
        var seenWord = false
        for character in before.reversed() {
            if character.isWhitespace || character.isNewline {
                if seenWord { break }
            } else {
                seenWord = true
            }
            count += 1
        }
        for _ in 0..<max(count, 1) {
            textDocumentProxy.deleteBackward()
        }
    }

    @objc private func recordTouchDown() {
        haptic.prepare()
        haptic.impactOccurred()
    }

    @objc private func openDictationApp() {
        guard let url = URL(string: "shinsoku://dictation") else {
            return
        }
        setStatus(.opening)
        // Same path as before the redesign: SwiftUI's openURL first, the extension context as fallback.
        EnvironmentValues().openURL(url) { [weak self] accepted in
            if !accepted {
                self?.openWithExtensionContext(url)
            }
        }
    }

    private func openWithExtensionContext(_ url: URL) {
        extensionContext?.open(url) { [weak self] completed in
            DispatchQueue.main.async {
                if !completed {
                    self?.setStatus(.openFailed)
                }
            }
        }
    }
}

/// Delete repeat: first repeat after 0.4 s, then every 0.08 s; after 1.5 s of holding, deletes whole words.
final class KeyRepeater {
    var onTick: ((_ wordMode: Bool) -> Void)?
    private var timer: Timer?
    private var startedAt: Date?

    func start() {
        stop()
        startedAt = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            self?.beginRepeating()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        startedAt = nil
    }

    private func beginRepeating() {
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard let startedAt else { return }
        onTick?(Date().timeIntervalSince(startedAt) >= 1.5)
    }
}

/// Latest text handed over by the app through the App Group (written by `AppDelegate.publishLatestText`).
/// Readable only with Full Access. The clipboard is never read: iOS paste privacy redacts it in extensions.
enum LatestTextStore {
    enum State {
        case none
        case new
        case inserted
    }

    struct Entry {
        let text: String
        let id: String
    }

    static let appGroup = "group.net.potafree.shinsoku"
    private static let log = Logger(subsystem: "net.potafree.shinsoku.keyboard", category: "latest")

    private static var shared: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    static func latest() -> Entry? {
        guard
            let shared,
            let text = shared.string(forKey: "latestText"),
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let id = shared.string(forKey: "latestId")
        else {
            return nil
        }
        return Entry(text: text, id: id)
    }

    static func lastInsertedId() -> String? {
        shared?.string(forKey: "lastInsertedId")
    }

    static func markInserted(_ id: String) {
        shared?.set(id, forKey: "lastInsertedId")
    }

    static func state(reason: String) -> State {
        let entry = latest()
        let state: State = entry == nil ? .none : (entry?.id == lastInsertedId() ? .inserted : .new)
        // Booleans only; never the text.
        log.notice("""
            state (\(reason, privacy: .public)): groupAvailable=\(shared != nil) hasLatest=\(entry != nil) \
            isNew=\(state == .new)
            """)
        return state
    }
}
