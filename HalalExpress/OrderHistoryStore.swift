import Foundation

struct OrderLine: Codable, Hashable {
    let itemId: String            // maps back to the catalog for future reorder
    let name: String
    let option: String?
    let customizations: String?
    let quantity: Int
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
