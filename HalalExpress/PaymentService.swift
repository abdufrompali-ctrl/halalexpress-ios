import Foundation

/// Produces the Square `sourceId` (payment token) that /api/checkout requires.
///
/// Phase 2: implement with Square's In-App Payments SDK (card entry + Apple Pay),
/// configured from /api/config (applicationId, locationId, environment). The
/// backend contract is identical to the website's Web Payments SDK flow.
protocol PaymentService {
    func tokenizeCard() async throws -> String
}

/// Placeholder until the Square SDK is wired in. In sandbox, Square accepts the
/// well-known test nonce so the full checkout flow can be exercised end-to-end.
struct StubPaymentService: PaymentService {
    let environment: String  // from /api/config

    func tokenizeCard() async throws -> String {
        if environment == "sandbox" { return "cnon:card-nonce-ok" }
        throw APIError.server("Card payments aren't available in the app yet — Square SDK integration is coming next.")
    }
}
