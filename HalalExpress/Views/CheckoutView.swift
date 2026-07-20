import SwiftUI

struct CheckoutView: View {
    @EnvironmentObject private var cart: CartStore
    @EnvironmentObject private var orders: OrderHistoryStore

    @AppStorage("loyaltyName")  private var savedName = ""
    @AppStorage("loyaltyPhone") private var savedPhone = ""
    @AppStorage("loyaltyEmail") private var savedEmail = ""

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""

    @State private var tipPercent: Int = 0            // 0 = no tip
    private let tipChoices = [0, 10, 15, 20]

    @State private var shifts: [Shift] = []
    @State private var scheduledSlot: String?         // nil = ASAP
    @State private var hours: HoursStatus?

    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var confirmation: CheckoutResponse?

    private var tipCents: Int {
        tipPercent == 0 ? 0 : Int((Double(cart.subtotalCents) * Double(tipPercent) / 100).rounded())
    }
    private var chargeCents: Int { cart.totalCents + tipCents }
    private var formValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        phone.filter(\.isNumber).count >= 10 && !cart.isEmpty
    }

    var body: some View {
        Form {
            Section("Your Info") {
                TextField("Name", text: $name)
                    .textContentType(.name)
                TextField("Phone", text: $phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                TextField("Email (optional, for receipt)", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }

            Section("Pickup Time") {
                Picker("Pickup", selection: $scheduledSlot) {
                    if hours?.orderingOpen == true {
                        Text("ASAP").tag(String?.none)
                    }
                    ForEach(shifts) { shift in
                        ForEach(shift.slots, id: \.self) { slot in
                            Text("\(shift.label) \(timeLabel(slot))").tag(Optional(slot))
                        }
                    }
                }
                if hours?.orderingOpen == false, let msg = hours?.message {
                    Text(msg).font(.caption).foregroundStyle(.orange)
                }
            }

            Section("Tip") {
                Picker("Tip", selection: $tipPercent) {
                    ForEach(tipChoices, id: \.self) { p in
                        Text(p == 0 ? "None" : "\(p)% (\(dollars(p == 0 ? 0 : Int((Double(cart.subtotalCents) * Double(p) / 100).rounded()))))").tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Total") {
                LabeledContent("Order + tax + fee", value: dollars(cart.totalCents))
                if tipCents > 0 { LabeledContent("Tip", value: dollars(tipCents)) }
                LabeledContent("Charge", value: dollars(chargeCents)).fontWeight(.semibold)
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }

        }
        .navigationTitle("Checkout")
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await submit() }
            } label: {
                HStack {
                    if submitting {
                        ProgressView().tint(.white).padding(.trailing, 4)
                    } else {
                        Image(systemName: "lock.fill")
                    }
                    Text("Pay")
                    Spacer()
                    Text(dollars(chargeCents)).monospacedDigit()
                }
            }
            .buttonStyle(BrandButtonStyle(enabled: formValid && !submitting))
            .disabled(!formValid || submitting)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .task { await loadOptions() }
        .navigationDestination(item: $confirmation) { conf in
            OrderConfirmationView(confirmation: conf)
        }
    }

    private func loadOptions() async {
        // Prefill from the saved Rewards profile so returning customers breeze through.
        if name.isEmpty { name = savedName }
        if phone.isEmpty { phone = savedPhone }
        if email.isEmpty { email = savedEmail }

        hours = try? await APIClient.shared.hours()
        shifts = (try? await APIClient.shared.scheduleSlots())?.shifts ?? []
        // If ordering is closed right now, default to the first order-ahead slot
        if hours?.orderingOpen != true, scheduledSlot == nil {
            scheduledSlot = shifts.first?.slots.first
        }
    }

    private func submit() async {
        submitting = true
        defer { submitting = false }
        errorMessage = nil
        do {
            let config = try await APIClient.shared.config()
            let payment: PaymentService = StubPaymentService(environment: config.environment ?? "production")
            let sourceId = try await payment.tokenizeCard()

            let req = CheckoutRequest(
                items: cart.checkoutItems,
                customer: CheckoutCustomer(
                    name: name.trimmingCharacters(in: .whitespaces),
                    phone: phone.filter(\.isNumber),
                    email: email.isEmpty ? nil : email
                ),
                sourceId: sourceId,
                idempotencyKey: UUID().uuidString,
                tipCents: tipCents > 0 ? tipCents : nil,
                scheduledPickupAt: scheduledSlot
            )
            let resp = try await APIClient.shared.checkout(req)
            // Log the order locally (powers the reorder list) before clearing the cart.
            let lines = cart.lines.map {
                OrderLine(itemId: $0.item.id, name: $0.item.name,
                          option: $0.option, customizations: $0.customizations,
                          quantity: $0.quantity)
            }
            orders.add(OrderRecord(id: resp.orderId, date: Date(),
                                   lines: lines, totalCents: Int((resp.total * 100).rounded())))
            cart.clear()
            confirmation = resp
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func timeLabel(_ iso: String) -> String {
        // Server slots come from JS toISOString() — includes fractional seconds
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = withFrac.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else {
            return iso
        }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

extension CheckoutResponse: Hashable, Identifiable {
    var id: String { orderId }
    static func == (lhs: CheckoutResponse, rhs: CheckoutResponse) -> Bool { lhs.orderId == rhs.orderId }
    func hash(into hasher: inout Hasher) { hasher.combine(orderId) }
}
