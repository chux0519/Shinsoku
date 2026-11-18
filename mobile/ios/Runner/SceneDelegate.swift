import Flutter
import UIKit

/// Flutter's scene delegate owns the window and the storyboard's FlutterViewController (iOS 27 requires
/// UIScene adoption). App-specific scene handling (deep links) lives in `DeepLinkRouter`, registered as a
/// Flutter scene delegate in `AppDelegate.registerChannels(_:)`.
class SceneDelegate: FlutterSceneDelegate {
}
