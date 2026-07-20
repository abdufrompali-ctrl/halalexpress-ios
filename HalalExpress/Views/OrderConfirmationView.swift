import SwiftUI

struct OrderConfirmationView: View {
    let confirmation: CheckoutResponse
    var onDone: () -> Void

    @State private var celebrate = false

    private var pickupDate: Date? {
        confirmation.scheduledPickupAt.flatMap(slotDate)
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                        .scaleEffect(celebrate ? 1 : 0.3)
                        .rotationEffect(.degrees(celebrate ? 0 : -20))
                        .shadow(color: .green.opacity(celebrate ? 0.35 : 0), radius: 12, y: 4)

                    Text("Thanks, \(confirmation.customerName)!")
                        .font(.title2.bold())

                    // Scheduled → live countdown; ASAP → pulsing "preparing" indicator.
                    if let date = pickupDate {
                        TimelineView(.periodic(from: .now, by: 60)) { _ in
                            VStack(spacing: 3) {
                                Text("Ready around \(date.formatted(date: .omitted, time: .shortened))")
                                    .font(.headline)
                                if date > Date() {
                                    Text(date, format: .relative(presentation: .named))
                                        .font(.subheadline)
                                        .foregroundStyle(Brand.ember)
                                }
                                if let label = confirmation.scheduledLabel {
                                    Text(label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        Label("Preparing your order…", systemImage: "flame.fill")
                            .symbolEffect(.pulse)
                            .font(.headline)
                            .foregroundStyle(Brand.ember)
                        Text("We'll have it ready for you shortly.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
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

            Section {
                Button("Done") { onDone() }
                    .buttonStyle(BrandButtonStyle())
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Order Placed")
        .navigationBarBackButtonHidden(true)
        .sensoryFeedback(.success, trigger: celebrate)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                celebrate = true
            }
        }
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
