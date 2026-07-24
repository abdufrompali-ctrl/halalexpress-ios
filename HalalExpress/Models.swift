import Foundation

// Mirrors the JSON served by https://halalexpressnc.com/api/* (server.js on the VPS).

/// Wrapper that decodes an element but never throws — a per-element decode failure
/// becomes `nil` instead of failing the whole surrounding array. Lets one malformed
/// record from the backend be dropped rather than blanking an entire response.
struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

// MARK: - /api/catalog

struct Catalog: Decodable {
    let items: [CatalogItem]
    let categories: [String]   // ["PLATES", "WRAPS", "LOADED", "SIDES", "EXTRAS"]

    private enum CodingKeys: String, CodingKey { case items, categories }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categories = (try? c.decode([String].self, forKey: .categories)) ?? []
        // Drop only the items that fail to decode — never the whole menu.
        let raw = (try? c.decode([FailableDecodable<CatalogItem>].self, forKey: .items)) ?? []
        items = raw.compactMap(\.value)
    }
}

struct CatalogItem: Decodable, Identifiable, Hashable {
    let id: String             // e.g. "chicken-rice"
    let squareId: String
    let name: String
    let category: String
    let price: Double          // base price; option-specific prices live server-side
    let desc: String
    let options: [String]?     // variation names when the item has real choices
    let customize: CustomizeGroups?
    let imageURL: URL?         // Square catalog photo; nil until the API serves it

    private enum CodingKeys: String, CodingKey {
        case id, squareId, name, category, price, desc, options, customize, imageURL
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Required to be a usable menu row; a row missing any of these is dropped.
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        price = try c.decode(Double.self, forKey: .price)
        // Tolerated — sensible defaults so a thin record still renders.
        category = (try? c.decode(String.self, forKey: .category)) ?? "EXTRAS"
        squareId = (try? c.decode(String.self, forKey: .squareId)) ?? ""
        desc = (try? c.decode(String.self, forKey: .desc)) ?? ""
        options = try? c.decodeIfPresent([String].self, forKey: .options)
        customize = try? c.decodeIfPresent(CustomizeGroups.self, forKey: .customize)
        imageURL = try? c.decodeIfPresent(URL.self, forKey: .imageURL)
    }
}

struct CustomizeGroups: Decodable, Hashable {
    let toppings: [Modifier]?
    let sauces: [Modifier]?
    let extras: [Modifier]?
}

struct Modifier: Decodable, Identifiable, Hashable {
    let id: String
    let label: String
    let isDefault: Bool
    let isChecked: Bool
    let price: Double          // upcharge in dollars (e.g. Queso 1, Extra Shrimp 3.99); 0 for free

    private enum CodingKeys: String, CodingKey { case id, label, `default`, checked, price }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decode(String.self, forKey: .label)
        isDefault = (try? c.decode(Bool.self, forKey: .default)) ?? false
        isChecked = (try? c.decode(Bool.self, forKey: .checked)) ?? false
        price = (try? c.decode(Double.self, forKey: .price)) ?? 0
    }

    var priceCents: Int { Int((price * 100).rounded()) }
    /// "Queso (+$1.00)" for the picker; plain label when free.
    var pricedLabel: String { priceCents > 0 ? "\(label) (+\(dollars(priceCents)))" : label }
}

// MARK: - /api/hours

struct HoursStatus: Decodable {
    let orderingOpen: Bool
    let message: String?
    let location: TruckLocation?
}

struct TruckLocation: Decodable, Hashable {
    let address: String?
    let city: String?
    let label: String?

    var display: String {
        [label, address, city].compactMap { $0 }.joined(separator: ", ")
    }
}

// MARK: - /api/schedule-slots

struct ScheduleResponse: Decodable {
    let shifts: [Shift]
}

struct Shift: Decodable, Identifiable, Hashable {
    let label: String          // "Today" / "Tomorrow" / weekday
    let location: TruckLocation?
    let slots: [String]        // ISO-8601 pickup times
    var id: String { label + (slots.first ?? "") }
}

// MARK: - /api/checkout

struct CheckoutItem: Encodable {
    let id: String
    let name: String
    let quantity: Int
    let option: String?
    let customizations: String?
}

struct CheckoutCustomer: Encodable {
    let name: String
    let phone: String
    let email: String?
}

struct CheckoutRequest: Encodable {
    let items: [CheckoutItem]
    let customer: CheckoutCustomer
    let sourceId: String        // Square payment token (In-App Payments SDK — phase 2)
    let idempotencyKey: String
    let tipCents: Int?
    let scheduledPickupAt: String?
}

struct CheckoutResponse: Decodable {
    let success: Bool
    let orderId: String
    let customerName: String
    let subtotal: Double
    let tax: Double
    let serviceFee: Double
    let tip: Double
    let total: Double
    let status: String
    let scheduledPickupAt: String?
    let scheduledLabel: String?

    private enum CodingKeys: String, CodingKey {
        case success, orderId, customerName, subtotal, tax, serviceFee, tip, total,
             status, scheduledPickupAt, scheduledLabel
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // orderId is the one field that must exist — it's our proof the charge produced
        // an order. Everything else defaults, so a thin/partial body after a *successful*
        // charge is still treated as success (and the receipt just shows what we have)
        // rather than surfacing a scary error over an order the customer already paid for.
        orderId = try c.decode(String.self, forKey: .orderId)
        success = (try? c.decode(Bool.self, forKey: .success)) ?? true
        customerName = (try? c.decode(String.self, forKey: .customerName)) ?? ""
        subtotal = (try? c.decode(Double.self, forKey: .subtotal)) ?? 0
        tax = (try? c.decode(Double.self, forKey: .tax)) ?? 0
        serviceFee = (try? c.decode(Double.self, forKey: .serviceFee)) ?? 0
        tip = (try? c.decode(Double.self, forKey: .tip)) ?? 0
        total = (try? c.decode(Double.self, forKey: .total)) ?? 0
        status = (try? c.decode(String.self, forKey: .status)) ?? "received"
        scheduledPickupAt = try? c.decodeIfPresent(String.self, forKey: .scheduledPickupAt)
        scheduledLabel = try? c.decodeIfPresent(String.self, forKey: .scheduledLabel)
    }
}

// MARK: - /api/config

struct ServerConfig: Decodable {
    let applicationId: String?
    let locationId: String?
    let environment: String?    // "sandbox" | "production"
}

// MARK: - /api/loyalty

struct LoyaltyJoinResponse: Decodable {
    let ok: Bool
    let alreadyMember: Bool?
}

struct LoyaltyStatus: Decodable {
    let found: Bool
    let name: String?
}
