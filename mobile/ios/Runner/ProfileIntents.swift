import AppIntents
import Foundation
import OSLog

// profile-01 P2: Shortcuts actions "Set Shinsoku Profile" / "Get Shinsoku Profile". They read and write the
// App Group store (`ProfileGroup`), so they run without opening the app: a personal automation
// ("When Slack is opened → Set Shinsoku Profile: Chat", Run Immediately) is the per-app mechanism.
// iOS 16+; the app's minimum stays iOS 15.

@available(iOS 16.0, *)
struct ProfileEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Shinsoku Profile"
  static var defaultQuery = ProfileEntityQuery()

  let id: String
  let name: String

  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

  init(id: String, name: String) {
    self.id = id
    self.name = name
  }

  init(_ profile: ProfileGroup.Profile) {
    self.init(id: profile.id, name: profile.name)
  }
}

@available(iOS 16.0, *)
struct ProfileEntityQuery: EntityQuery {
  func entities(for identifiers: [ProfileEntity.ID]) async throws -> [ProfileEntity] {
    let profiles = ProfileGroup.readProfiles()
    return identifiers.compactMap { id in profiles.first { $0.id == id }.map(ProfileEntity.init) }
  }

  func suggestedEntities() async throws -> [ProfileEntity] {
    ProfileGroup.readProfiles().map(ProfileEntity.init)
  }
}

@available(iOS 16.0, *)
enum ProfileIntentError: Error, CustomLocalizedStringResourceConvertible {
  case noProfiles
  case profileMissing(String)
  case storeUnavailable

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .noProfiles: return "Open Shinsoku once so your profiles are available."
    case .profileMissing(let name): return "The Shinsoku profile \"\(name)\" no longer exists."
    case .storeUnavailable: return "Shinsoku could not save the profile."
    }
  }
}

@available(iOS 16.0, *)
struct SetShinsokuProfileIntent: AppIntent {
  static var title: LocalizedStringResource = "Set Shinsoku Profile"
  static var description = IntentDescription(
    "Sets the profile Shinsoku uses for the next dictation, for example from an automation when an app opens.")
  static var openAppWhenRun = false
  private static let log = Logger(subsystem: "net.potafree.shinsoku.app", category: "profiles")

  @Parameter(title: "Profile")
  var profile: ProfileEntity

  static var parameterSummary: some ParameterSummary {
    Summary("Set Shinsoku profile to \(\.$profile)")
  }

  init() {}

  init(profile: ProfileEntity) {
    self.profile = profile
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    // pricing-01: switching profiles from Shortcuts is Shinsoku Pro. Without it nothing is written and the
    // action answers with a dialog (never a raw error); Get Shinsoku Profile stays free. Reads the App Group
    // mirror `pro.v1` (E4); a missing mirror is not Pro.
    guard ProfileGroup.proOwned() else {
      Self.log.notice("intent setActive: skipped, no Pro")
      return .result(dialog: "Switching profiles from Shortcuts needs Shinsoku Pro.")
    }
    // A renamed profile keeps its id; a deleted one must not become the selection (PR3).
    guard let current = ProfileGroup.readProfiles().first(where: { $0.id == profile.id }) else {
      throw ProfileIntentError.profileMissing(profile.name)
    }
    guard ProfileGroup.writeSelection(profileId: current.id, source: "automation") else {
      Self.log.error("intent setActive: App Group unavailable")
      throw ProfileIntentError.storeUnavailable
    }
    Self.log.notice("intent setActive: source=automation")
    return .result(dialog: "Shinsoku profile: \(current.name)")
  }
}

@available(iOS 16.0, *)
struct GetShinsokuProfileIntent: AppIntent {
  static var title: LocalizedStringResource = "Get Shinsoku Profile"
  static var description = IntentDescription("Returns the profile Shinsoku uses for the next dictation.")
  static var openAppWhenRun = false

  init() {}

  func perform() async throws -> some IntentResult & ReturnsValue<ProfileEntity> & ProvidesDialog {
    guard let active = ProfileGroup.resolveActive() else { throw ProfileIntentError.noProfiles }
    return .result(value: ProfileEntity(active.profile), dialog: "Shinsoku profile: \(active.profile.name)")
  }
}

// i18n-01 I4: the parameterized phrases come first, so the Shortcuts app and Spotlight show one ready-made
// action per saved profile ("Switch Shinsoku to Chat", from `suggestedEntities()`) with no setup. The plain
// phrases stay for Siri, which then asks for the profile. iOS re-reads the profiles only when
// `updateAppShortcutParameters()` is called: on launch and whenever the app publishes a changed list
// (`ShinsokuShortcuts.refreshParameters()`).
@available(iOS 16.0, *)
struct ShinsokuShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: SetShinsokuProfileIntent(),
      phrases: [
        "Switch \(.applicationName) to \(\.$profile)",
        "Use \(\.$profile) in \(.applicationName)",
        "Set \(.applicationName) profile",
        "Switch \(.applicationName) profile",
      ],
      shortTitle: "Set Profile",
      systemImageName: "person.crop.circle"
    )
    AppShortcut(
      intent: GetShinsokuProfileIntent(),
      phrases: ["Get \(.applicationName) profile"],
      shortTitle: "Get Profile",
      systemImageName: "person.crop.circle.badge.questionmark"
    )
  }
}

/// Called from code that is not itself gated on iOS 16 (AppDelegate, the profile channel).
enum ShinsokuShortcutParameters {
  static func refresh() {
    if #available(iOS 16.0, *) {
      ShinsokuShortcuts.updateAppShortcutParameters()
    }
  }
}
