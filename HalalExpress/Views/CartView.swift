import SwiftUI

struct CartView: View {
    var onFinished: () -> Void = {}

    @EnvironmentObject private var cart: CartStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PaperGroundLayer()
                if cart.isEmpty {
                    ContentUnavailableView("Your cart is empty",
                                           systemImage: "cart",
                                           description: Text("Add a dish from the menu to start an order."))
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            Rule()
                            ForEach(cart.lines) { line in
                                CartRow(line: line)
                                Rule().padding(.leading, 20)
                            }
                            totals.padding(.top, 8)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .safeAreaInset(edge: .bottom) { checkoutBar }
                }
            }
            .navigationTitle("Your Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Paper.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(Paper.red)
                }
            }
        }
    }

    private var totals: some View {
        VStack(spacing: 8) {
            row("Subtotal", cart.subtotalCents)
            row("Tax (7%)", cart.taxCents)
            row("Service fee (3%)", cart.feeCents)
            Rule().padding(.vertical, 2)
            row("Total", cart.totalCents, bold: true)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    private var checkoutBar: some View {
        NavigationLink {
            CheckoutView(onFinished: onFinished)
        } label: {
            HStack {
                Text("Checkout")
                Spacer()
                Text(dollars(cart.totalCents)).font(.price(17))
            }
        }
        .buttonStyle(SignButtonStyle())
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 8)
        .background(Paper.bg)
        .overlay(alignment: .top) { Rule() }
    }

    private func row(_ label: String, _ cents: Int, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(bold ? .system(.body, design: .default).weight(.bold) : .subheadline)
                .foregroundStyle(bold ? Paper.ink : Paper.inkSoft)
            Spacer()
            Text(dollars(cents))
                .font(.price(bold ? 17 : 14))
                .foregroundStyle(bold ? Paper.red : Paper.ink)
        }
    }
}

struct CartRow: View {
    @EnvironmentObject private var cart: CartStore
    let line: CartLine

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(line.displayName)
                        .font(.system(.body, design: .default).weight(.semibold))
                        .foregroundStyle(Paper.ink)
                    DottedLeader()
                    Text(dollars(line.lineCents)).font(.price(15)).foregroundStyle(Paper.ink)
                }
                if let custom = line.customizations {
                    Text(custom).font(.footnote).foregroundStyle(Paper.inkSoft)
                }
                Stepper(value: Binding(get: { line.quantity },
                                       set: { cart.setQuantity(line, to: $0) }),
                        in: 0...20) {
                    Text("Qty \(line.quantity)").font(.subheadline).foregroundStyle(Paper.inkSoft)
                }
                .fixedSize()
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }
}
