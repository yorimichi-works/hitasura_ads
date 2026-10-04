import Flutter
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var priceDiagnosticID: UUID?
  private var priceDiagnosticTask: Task<Void, Never>?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    #if DEBUG && targetEnvironment(simulator)
      // Only the separate debug capture entrypoint uses this channel. It is
      // absent from device/release builds and never exposes process environment.
      if let captureRegistrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "HitasuraSimulatorCapture"
      ) {
        let captureChannel = FlutterMethodChannel(
          name: "hitasura_ads/simulator_capture",
          binaryMessenger: captureRegistrar.messenger()
        )
        captureChannel.setMethodCallHandler { call, result in
          guard call.method == "documentsDirectory" else {
            result(FlutterMethodNotImplemented)
            return
          }
          guard let documents = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
          ).first else {
            result(FlutterError(code: "no_documents", message: "Documents directory unavailable", details: nil))
            return
          }
          result(["isSimulator": true, "documentsPath": documents.path])
        }
      }
    #endif
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "HitasuraPurchaseVerification"
    ) else { return }
    let channel = FlutterMethodChannel(
      name: "hitasura_ads/purchases", binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "readStorePriceDiagnostic" {
        self.readStorePriceDiagnostic(result: result)
        return
      }
      if call.method == "readPremiumEntitlement" {
        guard let arguments = call.arguments as? [String: Any],
          arguments["productId"] as? String == "ad_free_unlimited"
        else {
          result(["status": "unknown"])
          return
        }
        let userInitiatedSync = arguments["userInitiatedSync"] as? Bool ?? false
        let cachedID = arguments["cachedTransactionId"] as? String
        let cachedOriginalID = arguments["cachedOriginalTransactionId"] as? String
        Task { @MainActor in
          do {
            if userInitiatedSync {
              // May show Apple sign-in UI. Never call this on startup/resume.
              try await AppStore.sync()
            }
            result(await Self.readPremiumEntitlement(
              cachedID: cachedID, cachedOriginalID: cachedOriginalID,
              synchronized: userInitiatedSync
            ))
          } catch {
            // Cancellation, offline and store errors are not negative evidence.
            result(FlutterError(
              code: "store_sync_failed", message: "Purchases could not be synchronized. Please try again.",
              details: nil
            ))
          }
        }
        return
      }
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

  // Owner-only, read-only diagnostic. It never changes the purchase catalogue,
  // account, receipt, transactions or entitlements used by the app.
  private func readStorePriceDiagnostic(result: @escaping FlutterResult) {
    guard Bundle.main.object(forInfoDictionaryKey: "HitasuraPriceDiagnostics") as? Bool == true else {
      result(["status": "disabled"])
      return
    }
    guard priceDiagnosticID == nil else {
      result(["status": "busy"])
      return
    }
    let identifier = UUID()
    priceDiagnosticID = identifier
    let startedAt = Date()
    priceDiagnosticTask = Task { @MainActor [weak self] in
      guard let self else { return }
      let before = await Storefront.current
      do {
        let products = try await Product.products(for: ["ad_free_unlimited"])
        let after = await Storefront.current
        guard !Task.isCancelled, self.priceDiagnosticID == identifier else { return }
        let prices = products.filter { $0.id == "ad_free_unlimited" }.map { product in
          [
            "id": product.id,
            "rawPrice": NSDecimalNumber(decimal: product.price).stringValue,
            "currencyCode": product.priceFormatStyle.currencyCode,
            "displayPrice": product.displayPrice,
            "priceLocale": product.priceFormatStyle.locale.identifier
          ]
        }
        self.finishPriceDiagnostic(identifier, result: result, payload: [
          "status": prices.isEmpty ? "empty" : "ok",
          "rawProductCount": products.count,
          "products": prices,
          "storefrontBefore": Self.rawStorefront(before),
          "storefrontAfter": Self.rawStorefront(after),
          "startedAt": ISO8601DateFormatter().string(from: startedAt),
          "elapsedMs": Int(Date().timeIntervalSince(startedAt) * 1000),
          "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
          "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
          "os": UIDevice.current.systemVersion,
          "bundleMatches": Bundle.main.bundleIdentifier == "com.syamo.hitasuraads"
        ])
      } catch {
        guard !Task.isCancelled, self.priceDiagnosticID == identifier else { return }
        let failure = error as NSError
        self.finishPriceDiagnostic(identifier, result: result, payload: [
          "status": "error", "errorDomain": failure.domain, "errorCode": failure.code,
          "storefrontBefore": Self.rawStorefront(before)
        ])
      }
    }
    Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 15_000_000_000)
      guard let self, self.priceDiagnosticID == identifier else { return }
      self.priceDiagnosticTask?.cancel()
      self.finishPriceDiagnostic(identifier, result: result, payload: ["status": "timeout"])
    }
  }

  private static func rawStorefront(_ storefront: Storefront?) -> [String: String] {
    guard let storefront else { return [:] }
    // Preserve BOTH raw values; never infer a country from just one of them.
    return ["countryCode": storefront.countryCode, "identifier": storefront.id]
  }

  private func finishPriceDiagnostic(
    _ identifier: UUID, result: FlutterResult, payload: [String: Any]
  ) {
    guard priceDiagnosticID == identifier else { return }
    priceDiagnosticID = nil
    priceDiagnosticTask = nil
    result(payload)
  }

  private static func entitlementResult(
    _ status: String, _ transaction: Transaction
  ) -> [String: Any] {
    return [
      "status": status,
      "transactionId": String(transaction.id),
      "originalTransactionId": String(transaction.originalID),
      "signedDateMs": Int64(transaction.signedDate.timeIntervalSince1970 * 1000)
    ]
  }

  private static func readPremiumEntitlement(
    cachedID: String?, cachedOriginalID: String?, synchronized: Bool
  ) async -> [String: Any] {
    var active: Transaction?
    var hasUnverified = false
    for await entitlement in Transaction.currentEntitlements {
      switch entitlement {
      case .verified(let transaction):
        guard transaction.productID == "ad_free_unlimited",
          transaction.productType == .nonConsumable,
          transaction.revocationDate == nil, !transaction.isUpgraded,
          transaction.expirationDate.map({ $0 > Date() }) ?? true
        else { continue }
        if active == nil || transaction.signedDate > active!.signedDate {
          active = transaction
        }
      case .unverified:
        // Even an unverified result must not turn absence into revocation.
        hasUnverified = true
      }
    }
    // A verified replacement purchase always wins over an older refund.
    if let active = active { return entitlementResult("active", active) }
    if hasUnverified { return ["status": "unknown"] }

    // Refunded/revoked purchases are excluded from currentEntitlements.
    // Look for signed revocation evidence, tied to the last cached purchase.
    if let latest = await Transaction.latest(for: "ad_free_unlimited") {
      switch latest {
      case .verified(let transaction):
        guard transaction.productID == "ad_free_unlimited",
          transaction.productType == .nonConsumable
        else { return ["status": "unknown"] }
        if transaction.revocationDate != nil {
          if String(transaction.id) == cachedID ||
            String(transaction.originalID) == cachedOriginalID
          {
            return entitlementResult("revoked", transaction)
          }
        } else {
          // History says owned but the current snapshot says absent. Treat
          // inconsistent or stale store data as unknown, even after sync.
          return ["status": "unknown"]
        }
      case .unverified:
        return ["status": "unknown"]
      }
    }
    // No account identifier is guessed. A completed, user-requested refresh
    // is required to clear a legacy cache or an owning-account switch.
    return ["status": synchronized ? "absentAfterSync" : "unknown"]
  }
}
