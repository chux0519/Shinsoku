import Foundation

/// profile-01 P3: what the keyboard shows as the active profile, and why. Foundation only (no UIKit), so
/// `ResolverChecks/main.swift` can compile it with `ProfileGroup.swift` on the Mac.
///
/// Port of `resolveActive` in `mobile/lib/services/active_profile.dart` (invariants PR2, PR3 in
/// docs/design/state_invariants.md). Keep the two in step.

/// The kind of the focused text field, from `textDocumentProxy` (see `FieldKind.detect` in
/// `KeyboardViewController.swift`). Raw values are the keys of `fieldRules.v1`.
enum FieldKind: String, CaseIterable {
    case search
    case url
    case email
    case message
    case other
}

enum KeyboardProfileResolver {
    /// App Group key written by Settings (P4): JSON object `{kind: profileId}`, e.g. `{"search":"p-2"}`.
    static let fieldRulesKey = "fieldRules.v1"

    static let explicitSources: Set<String> = ["manual", "automation"]

    struct Resolved: Equatable {
        let profile: ProfileGroup.Profile
        /// Wire name: `manual`, `automation`, `fieldRule` or `default`.
        let source: String
    }

    /// `{kind: profileId}`; unknown kinds and empty ids are dropped. No rules → empty.
    static func parseFieldRules(_ raw: String?) -> [FieldKind: String] {
        guard
            let data = raw?.data(using: .utf8),
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return [:] }
        var rules: [FieldKind: String] = [:]
        for (key, value) in object {
            guard let kind = FieldKind(rawValue: key), let id = value as? String, !id.isEmpty else { continue }
            rules[kind] = id
        }
        return rules
    }

    static func readFieldRules(_ shared: UserDefaults? = ProfileGroup.defaults) -> [FieldKind: String] {
        parseFieldRules(shared?.string(forKey: fieldRulesKey))
    }

    /// Parses `at` as written by Dart (`toIso8601String`, micro- or milliseconds) or Swift (`timestamp`).
    static func instant(_ at: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: at) { return date }
        return ISO8601DateFormatter().date(from: at)
    }

    /// Strict precedence (user decision 2026-11-19): manual > automation > field rule > default.
    /// 1. A field rule applies only when no explicit selection (manual pick or automation set) is in effect:
    ///    the stored selection is missing, has source `default`, or points at a deleted profile. It never
    ///    overrides a manual or automation selection, whatever the timestamps or when the keyboard appeared.
    /// 2. Otherwise the stored selection, if its profile still exists.
    /// 3. Otherwise the default (first) profile (missing id → default, PR3).
    /// Nil only when there are no profiles (the app never published a list).
    static func resolve(
        selection: ProfileGroup.Selection?,
        profiles: [ProfileGroup.Profile],
        fieldRuleProfileId: String? = nil
    ) -> Resolved? {
        func find(_ id: String) -> ProfileGroup.Profile? {
            profiles.first { $0.id == id }
        }
        // Dart's `ProfileSelection.fromJson` rejects an unparseable `at`: treat it as no selection.
        let selection = selection.flatMap { instant($0.at) == nil ? nil : $0 }
        let selected = selection.flatMap { find($0.profileId) }
        let explicitInEffect = selected != nil && explicitSources.contains(selection?.source ?? "")

        if let fieldRuleProfileId, let fieldProfile = find(fieldRuleProfileId), !explicitInEffect {
            return Resolved(profile: fieldProfile, source: "fieldRule")
        }
        if let selection, let selected {
            return Resolved(profile: selected, source: selection.source)
        }
        return profiles.first.map { Resolved(profile: $0, source: "default") }
    }

    /// The profile after `currentId` in list order (wraps); the first one when `currentId` is unknown.
    static func next(after currentId: String?, in profiles: [ProfileGroup.Profile]) -> ProfileGroup.Profile? {
        guard !profiles.isEmpty else { return nil }
        guard let currentId, let index = profiles.firstIndex(where: { $0.id == currentId }) else {
            return profiles.first
        }
        return profiles[(index + 1) % profiles.count]
    }

    /// `shinsoku://dictation?profile=<id>` (PR1: the app records with the profile the keyboard shows).
    static func dictationURL(profileId: String?) -> URL? {
        var components = URLComponents()
        components.scheme = "shinsoku"
        components.host = "dictation"
        if let profileId, !profileId.isEmpty {
            components.queryItems = [URLQueryItem(name: "profile", value: profileId)]
        }
        return components.url
    }
}

/// PR4: the last profile the keyboard showed, kept in the extension's own defaults (readable without Full
/// Access, unlike the App Group) so a read-only keyboard can still show it.
enum LastShownProfile {
    static let key = "keyboard.lastShownProfile.v1"

    static func read(_ defaults: UserDefaults = .standard) -> ProfileGroup.Profile? {
        guard
            let object = defaults.dictionary(forKey: key),
            let id = object["id"] as? String, !id.isEmpty,
            let name = object["name"] as? String
        else { return nil }
        return ProfileGroup.Profile(id: id, name: name)
    }

    static func write(_ profile: ProfileGroup.Profile, _ defaults: UserDefaults = .standard) {
        defaults.set(["id": profile.id, "name": profile.name], forKey: key)
    }
}
