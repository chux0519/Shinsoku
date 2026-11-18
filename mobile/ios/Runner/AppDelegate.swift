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

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let keyboardBridgeChannel = "net.potafree.shinsoku/keyboard_bridge"
  private let deepLinkChannel = "net.potafree.shinsoku/deep_link"
  private let divisionRegionStream = DivisionRegionStream()
  private var pendingDeepLink: String?

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
    if let launchURL = launchOptions?[.url] as? URL, launchURL.scheme == "shinsoku" {
      pendingDeepLink = launchURL.absoluteString
    }

#if DEBUG
    Self.applySceneLaunchArguments()
#endif

    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: keyboardBridgeChannel,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
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

      let deepLink = FlutterMethodChannel(
        name: deepLinkChannel,
        binaryMessenger: controller.binaryMessenger
      )
      deepLink.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "consumeInitialURL":
          result(self?.pendingDeepLink)
          self?.pendingDeepLink = nil
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      divisionRegionStream.register(with: controller)

      if let pendingDeepLink {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
          deepLink.invokeMethod("openURL", arguments: pendingDeepLink)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    divisionRegionStream.attach()
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard url.scheme == "shinsoku" else {
      return super.application(app, open: url, options: options)
    }

    pendingDeepLink = url.absoluteString
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: deepLinkChannel,
        binaryMessenger: controller.binaryMessenger
      )
      channel.invokeMethod("openURL", arguments: url.absoluteString)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self, weak controller] in
        guard let self, self.pendingDeepLink == url.absoluteString, let controller else {
          return
        }
        let channel = FlutterMethodChannel(
          name: self.deepLinkChannel,
          binaryMessenger: controller.binaryMessenger
        )
        channel.invokeMethod("openURL", arguments: url.absoluteString)
      }
    }
    return true
  }
}
