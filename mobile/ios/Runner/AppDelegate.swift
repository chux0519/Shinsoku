import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let keyboardBridgeChannel = "net.potafree.shinsoku/keyboard_bridge"

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
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
