import Foundation
import PassKit
#if canImport(UIKit)
import UIKit
#endif

// Produces the Square `sourceId` (payment token) that /api/checkout requires.
// The backend contract is identical to the website's Web Payments SDK flow —
// the app tokenizes a card/Apple Pay locally and sends only the nonce; no PAN
// ever touches our server, and no Square keys are embedded in the app
// (applicationId / locationId / environment all come from /api/config).
//
// ─────────────────────────────────────────────────────────────────────────────
// WIRING THE REAL SQUARE SDK (one-time setup):
//   1. Add the dependency and regenerate the project:
//        • SPM:        https://github.com/square/in-app-payments-ios
//        • or CocoaPods:  pod 'SquareInAppPaymentsSDK'
//      Add it under `packages:`/`dependencies:` in project.yml, then `xcodegen`.
//   2. In HalalExpressApp.init(), once /api/config is fetched:
//        SQIPInAppPaymentsSDK.squareApplicationID = config.applicationId
//   3. For Apple Pay, set your Merchant ID in Signing & Capabilities and in
//      `applePayMerchantID` below.
// Once the module is present, the `#if canImport(SquareInAppPaymentsSDK)` block
// compiles and becomes the live implementation automatically.
// ─────────────────────────────────────────────────────────────────────────────

enum PaymentError: LocalizedError {
    case unavailable(String)
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let m): return m
        case .cancelled:          return "Payment canceled."
        case .failed(let m):      return m
        }
    }
}

@MainActor
protocol PaymentService {
    /// Whether Apple Pay is set up on this device for our merchant.
    var applePaySupported: Bool { get }
    /// Present Square's card-entry UI and return a single-use card nonce.
    func tokenizeCard() async throws -> String
    /// Present the Apple Pay sheet for `amountCents` and return a Square nonce.
    func tokenizeApplePay(amountCents: Int, summaryLabel: String) async throws -> String
}

/// Your Apple Pay merchant identifier (must match the entitlement). Wire when you
/// enable Apple Pay in the Square dashboard + Xcode capabilities.
let applePayMerchantID = "merchant.com.halalexpress.app"

enum PaymentServiceFactory {
    static func make(config: ServerConfig) -> PaymentService {
        #if canImport(SquareInAppPaymentsSDK)
        return SquarePaymentService(config: config)
        #else
        return FallbackPaymentService(environment: config.environment ?? "production")
        #endif
    }
}

// MARK: - Fallback (until the SDK is added)
//
// Sandbox returns Square's public test nonce so the whole order flow can be
// exercised end-to-end. Production fails loudly and honestly rather than
// pretending to charge a card that was never entered.

@MainActor
struct FallbackPaymentService: PaymentService {
    let environment: String
    var applePaySupported: Bool { false }

    func tokenizeCard() async throws -> String {
        if environment == "sandbox" { return "cnon:card-nonce-ok" }
        throw PaymentError.unavailable(
            "Card payment in the app isn't set up yet. You can order through DoorDash or Uber Eats, or pay at the truck.")
    }

    func tokenizeApplePay(amountCents: Int, summaryLabel: String) async throws -> String {
        if environment == "sandbox" { return "cnon:card-nonce-ok" }
        throw PaymentError.unavailable("Apple Pay isn't set up yet.")
    }
}

// MARK: - Real Square implementation
//
// Compiled only once SquareInAppPaymentsSDK is a dependency. Kept faithful to
// Square's In-App Payments API so it's live the moment the module resolves; if a
// symbol name drifts across SDK versions, it's an isolated, well-marked fix here.

#if canImport(SquareInAppPaymentsSDK)
import SquareInAppPaymentsSDK

@MainActor
final class SquarePaymentService: NSObject, PaymentService {
    private let environment: String
    init(config: ServerConfig) {
        self.environment = config.environment ?? "production"
        if let appId = config.applicationId {
            SQIPInAppPaymentsSDK.squareApplicationID = appId
        }
    }

    var applePaySupported: Bool {
        SQIPInAppPaymentsSDK.canUseApplePay &&
        PKPaymentAuthorizationController.canMakePayments()
    }

    // Card entry ------------------------------------------------------------
    private var cardContinuation: CheckedContinuation<String, Error>?

    func tokenizeCard() async throws -> String {
        guard let presenter = Self.topViewController() else {
            throw PaymentError.failed("Couldn't present the card form.")
        }
        let theme = SQIPTheme()
        theme.errorColor = .systemRed
        theme.saveButtonTitle = "Pay"
        let cardEntry = SQIPCardEntryViewController(theme: theme)
        cardEntry.delegate = self
        let nav = UINavigationController(rootViewController: cardEntry)
        return try await withCheckedThrowingContinuation { cont in
            self.cardContinuation = cont
            presenter.present(nav, animated: true)
        }
    }

    // Apple Pay -------------------------------------------------------------
    private var applePayContinuation: CheckedContinuation<String, Error>?

    func tokenizeApplePay(amountCents: Int, summaryLabel: String) async throws -> String {
        let request = PKPaymentRequest.squarePaymentRequest(
            merchantIdentifier: applePayMerchantID,
            countryCode: "US",
            currencyCode: "USD")
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: summaryLabel,
                                 amount: NSDecimalNumber(value: Double(amountCents) / 100))
        ]
        guard let controller = PKPaymentAuthorizationController(paymentRequest: request) as PKPaymentAuthorizationController?
        else { throw PaymentError.unavailable("Apple Pay unavailable.") }
        controller.delegate = self
        return try await withCheckedThrowingContinuation { cont in
            self.applePayContinuation = cont
            controller.present(completion: nil)
        }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

extension SquarePaymentService: SQIPCardEntryViewControllerDelegate {
    func cardEntryViewController(_ vc: SQIPCardEntryViewController,
                                 didObtain result: SQIPCardDetails,
                                 completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
        cardContinuation?.resume(returning: result.nonce)
        cardContinuation = nil
    }
    func cardEntryViewController(_ vc: SQIPCardEntryViewController,
                                 didCompleteWith status: SQIPCardEntryCompletionStatus) {
        vc.dismiss(animated: true)
        if status == .canceled, let cont = cardContinuation {
            cont.resume(throwing: PaymentError.cancelled)
            cardContinuation = nil
        }
    }
}

extension SquarePaymentService: PKPaymentAuthorizationControllerDelegate {
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController,
                                        didAuthorizePayment payment: PKPayment,
                                        handler: @escaping (PKPaymentAuthorizationResult) -> Void) {
        let params = SQIPApplePayNonceRequest(payment: payment)
        params.perform { details, error in
            if let details {
                handler(.init(status: .success, errors: nil))
                self.applePayContinuation?.resume(returning: details.nonce)
            } else {
                handler(.init(status: .failure, errors: error.map { [$0] }))
                self.applePayContinuation?.resume(throwing: error ?? PaymentError.failed("Apple Pay failed."))
            }
            self.applePayContinuation = nil
        }
    }
    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss(completion: nil)
        if let cont = applePayContinuation {   // finished without authorizing
            cont.resume(throwing: PaymentError.cancelled)
            applePayContinuation = nil
        }
    }
}
#endif
