import Flutter
import OSLog
import StoreKit
import UIKit

/// pricing-01 S2: Shinsoku Pro (`net.potafree.shinsoku.pro`, non-consumable, Family Sharing) over StoreKit 2.
///
/// Channel contract: docs/iterations/pricing-01/round-01/S1-implementation.md.
/// - MethodChannel `net.potafree.shinsoku/store`: `state` → `{owned, price?}`, `purchase` / `restore` →
///   `{result, owned}`.
/// - EventChannel `net.potafree.shinsoku/store/updates`: the `state` map after a transaction update rewrote the
///   mirror.
///
/// The App Group mirror `pro.v1` (`ProfileGroup.writePro`) is written only here (E4):
/// - a verified, unrevoked entitlement for the product → `owned = true`;
/// - a verified transaction for the product that carries a `revocationDate` (refund, Family Sharing removed),
///   with no other live entitlement → `owned = false` (E2);
/// - anything else (offline, StoreKit error, no transaction known) keeps the last known value (E1). A missing
///   mirror reads as not Pro everywhere.
/// Unverified transactions never count and are not finished.
@MainActor
final class ProStore: NSObject, FlutterStreamHandler {
  static let shared = ProStore()
  static let productId = "net.potafree.shinsoku.pro"
  static let channelName = "net.potafree.shinsoku/store"
  static let updatesChannelName = "net.potafree.shinsoku/store/updates"
  private static let log = Logger(subsystem: "net.potafree.shinsoku.app", category: "store")

  private var product: Product?
  private var updatesTask: Task<Void, Never>?
  private var sink: FlutterEventSink?
  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?

#if DEBUG
  /// `-ShinsokuSceneProFixture owned|locked` (Debug builds only): StoreKit is never touched; the mirror is
  /// written from the fixture so the keyboard and the intents follow it.
  let fixture: String? = {
    let arguments = ProcessInfo.processInfo.arguments
    guard let index = arguments.firstIndex(of: "-ShinsokuSceneProFixture"), arguments.indices.contains(index + 1)
    else { return nil }
    let value = arguments[index + 1]
    return ["owned", "locked"].contains(value) ? value : nil
  }()
#endif

  // MARK: Launch

  /// Called once from `didFinishLaunching`: listens for transaction updates for the whole app lifetime (Apple:
  /// start the listener at launch so no update is missed) and reconciles the mirror with the entitlements.
  func start() {
#if DEBUG
    if let fixture {
      ProfileGroup.writePro(owned: fixture == "owned")
      Self.log.notice("start: scene fixture \(fixture, privacy: .public), StoreKit not used")
      return
    }
#endif
    guard updatesTask == nil else { return }
    updatesTask = Task { [weak self] in
      for await update in Transaction.updates {
        await self?.handle(update: update)
      }
    }
    Task { [weak self] in
      _ = await self?.reconcile()
    }
  }

  // MARK: Channels

