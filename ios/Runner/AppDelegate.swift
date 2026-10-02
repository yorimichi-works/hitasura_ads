import Flutter
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "HitasuraPurchaseVerification"
    ) else { return }
    let channel = FlutterMethodChannel(
      name: "hitasura_ads/purchases", binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "verifyCurrentEntitlement" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: String],
        arguments["productId"] == "ad_free_unlimited",
        let id = arguments["transactionId"], let transactionID = UInt64(id)
      else {
        result(false)
        return
      }
      Task { @MainActor in
        // This sequence includes StoreKit's cryptographic verification result.
        // Do not use unsafePayloadValue or parse an unverified JWS locally.
        for await entitlement in Transaction.currentEntitlements {
          guard case .verified(let transaction) = entitlement else { continue }
          if transaction.id == transactionID,
            transaction.productID == "ad_free_unlimited",
            transaction.revocationDate == nil,
            !transaction.isUpgraded,
            transaction.expirationDate.map({ $0 > Date() }) ?? true
          {
            result(true)
            return
          }
        }
        result(false)
      }
    }
  }
}
