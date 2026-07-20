import Foundation

// Mirrors the JSON served by https://halalexpressnc.com/api/* (server.js on the VPS).

// MARK: - /api/catalog

struct Catalog: Decodable {
    let items: [CatalogItem]
    let categories: [String]   // ["PLATES", "WRAPS", "LOADED", "SIDES", "EXTRAS"]
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

    private enum CodingKeys: String, CodingKey { case id, label, `default`, checked }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decode(String.self, forKey: .label)
        isDefault = (try? c.decode(Bool.self, forKey: .default)) ?? false
        isChecked = (try? c.decode(Bool.self, forKey: .checked)) ?? false
    }
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
