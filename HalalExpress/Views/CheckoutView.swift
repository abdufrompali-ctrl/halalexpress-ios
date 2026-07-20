import SwiftUI

struct CheckoutView: View {
    @EnvironmentObject private var cart: CartStore
    @EnvironmentObject private var orders: OrderHistoryStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("loyaltyName")  private var savedName = ""
    @AppStorage("loyaltyPhone") private var savedPhone = ""
    @AppStorage("loyaltyEmail") private var savedEmail = ""

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""

    // Tip — 2×2 grid: 10% / 15% / 20% / Custom ($); nil = no tip
    private enum TipChoice: Equatable { case percent(Int); case custom }
    @State private var selectedTip: TipChoice?
    @State private var customTipCents = 0
    @State private var customTipText = ""
    @State private var showCustomTipSheet = false

    // Pickup — ASAP or iOS-clock style dual wheels over server slots
    private enum PickupMode: Hashable { case asap, scheduled }
    @State private var pickupMode: PickupMode = .asap
    @State private var shiftIndex = 0
    @State private var slotIndex = 0
    @State private var shifts: [Shift] = []
    @State private var hours: HoursStatus?

    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var confirmation: CheckoutResponse?

    private var tipCents: Int {
        switch selectedTip {
        case .percent(let p): return Int((Double(cart.subtotalCents) * Double(p) / 100).rounded())
        case .custom: return customTipCents
        case nil: return 0
        }
    }
    private var chargeCents: Int { cart.totalCents + tipCents }

    private var selectedSlot: String? {
        guard shifts.indices.contains(shiftIndex) else { return nil }
        let slots = shifts[shiftIndex].slots
        guard slots.indices.contains(slotIndex) else { return slots.first }
        return slots[slotIndex]
    }

    private var formValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        phone.filter(\.isNumber).count >= 10 && !cart.isEmpty &&
        (pickupMode == .asap ? hours?.orderingOpen == true : selectedSlot != nil)
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

            pickupSection

            tipSection

