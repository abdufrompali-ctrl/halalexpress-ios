import Foundation

struct OrderLine: Codable, Hashable {
    let itemId: String            // maps back to the catalog for future reorder
    let name: String
    let option: String?
    let customizations: String?
    var addOnCents: Int = 0       // paid extras, preserved so reorders re-price correctly
    let quantity: Int

    private enum CodingKeys: String, CodingKey {
        case itemId, name, option, customizations, addOnCents, quantity
    }
    init(itemId: String, name: String, option: String?, customizations: String?,
         addOnCents: Int = 0, quantity: Int) {
        self.itemId = itemId; self.name = name; self.option = option
        self.customizations = customizations; self.addOnCents = addOnCents; self.quantity = quantity
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itemId = try c.decode(String.self, forKey: .itemId)
        name = try c.decode(String.self, forKey: .name)
        option = try c.decodeIfPresent(String.self, forKey: .option)
        customizations = try c.decodeIfPresent(String.self, forKey: .customizations)
        addOnCents = (try? c.decode(Int.self, forKey: .addOnCents)) ?? 0
        quantity = try c.decode(Int.self, forKey: .quantity)
    }
}

struct OrderRecord: Codable, Identifiable {
    let id: String                // Square payment/order id
    let date: Date
    let lines: [OrderLine]
    let totalCents: Int

    var summary: String {
        lines.map { "\($0.quantity)× \($0.name)" }.joined(separator: ", ")
    }
}

/// Local, persisted log of the customer's orders — the source for the reorder list.
@MainActor
final class OrderHistoryStore: ObservableObject {
    @Published private(set) var orders: [OrderRecord] = []
    private let key = "orderHistory.v1"

    init() { load() }

    func add(_ record: OrderRecord) {
        orders.insert(record, at: 0)   // newest first
        save()
    }

    func clear() {
        orders.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([OrderRecord].self, from: data)
        else { return }
        orders = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(orders) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