  func register(messenger: FlutterBinaryMessenger) {
    let methods = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    methods.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "Store unavailable.", details: nil))
        return
      }
      switch call.method {
      case "state":
        Task { @MainActor in result(await self.stateMap()) }
      case "purchase":
        Task { @MainActor in result(await self.purchase()) }
      case "restore":
        Task { @MainActor in result(await self.restore()) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    methodChannel = methods

    eventChannel?.setStreamHandler(nil)
    let events = FlutterEventChannel(name: Self.updatesChannelName, binaryMessenger: messenger)
    events.setStreamHandler(self)
    eventChannel = events
  }

  nonisolated func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    MainActor.assumeIsolated { sink = events }
    return nil
  }

  nonisolated func onCancel(withArguments arguments: Any?) -> FlutterError? {
    MainActor.assumeIsolated { sink = nil }
    return nil
  }

  private func emit() {
    guard let sink else { return }
    Task { @MainActor in sink(await self.stateMap(loadPrice: false)) }
  }

  // MARK: State

  private var mirrorOwned: Bool { ProfileGroup.proOwned() }

  /// `{owned, price}`; owned from StoreKit when it answers, else the mirror (E1).
  private func stateMap(loadPrice: Bool = true) async -> [String: Any] {
#if DEBUG
    if let fixture {
      return ["owned": fixture == "owned", "price": "$4.99"]
    }
#endif
    let owned = await reconcile()
    var map: [String: Any] = ["owned": owned]
    if loadPrice, let product = await loadProduct() {
      map["price"] = product.displayPrice
    } else if let product {
      map["price"] = product.displayPrice
    }
    return map
  }

  private func loadProduct() async -> Product? {
    if let product { return product }
    do {
      product = try await Product.products(for: [Self.productId]).first
      if product == nil { Self.log.error("product: not found") }
    } catch {
      Self.log.error("product: \(String(describing: error), privacy: .public)")
    }
    return product
  }

  /// What StoreKit says about the product right now.
  enum Evidence: Equatable {
    /// A verified, unrevoked entitlement.
    case owned
    /// A verified transaction for the product, revoked, and no live entitlement (E2).
    case revoked
    /// Nothing known (never bought here, offline, error): keep the mirror (E1).
    case unknown
  }

  private func evidence() async -> Evidence {
    for await result in Transaction.currentEntitlements {
      if case .verified(let transaction) = result, transaction.productID == Self.productId,
        transaction.revocationDate == nil
      {
        return .owned
      }
    }
    if let latest = await Transaction.latest(for: Self.productId),
      case .verified(let transaction) = latest, transaction.revocationDate != nil
    {
      return .revoked
    }
    return .unknown
  }

  /// Applies the evidence to the mirror (only writer, E4) and returns the owned state.
  @discardableResult
  private func reconcile() async -> Bool {
    let found = await evidence()
    let before = ProfileGroup.readPro()
    let owned = Self.ownedAfter(found, mirror: before?.owned)
    if before?.owned != owned || before == nil {
      if !ProfileGroup.writePro(owned: owned) {
        Self.log.error("mirror: App Group unavailable")
      }
    }
    Self.log.notice(
      "reconcile: evidence=\(String(describing: found), privacy: .public) before=\(before.map { "\($0.owned)" } ?? "none", privacy: .public) owned=\(owned)"
    )
    return owned
  }

  /// E1/E2 as a pure rule: only evidence changes the mirror; no evidence keeps it (missing → not Pro).
  nonisolated static func ownedAfter(_ evidence: Evidence, mirror: Bool?) -> Bool {
    switch evidence {
    case .owned: return true
    case .revoked: return false
    case .unknown: return mirror ?? false
    }
  }

  // MARK: Transactions

  private func handle(update: VerificationResult<Transaction>) async {
    guard case .verified(let transaction) = update else {
      Self.log.error("update: unverified transaction ignored")
      return
    }
    await transaction.finish()
    guard transaction.productID == Self.productId else { return }
    Self.log.notice("update: revoked=\(transaction.revocationDate != nil)")
    await reconcile()
    emit()
  }

  private func purchase() async -> [String: Any] {
#if DEBUG
    if let fixture {
      return ["result": fixture == "owned" ? "purchased" : "failed", "owned": fixture == "owned"]
    }
#endif
    guard let product = await loadProduct() else {
      return ["result": "failed", "owned": mirrorOwned]
    }
    do {
      let outcome: Product.PurchaseResult
      if #available(iOS 17.0, *), let scene = Self.activeScene() {
        outcome = try await product.purchase(confirmIn: scene)
      } else {
        outcome = try await product.purchase()
      }
      switch outcome {
      case .success(.verified(let transaction)):
        await transaction.finish()
        ProfileGroup.writePro(owned: true)
        Self.log.notice("purchase: purchased")
        emit()
        return ["result": "purchased", "owned": true]
      case .success(.unverified):
        Self.log.error("purchase: unverified transaction")
        return ["result": "failed", "owned": mirrorOwned]
      case .pending:
        Self.log.notice("purchase: pending")
        return ["result": "pending", "owned": mirrorOwned]
      case .userCancelled:
        return ["result": "cancelled", "owned": mirrorOwned]
      @unknown default:
        return ["result": "failed", "owned": mirrorOwned]
      }
    } catch {
      Self.log.error("purchase: \(String(describing: error), privacy: .public)")
      return ["result": "failed", "owned": mirrorOwned]
    }
  }

  private func restore() async -> [String: Any] {
#if DEBUG
    if let fixture {
      return ["result": "purchased", "owned": fixture == "owned"]
    }
#endif
    do {
      try await AppStore.sync()
    } catch StoreKitError.userCancelled {
      return ["result": "cancelled", "owned": mirrorOwned]
    } catch {
      Self.log.error("restore: \(String(describing: error), privacy: .public)")
      return ["result": "failed", "owned": mirrorOwned]
    }
    let owned = await reconcile()
    emit()
    return ["result": "purchased", "owned": owned]
  }

  private static func activeScene() -> UIWindowScene? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
  }
}
