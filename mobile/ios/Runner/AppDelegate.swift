import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let keyboardBridgeChannel = "net.potafree.shinsoku/keyboard_bridge"
  private let deepLinkChannel = "net.potafree.shinsoku/deep_link"
  private var pendingDeepLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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

          UIPasteboard.general.string = text
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
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
    }
    return true
  }
}
