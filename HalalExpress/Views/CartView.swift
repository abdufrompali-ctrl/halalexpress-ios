import SwiftUI

struct CartView: View {
    @EnvironmentObject private var cart: CartStore

    var body: some View {
        NavigationStack {
            Group {
                if cart.isEmpty {
                    ContentUnavailableView("Your cart is empty",
                                           systemImage: "cart",
                                           description: Text("Add something tasty from the menu."))
                } else {
                    List {
                        Section {
                            ForEach(cart.lines) { line in
                                CartRow(line: line)
                            }
                            .onDelete { idx in
                                idx.map { cart.lines[$0] }.forEach { cart.remove($0) }
                            }
                        }

                        Section("Order Total") {
                            row("Subtotal", cart.subtotalCents)
                            row("Tax (7%)", cart.taxCents)
                            row("Service Fee (3%)", cart.feeCents)
                            row("Total", cart.totalCents, bold: true)
                        }

                        Section {
                            NavigationLink("Checkout") { CheckoutView() }
                                .font(.headline)
                        }
                    }
                }
            }
            .navigationTitle("Cart")
        }
    }

    private func row(_ label: String, _ cents: Int, bold: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(dollars(cents)).monospacedDigit()
        }
        .fontWeight(bold ? .semibold : .regular)
    }
}

struct CartRow: View {
    @EnvironmentObject private var cart: CartStore
    let line: CartLine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(line.displayName).font(.headline)
                Spacer()
                Text(dollars(line.lineCents)).monospacedDigit()
            }
            if let custom = line.customizations {
                Text(custom).font(.caption).foregroundStyle(.secondary)
            }
            Stepper("Qty: \(line.quantity)", value: Binding(
                get: { line.quantity },
                set: { cart.setQuantity(line, to: $0) }
            ), in: 0...20)
            .font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}
