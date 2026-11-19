import Foundation

/// profile-01: the App Group profile store shared by the Flutter channel (`ProfileGroupChannel`) and the App
/// Intents (`ProfileIntents.swift`). One place owns the keys and the JSON shape:
/// - `profiles.v1`: JSON array of `{id, name}` (no prompt text, no keys).
/// - `activeProfile.v1`: JSON object `{profileId, source, at}`; `at` is ISO 8601 UTC.
/// Mirrors `ProfileSelection` in `mobile/lib/services/active_profile.dart`.
enum ProfileGroup {
  static let appGroup = "group.net.potafree.shinsoku"
  static let profilesKey = "profiles.v1"
  static let activeKey = "activeProfile.v1"
  static let fieldRulesKey = "fieldRules.v1"
  static let fieldKinds: [String] = ["search", "url", "email", "message"]
  static let sources: Set<String> = ["manual", "automation", "fieldRule", "default"]

  struct Profile: Equatable {
    let id: String
    let name: String
  }

  struct Selection: Equatable {
    let profileId: String
    let source: String
    let at: String
  }

  static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

  // MARK: JSON shape

  private static func jsonString(_ object: Any) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  private static func decode(_ raw: String?) -> Any? {
    guard let data = raw?.data(using: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: data)
  }

  /// Nil when any entry is malformed (the whole list is rejected).
  static func parseProfiles(_ raw: String?) -> [Profile]? {
    guard let items = decode(raw) as? [[String: Any]] else { return nil }
    var list: [Profile] = []
    for item in items {
      guard let id = item["id"] as? String, !id.isEmpty, let name = item["name"] as? String else { return nil }
      list.append(Profile(id: id, name: name))
    }
    return list
  }

  static func encodeProfiles(_ profiles: [Profile]) -> String? {
    jsonString(profiles.map { ["id": $0.id, "name": $0.name] })
  }

  static func parseSelection(_ raw: String?) -> Selection? {
    guard
      let object = decode(raw) as? [String: Any],
      let id = object["profileId"] as? String, !id.isEmpty,
      let source = object["source"] as? String, sources.contains(source),
      let at = object["at"] as? String, !at.isEmpty
    else { return nil }
    return Selection(profileId: id, source: source, at: at)
  }

  static func encodeSelection(_ selection: Selection) -> String? {
    jsonString(["profileId": selection.profileId, "source": selection.source, "at": selection.at])
  }

  /// Re-serialized with only `{id, name}`, so nothing else can land in the group.
  static func sanitizedProfiles(_ raw: String?) -> String? {
    parseProfiles(raw).flatMap(encodeProfiles)
  }

  static func sanitizedSelection(_ raw: String?) -> String? {
    parseSelection(raw).flatMap(encodeSelection)
  }

  /// `fieldRules.v1`: `{kind: profileId}`. Only known kinds with non-empty string ids survive; nil when the
  /// value is not a JSON object.
  static func sanitizedFieldRules(_ raw: String?) -> String? {
    guard let object = decode(raw) as? [String: Any] else { return nil }
    var rules: [String: String] = [:]
    for kind in fieldKinds {
      if let id = object[kind] as? String, !id.isEmpty { rules[kind] = id }
    }
    return jsonString(rules)
  }

  /// Same format as Dart's `DateTime.toUtc().toIso8601String()` (millisecond precision, `Z`).
  static func timestamp(_ date: Date = Date()) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: date)
  }

  // MARK: Store

  static func readProfiles(_ shared: UserDefaults? = defaults) -> [Profile] {
    parseProfiles(shared?.string(forKey: profilesKey)) ?? []
  }

  static func readSelection(_ shared: UserDefaults? = defaults) -> Selection? {
    parseSelection(shared?.string(forKey: activeKey))
  }

  /// The active profile as recording would see it without a field rule (PR3): the stored selection if its
  /// profile still exists, otherwise the first profile. Nil only when the app never published a list.
  static func resolveActive(_ shared: UserDefaults? = defaults) -> (profile: Profile, source: String)? {
    let profiles = readProfiles(shared)
    if let selection = readSelection(shared),
      let profile = profiles.first(where: { $0.id == selection.profileId })
    {
      return (profile, selection.source)
    }
    return profiles.first.map { ($0, "default") }
  }

  /// Writes `{profileId, source, at: now}`. Returns false when the group is unavailable or the value is invalid.
  @discardableResult
  static func writeSelection(
    profileId: String, source: String, at date: Date = Date(), to shared: UserDefaults? = defaults
  ) -> Bool {
    guard
      let shared,
      let encoded = sanitizedSelection(
        encodeSelection(Selection(profileId: profileId, source: source, at: timestamp(date))))
    else { return false }
    shared.set(encoded, forKey: activeKey)
    return true
  }
}
