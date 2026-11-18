import Flutter
import OSLog
import UIKit

// iPhone Duo division regions (the fold), bridged to Dart as
// `net.potafree.shinsoku/division_regions` (mobile/lib/platform/division_regions.dart).
// Ported from Shinphony. The API exists from iOS 27.1 and the iOS 27 SDK
// (Swift 6.4); older SDKs and OS versions report no regions.
#if compiler(>=6.4)
@available(iOS 27.1, *)
private final class DivisionRegionObserver: UIView {
  var onChange: (([CGRect]) -> Void)?
  private var previous: [CGRect] = []
  override class var requiresConstraintBasedLayout: Bool { true }

  override func updateConstraints() {
    let frames = reservedRegions(kind: .division)
      .filter { $0.isActive && !$0.frame.isNull && !$0.frame.isEmpty }
      .map(\.frame)
      .filter { [$0.minX, $0.minY, $0.width, $0.height].allSatisfy(\.isFinite) }
    if frames != previous {
      previous = frames
      onChange?(frames)
    }
    super.updateConstraints()
  }
}
#endif

/// Self-contained: call `register(with:)` once with the FlutterViewController
/// (from the app or the scene delegate, wherever channels are registered) and
/// `attach()` when the scene becomes active.
final class DivisionRegionStream: NSObject, FlutterStreamHandler {
  static let channelName = "net.potafree.shinsoku/division_regions"
  private weak var controller: FlutterViewController?
  private var channel: FlutterEventChannel?
  private var sink: FlutterEventSink?
  private weak var observer: UIView?
  private var frames: [CGRect] = []

  func register(with controller: FlutterViewController) {
    self.controller = controller
    channel?.setStreamHandler(nil)
    let channel = FlutterEventChannel(name: Self.channelName, binaryMessenger: controller.binaryMessenger)
    channel.setStreamHandler(self)
    self.channel = channel
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    emit()
    attach()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    observer?.removeFromSuperview()
    observer = nil
    frames = []
    return nil
  }

  func attach() {
    #if compiler(>=6.4)
    guard sink != nil, #available(iOS 27.1, *), let host = controller?.view else { return }
    if observer?.superview === host { return }
    observer?.removeFromSuperview()
    if !frames.isEmpty {
      frames = []
      emit()
    }
    let view = DivisionRegionObserver(frame: .zero)
    view.backgroundColor = .clear
    view.isUserInteractionEnabled = false
    view.isAccessibilityElement = false
    view.accessibilityElementsHidden = true
    view.translatesAutoresizingMaskIntoConstraints = false
    view.onChange = { [weak self] frames in
      guard let self else { return }
      self.frames = Array(frames.prefix(8))
      self.emit()
    }
    host.addSubview(view)
    NSLayoutConstraint.activate([
      view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: host.trailingAnchor),
      view.topAnchor.constraint(equalTo: host.topAnchor),
      view.bottomAnchor.constraint(equalTo: host.bottomAnchor),
    ])
    observer = view
    view.setNeedsUpdateConstraints()
    #endif
  }

  private func emit() {
    sink?(frames.map { ["left": $0.minX, "top": $0.minY, "width": $0.width, "height": $0.height] })
  }
}

/// App lifecycle with UIScene adoption (required by the iOS 27 SDK; Flutter's `FlutterSceneDelegate` owns the
/// window, see `SceneDelegate.swift`). There is no root view controller at launch any more: everything that
/// needs the Flutter engine is set up in `didInitializeImplicitFlutterEngine` → `registerChannels(_:)`.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Retained here: Flutter keeps scene delegates weakly.
  private var deepLinks: DeepLinkRouter?
  private var divisionRegions: DivisionRegionHook?

  /// Shared with the keyboard extension (both targets carry this App Group).
  static let appGroup = "group.net.potafree.shinsoku"
  private static let log = Logger(subsystem: "net.potafree.shinsoku.app", category: "latest")

  /// Hands the latest text to the keyboard through the App Group and puts it on the clipboard for the
  /// user's own pasting. The keyboard never reads the clipboard (iOS paste privacy redacts it there).
  /// Logs never contain the text, only its length.
  static func publishLatestText(_ text: String) {
    guard let shared = UserDefaults(suiteName: appGroup) else {
      log.error("publish: UserDefaults(suiteName: \(appGroup, privacy: .public)) is nil")
      return
    }
    let id = UUID().uuidString
    shared.set(text, forKey: "latestText")
    shared.set(id, forKey: "latestId")
    shared.set(Date(), forKey: "latestAt")
    let synced = shared.synchronize()
    let readBack = shared.string(forKey: "latestId") == id
    log.notice("""
      publish: suite=\(appGroup, privacy: .public) keys=latestText,latestId,latestAt \
      length=\(text.count) synchronize=\(synced) readBack=\(readBack)
      """)
    UIPasteboard.general.setItems([["public.utf8-plain-text": text]], options: [.localOnly: true])
  }