            Section("Order Summary") {
                summaryRow("Subtotal", cart.subtotalCents)
                summaryRow("Tax (7%)", cart.taxCents)
                summaryRow("Service Fee (3%)", cart.feeCents)
                summaryRow("Tip", tipCents)
                Divider()
                HStack {
                    Text("Total").font(.title3.weight(.bold))
                    Spacer()
                    Text(dollars(chargeCents))
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(Brand.red)
                }
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
            OrderConfirmationView(confirmation: conf) {
                confirmation = nil
                dismiss()
            }
        }
        .sheet(isPresented: $showCustomTipSheet) { customTipSheet }
        .sensoryFeedback(.selection, trigger: selectedTip)
    }

    // MARK: - Pickup time (iOS-clock style)

    @ViewBuilder
    private var pickupSection: some View {
        Section("Pickup Time") {
            if hours?.orderingOpen == true {
                Picker("Pickup mode", selection: $pickupMode) {
                    Text("ASAP").tag(PickupMode.asap)
                    Text("Schedule").tag(PickupMode.scheduled)
                }
                .pickerStyle(.segmented)
            } else if let msg = hours?.message {
                Label(msg, systemImage: "clock.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if pickupMode == .scheduled || hours?.orderingOpen != true {
                if shifts.isEmpty {
                    Text("No order-ahead times available right now.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 0) {
                        Picker("Day", selection: $shiftIndex) {
                            ForEach(Array(shifts.enumerated()), id: \.offset) { i, shift in
                                Text(shift.label).tag(i)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()

                        Picker("Time", selection: $slotIndex) {
                            let slots = shifts.indices.contains(shiftIndex) ? shifts[shiftIndex].slots : []
                            ForEach(Array(slots.enumerated()), id: \.offset) { i, slot in
                                Text(slotTimeLabel(slot)).tag(i)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                    .frame(height: 130)
                    .onChange(of: shiftIndex) { _, _ in slotIndex = 0 }

                    if shifts.indices.contains(shiftIndex), let loc = shifts[shiftIndex].location {
                        Label(loc.display, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Tip grid

    @ViewBuilder
    private var tipSection: some View {
        Section("Add a Tip") {
            VStack(spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach([10, 15, 20], id: \.self) { p in
                        tipTile(selected: selectedTip == .percent(p)) {
                            VStack(spacing: 2) {
                                Text("\(p)%").font(.title2.weight(.heavy))
                                Text(dollars(Int((Double(cart.subtotalCents) * Double(p) / 100).rounded())))
                                    .font(.caption.monospacedDigit())
                                    .opacity(0.85)
                            }
                        } action: {
                            selectedTip = (selectedTip == .percent(p)) ? nil : .percent(p)
                        }
                    }

                    tipTile(selected: selectedTip == .custom) {
                        VStack(spacing: 2) {
                            if selectedTip == .custom && customTipCents > 0 {
                                Text(dollars(customTipCents))
                                    .font(.title3.weight(.heavy).monospacedDigit())
                                Text("Custom").font(.caption).opacity(0.85)
                            } else {
                                Image(systemName: "pencil")
                                    .font(.title3.weight(.bold))
                                Text("Custom").font(.caption.weight(.semibold))
                            }
                        }
                    } action: {
                        customTipText = customTipCents > 0
                            ? String(format: "%.2f", Double(customTipCents) / 100) : ""
                        showCustomTipSheet = true
                    }
                }

                Button("No tip") { selectedTip = nil }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.borderless)
                    .opacity(selectedTip == nil ? 0.45 : 1)
            }
            .padding(.vertical, 6)
            .listRowBackground(Color.clear)
        }
    }

    private func tipTile<Content: View>(selected: Bool,
                                        @ViewBuilder content: () -> Content,
                                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            content()
                .frame(maxWidth: .infinity)
                .frame(height: 78)
                .foregroundStyle(selected ? Color.white : Brand.red)
                .background {
                    if selected {
                        LinearGradient.brand
                    } else {
                        Brand.red.opacity(0.08)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: selected ? Brand.red.opacity(0.35) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var customTipSheet: some View {
        VStack(spacing: 20) {
            Capsule().fill(.tertiary).frame(width: 36, height: 5).padding(.top, 10)
            Text("Custom Tip").font(.headline)

            HStack(spacing: 6) {
                Text("$")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $customTipText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 40)

            Button("Set Tip") {
                let normalized = customTipText.replacingOccurrences(of: ",", with: ".")
                let cents = Int(((Double(normalized) ?? 0) * 100).rounded())
                customTipCents = min(max(cents, 0), 100_000)   // server caps at $1,000
                selectedTip = customTipCents > 0 ? .custom : nil
                showCustomTipSheet = false
            }
            .buttonStyle(BrandButtonStyle())
            .padding(.horizontal)

            Button("Cancel") { showCustomTipSheet = false }
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .presentationDetents([.height(300)])
    }

    // MARK: - Summary

    private func summaryRow(_ label: String, _ cents: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(dollars(cents)).monospacedDigit()
        }
        .font(.subheadline)
    }

    // MARK: - Data

    private func loadOptions() async {
        // Prefill from the saved Rewards profile so returning customers breeze through.
        if name.isEmpty { name = savedName }
        if phone.isEmpty { phone = savedPhone }
        if email.isEmpty { email = savedEmail }

        hours = try? await APIClient.shared.hours()
        shifts = (try? await APIClient.shared.scheduleSlots())?.shifts ?? []
        // Truck closed → ASAP impossible; land on the scheduler.
        if hours?.orderingOpen != true {
            pickupMode = .scheduled
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
                scheduledPickupAt: pickupMode == .scheduled ? selectedSlot : nil
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
}

extension CheckoutResponse: Hashable, Identifiable {
    var id: String { orderId }
    static func == (lhs: CheckoutResponse, rhs: CheckoutResponse) -> Bool { lhs.orderId == rhs.orderId }
    func hash(into hasher: inout Hasher) { hasher.combine(orderId) }
}
