import SwiftUI

struct OrderConfirmationView: View {
    let confirmation: CheckoutResponse
    var onDone: () -> Void

    private var pickupDate: Date? { confirmation.scheduledPickupAt.flatMap(slotDate) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Headline block
                VStack(alignment: .leading, spacing: 8) {
                    Text("ORDER IN").font(.board(56)).foregroundStyle(Paper.red)
                    Rectangle().fill(Paper.red).frame(width: 120, height: 4)
                    Text("Thanks, \(confirmation.customerName).")
                        .font(.system(.title3, design: .default).weight(.semibold))
                        .foregroundStyle(Paper.ink)
                        .padding(.top, 8)

                    if let date = pickupDate {
                        TimelineView(.periodic(from: .now, by: 60)) { _ in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ready around \(date.formatted(date: .omitted, time: .shortened))")
                                    .font(.headline).foregroundStyle(Paper.ink)
                                if date > Date() {
                                    Text(date, format: .relative(presentation: .named))
                                        .font(.subheadline).foregroundStyle(Paper.inkSoft)
                                }
                                if let label = confirmation.scheduledLabel {
                                    Text(label).font(.caption).foregroundStyle(Paper.inkSoft)
                                }
                            }
                        }
                        .padding(.top, 4)
                    } else {
                        Text("We're preparing it now — we'll have it ready shortly.")
                            .font(.subheadline).foregroundStyle(Paper.inkSoft).padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 20)

                Rule()

                // Receipt
                VStack(spacing: 8) {
                    receiptRow("Subtotal", confirmation.subtotal)
                    receiptRow("Tax", confirmation.tax)
                    receiptRow("Service fee", confirmation.serviceFee)
                    if confirmation.tip > 0 { receiptRow("Tip", confirmation.tip) }
                    Rule().padding(.vertical, 2)
                    receiptRow("Total charged", confirmation.total, bold: true)
                }
                .padding(.horizontal, 20).padding(.vertical, 16)

                Rule()

                VStack(alignment: .leading, spacing: 6) {
                    metaRow("Order", confirmation.orderId)
                    metaRow("Status", confirmation.status.capitalized)
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
        }
        .scrollContentBackground(.hidden)
        .paperGround()
        .navigationTitle("Order placed")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Paper.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            Button("Done") { onDone() }
                .buttonStyle(SignButtonStyle())
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 8)
                .background(Paper.bg)
                .overlay(alignment: .top) { Rule() }
        }
        .sensoryFeedback(.success, trigger: confirmation.orderId)
    }

    private func receiptRow(_ label: String, _ amount: Double, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(bold ? .system(.body, design: .default).weight(.bold) : .subheadline)
                .foregroundStyle(bold ? Paper.ink : Paper.inkSoft)
            Spacer()
            Text(String(format: "$%.2f", amount))
                .font(.price(bold ? 17 : 14)).foregroundStyle(bold ? Paper.red : Paper.ink)
        }
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(Paper.inkFaint)
            Spacer()
            Text(value).font(.system(.caption, design: .monospaced)).foregroundStyle(Paper.inkSoft)
        }
    }
}
