import Foundation
import SwiftUI

struct CartLine: Identifiable, Equatable {
    let id = UUID()
    let item: CatalogItem
    let option: String?          // chosen variation, e.g. "Chicken" on loaded fries
    let customizations: String?  // human string, e.g. "No Lettuce, Add Corn"
    var addOnCents: Int = 0      // paid extras chosen, e.g. Queso +$1, Extra Shrimp +$3.99
    var quantity: Int

    var unitCents: Int { Int((item.price * 100).rounded()) + addOnCents }
    var lineCents: Int { unitCents * quantity }

    var displayName: String {
        option.map { "\(item.name) (\($0))" } ?? item.name
    }
}

/// Client-side cart. Rates and rounding MUST match server.js: tax and fee are
/// each computed on the item subtotal and rounded to the cent independently.
/// The server recomputes everything at checkout — this is display math only.
@MainActor
final class CartStore: ObservableObject {
    @Published private(set) var lines: [CartLine] = []

    static let taxRate = 0.07
    static let feeRate = 0.03

    var subtotalCents: Int { lines.reduce(0) { $0 + $1.lineCents } }
    var taxCents: Int { Int((Double(subtotalCents) * Self.taxRate).rounded()) }
    var feeCents: Int { Int((Double(subtotalCents) * Self.feeRate).rounded()) }
    var totalCents: Int { subtotalCents + taxCents + feeCents }

    var itemCount: Int { lines.reduce(0) { $0 + $1.quantity } }
    var isEmpty: Bool { lines.isEmpty }

    func add(_ item: CatalogItem, option: String?, customizations: String?,
             addOnCents: Int = 0, quantity: Int) {
        // Merge identical lines (same item + option + customizations)
        if let idx = lines.firstIndex(where: {
            $0.item.id == item.id && $0.option == option && $0.customizations == customizations
        }) {
            lines[idx].quantity += quantity
        } else {
            lines.append(CartLine(item: item, option: option, customizations: customizations,
                                  addOnCents: addOnCents, quantity: quantity))
        }
    }

    func setQuantity(_ line: CartLine, to qty: Int) {
        guard let idx = lines.firstIndex(where: { $0.id == line.id }) else { return }
        if qty < 1 { lines.remove(at: idx) } else { lines[idx].quantity = qty }
    }

    func remove(_ line: CartLine) {
        lines.removeAll { $0.id == line.id }
    }

    func clear() { lines.removeAll() }

    var checkoutItems: [CheckoutItem] {
        lines.map {
            CheckoutItem(id: $0.item.id, name: $0.item.name, quantity: $0.quantity,
                         option: $0.option, customizations: $0.customizations)
        }
    }
}

func dollars(_ cents: Int) -> String {
    String(format: "$%.2f", Double(cents) / 100)
}