#if DEBUG
  /// Scene-test hooks (Debug builds only): `-ShinsokuSceneResetLatest YES` clears the shared latest text,
  /// `-ShinsokuSceneSeedLatest <text>` publishes <text> through the same path as the method channel.
  /// Read straight from the process arguments, before the Flutter engine starts.
  private static func applySceneLaunchArguments() {
    let arguments = ProcessInfo.processInfo.arguments
    func value(after flag: String) -> String? {
      guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
        return nil
      }
      return arguments[index + 1]
    }
    let reset = value(after: "-ShinsokuSceneResetLatest")
    let seed = value(after: "-ShinsokuSceneSeedLatest")
    log.notice("""
      scene args: count=\(arguments.count) reset=\(reset ?? "nil", privacy: .public) \
      seedLength=\(seed?.count ?? -1)
      """)
    if reset == "YES", let shared = UserDefaults(suiteName: appGroup) {
      for key in ["latestText", "latestId", "latestAt", "lastInsertedId"] {
        shared.removeObject(forKey: key)
      }
      log.notice("scene reset: synchronize=\(shared.synchronize())")
    }
    if let seed, !seed.isEmpty {
      publishLatestText(seed)
    }
  }
#endif

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
#if DEBUG
    Self.applySceneLaunchArguments()
#endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerChannels(engineBridge.pluginRegistry)
  }

  /// The one place where Shinsoku's own platform channels are registered: keyboard bridge, deep links,
  /// division regions (U4). Add new channels here.
  private func registerChannels(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "ShinsokuHost") else {
      Self.log.error("registerChannels: no registrar")
      return
    }
    let messenger = registrar.messenger()

    let keyboardBridge = FlutterMethodChannel(
      name: "net.potafree.shinsoku/keyboard_bridge",
      binaryMessenger: messenger
    )
    keyboardBridge.setMethodCallHandler { call, result in
      switch call.method {
      case "publishLatestText":
        guard
          let arguments = call.arguments as? [String: Any],
          let text = arguments["text"] as? String,
          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
          result(FlutterError(
            code: "invalid-arguments",
            message: "Missing latest text.",
            details: nil
          ))
          return
        }
        AppDelegate.publishLatestText(text)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let router = DeepLinkRouter(messenger: messenger)
    registrar.addSceneDelegate(router)
    deepLinks = router

    let regions = DivisionRegionHook(registrar: registrar)
    registrar.addSceneDelegate(regions)
    divisionRegions = regions
  }
}

/// Connects U4's `DivisionRegionStream` under scenes. `register(with:)` needs the FlutterViewController, which
/// may not be attached yet when the implicit engine initializes: register as soon as it is (now, or when
/// Flutter replays the scene connection, at the latest when the scene becomes active), and `attach()` on
/// every `sceneDidBecomeActive` (was `applicationDidBecomeActive` before the scene migration).
final class DivisionRegionHook: NSObject, FlutterSceneLifeCycleDelegate {
  private let stream = DivisionRegionStream()
  private weak var registrar: FlutterPluginRegistrar?
  private var registered = false

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
    registerIfPossible(nil)
  }

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    registerIfPossible(scene)
    return false
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    registerIfPossible(scene)
    stream.attach()
  }

  private func registerIfPossible(_ scene: UIScene?) {
    guard !registered else { return }
    let fromRegistrar = registrar?.viewController as? FlutterViewController
    let fromScene = (scene as? UIWindowScene)?.windows.first?.rootViewController as? FlutterViewController
    guard let controller = fromRegistrar ?? fromScene else { return }
    stream.register(with: controller)
    registered = true
  }
}

/// `shinsoku://` links → Dart over `net.potafree.shinsoku/deep_link`, same protocol as before the scene
/// migration: Dart calls `consumeInitialURL` for the launch link; the host also invokes `openURL` (after
/// 0.4 s on a cold launch; immediately plus one retry after 0.4 s while running, until Dart consumed it).
/// Returning true keeps Flutter's own deep-link routing out of these links, as before.
final class DeepLinkRouter: NSObject, FlutterSceneLifeCycleDelegate {
  private static let scheme = "shinsoku"
  private let channel: FlutterMethodChannel
  private var pendingDeepLink: String?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "net.potafree.shinsoku/deep_link", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "consumeInitialURL":
        result(self?.pendingDeepLink)
        self?.pendingDeepLink = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Cold launch: Flutter replays the connection options to scene delegates added during engine setup.
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let url = Self.shinsokuURL(in: connectionOptions?.urlContexts ?? []) else {
      return false
    }
    let link = url.absoluteString
    pendingDeepLink = link
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
      self?.channel.invokeMethod("openURL", arguments: link)
    }
    return true
  }

  /// Link opened while the app runs or is suspended.
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    guard let url = Self.shinsokuURL(in: URLContexts) else {
      return false
    }
    let link = url.absoluteString
    pendingDeepLink = link
    channel.invokeMethod("openURL", arguments: link)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
      guard let self, self.pendingDeepLink == link else {
        return
      }
      self.channel.invokeMethod("openURL", arguments: link)
    }
    return true
  }

  private static func shinsokuURL(in contexts: Set<UIOpenURLContext>) -> URL? {
    contexts.first { $0.url.scheme == scheme }?.url
  }
}
