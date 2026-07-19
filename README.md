# Halal Express — iOS App

Native SwiftUI customer-ordering app for [halalexpressnc.com](https://halalexpressnc.com).
Talks to the existing Express/Square backend on the VPS — the server stays the
source of truth for prices, tax (7%), service fee (3%), hours, and payment capture.

## Layout

- `project.yml` — [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec; the
  `.xcodeproj` is generated, never hand-edited. Developed entirely from Linux.
- `HalalExpress/` — Swift sources
  - `Models.swift` — decodables mirroring `/api/catalog`, `/api/hours`,
    `/api/schedule-slots`, `/api/checkout`, `/api/loyalty/*`
  - `APIClient.swift` — async networking against `https://halalexpressnc.com`
  - `CartStore.swift` — cart + display totals (same cent-rounding as server.js)
  - `PaymentService.swift` — Square tokenization seam (stubbed; see Phase 2)
  - `Views/` — Menu → Item detail (options/toppings/sauces/extras) → Cart →
    Checkout (ASAP or order-ahead slots, tip) → Confirmation; Rewards tab
- `.github/workflows/build.yml` — the "free Mac": GitHub's macOS runner
  generates the project and builds an **unsigned IPA** artifact on every push.

## Building & installing without a Mac (free, no $99 account)

1. Push this repo to GitHub (public repo → unlimited free macOS CI minutes).
2. The **Build iOS app** workflow produces `HalalExpress-unsigned-ipa` under
   the run's Artifacts.
3. Sideload the IPA onto your iPhone with **AltStore** or **Sideloadly** using a
   free Apple ID. Free-tier signing expires every **7 days** — re-sideload to
   renew (AltServer can auto-refresh over Wi-Fi).

Later, for TestFlight/App Store: join the Apple Developer Program ($99/yr) and
add signing + upload steps to the workflow (or switch to Xcode Cloud).

## Phase 2 — real payments

`StubPaymentService` refuses to tokenize in production (and uses Square's
`cnon:card-nonce-ok` test nonce in sandbox). To take real cards:

1. Add Square's **In-App Payments SDK** (card entry + Apple Pay).
2. Configure it from `/api/config` (`applicationId`, `locationId`, `environment`).
3. Implement `PaymentService.tokenizeCard()` to return the SDK's nonce —
   `/api/checkout` already accepts it unchanged (same contract as the website's
   Web Payments SDK flow).
