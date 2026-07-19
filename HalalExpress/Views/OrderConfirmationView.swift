import SwiftUI

struct OrderConfirmationView: View {
    let confirmation: CheckoutResponse

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text("Thanks, \(confirmation.customerName)!")
                        .font(.title2.bold())
                    Text(confirmation.scheduledLabel.map { "Scheduled for pickup \($0)." }
                         ?? "We'll have it ready for you shortly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .listRowBackground(Color.clear)

            Section("Receipt") {
                row("Subtotal", confirmation.subtotal)
                row("Tax", confirmation.tax)
                row("Service Fee", confirmation.serviceFee)
                if confirmation.tip > 0 { row("Tip", confirmation.tip) }
                row("Total Charged", confirmation.total, bold: true)
            }

            Section {
                LabeledContent("Order ID", value: confirmation.orderId)
                    .font(.caption)
                LabeledContent("Status", value: confirmation.status)
                    .font(.caption)
            }
        }
        .navigationTitle("Order Placed")
        .navigationBarBackButtonHidden(true)
    }

    private func row(_ label: String, _ amount: Double, bold: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "$%.2f", amount)).monospacedDigit()
        }
        .fontWeight(bold ? .semibold : .regular)
    }
}
