import SwiftUI

struct CheckoutView: View {
    var onFinished: () -> Void = {}

    @EnvironmentObject private var cart: CartStore
    @EnvironmentObject private var orders: OrderHistoryStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("loyaltyName")  private var savedName = ""
    @AppStorage("loyaltyPhone") private var savedPhone = ""
    @AppStorage("loyaltyEmail") private var savedEmail = ""
    @AppStorage("defaultTipPct") private var defaultTip = 15

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @FocusState private var focused: Bool

    // Tip — 10% / 15% / 20% / Custom ($); nil = no tip
    private enum TipChoice: Equatable { case percent(Int); case custom }
    @State private var selectedTip: TipChoice?
    @State private var customTipCents = 0
    @State private var customTipText = ""
    @State private var showCustomTipSheet = false
    @State private var tipPrefilled = false

    // Pickup — ASAP or dual wheels over server slots
    private enum PickupMode: Hashable { case asap, scheduled }
    @State private var pickupMode: PickupMode = .asap
    @State private var shiftIndex = 0
    @State private var slotIndex = 0
    @State private var shifts: [Shift] = []
    @State private var hours: HoursStatus?

    // Stable across retries so a re-tap after a lost response can't double-charge.
    @State private var idempotencyKey = UUID().uuidString
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
            Section("Your info") {
                TextField("Name", text: $name)
                    .textContentType(.name).focused($focused)
                TextField("Phone", text: $phone)
                    .textContentType(.telephoneNumber).keyboardType(.phonePad).focused($focused)
                TextField("Email (optional, for receipt)", text: $email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).focused($focused)
            }
            .listRowBackground(Paper.panel)

            pickupSection
            tipSection

            Section("Order") {
                summaryRow("Subtotal", cart.subtotalCents)
                summaryRow("Tax (7%)", cart.taxCents)
                summaryRow("Service fee (3%)", cart.feeCents)
                if tipCents > 0 { summaryRow("Tip", tipCents) }
                HStack {
                    Text("Total").font(.system(.body, design: .default).weight(.bold))
                    Spacer()
                    Text(dollars(chargeCents)).font(.price(18)).foregroundStyle(Paper.red)
                }
            }
            .listRowBackground(Paper.panel)

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Paper.red).font(.subheadline)
                }
                .listRowBackground(Paper.panel)
            }
        }
        .scrollContentBackground(.hidden)
        .paperGround()
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Paper.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer(); Button("Done") { focused = false }.tint(Paper.red)
            }
        }
        .safeAreaInset(edge: .bottom) { payBar }
        .task { await loadOptions() }
        .navigationDestination(item: $confirmation) { conf in
            OrderConfirmationView(confirmation: conf) { onFinished() }
        }
        .sheet(isPresented: $showCustomTipSheet) { customTipSheet }
        .sensoryFeedback(.selection, trigger: selectedTip)
    }

    // MARK: - Pay bar

    private var payBar: some View {
        Button { Task { await submit() } } label: {
            HStack {
                if submitting { ProgressView().tint(.white).padding(.trailing, 4) }
                Text(submitting ? "Placing order…" : "Place order")
                Spacer()
                Text(dollars(chargeCents)).font(.price(17))
            }
        }
        .buttonStyle(SignButtonStyle(enabled: formValid && !submitting))
        .disabled(!formValid || submitting)
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 8)
        .background(Paper.bg)
        .overlay(alignment: .top) { Rule() }
    }

    // MARK: - Pickup time

    @ViewBuilder
    private var pickupSection: some View {
        Section("Pickup time") {
            if hours?.orderingOpen == true {
                Picker("Pickup mode", selection: $pickupMode) {
                    Text("ASAP").tag(PickupMode.asap)
                    Text("Schedule").tag(PickupMode.scheduled)
                }
                .pickerStyle(.segmented)
            } else if let msg = hours?.message {
                Label(msg, systemImage: "clock.badge.exclamationmark")
                    .font(.caption).foregroundStyle(Paper.red)
            }

            if pickupMode == .scheduled || hours?.orderingOpen != true {
                if shifts.isEmpty {
                    Text("No order-ahead times available right now.")
                        .font(.subheadline).foregroundStyle(Paper.inkSoft)
                } else {
                    HStack(spacing: 0) {
                        Picker("Day", selection: $shiftIndex) {
                            ForEach(Array(shifts.enumerated()), id: \.offset) { i, shift in
                                Text(shift.label).tag(i)
                            }
                        }
                        .pickerStyle(.wheel).frame(maxWidth: .infinity).clipped()

                        Picker("Time", selection: $slotIndex) {
                            let slots = shifts.indices.contains(shiftIndex) ? shifts[shiftIndex].slots : []
                            ForEach(Array(slots.enumerated()), id: \.offset) { i, slot in
                                Text(slotTimeLabel(slot)).tag(i)
                            }
                        }
                        .pickerStyle(.wheel).frame(maxWidth: .infinity).clipped()
                    }
                    .frame(height: 130)
                    .onChange(of: shiftIndex) { _, _ in slotIndex = 0 }

                    if shifts.indices.contains(shiftIndex), let loc = shifts[shiftIndex].location {
                        Label(loc.display, systemImage: "mappin.and.ellipse")
                            .font(.caption).foregroundStyle(Paper.inkSoft)
                    }
                }
            }
        }
        .listRowBackground(Paper.panel)
    }

    // MARK: - Tip

    @ViewBuilder
    private var tipSection: some View {
        Section("Tip") {
            VStack(spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach([10, 15, 20], id: \.self) { p in
                        tipTile(selected: selectedTip == .percent(p)) {
                            VStack(spacing: 2) {
                                Text("\(p)%").font(.system(.title3, design: .default).weight(.heavy))
                                Text(dollars(Int((Double(cart.subtotalCents) * Double(p) / 100).rounded())))
                                    .font(.price(12)).opacity(0.85)
                            }
                        } action: {
                            selectedTip = (selectedTip == .percent(p)) ? nil : .percent(p)
                        }
                    }
                    tipTile(selected: selectedTip == .custom) {
                        VStack(spacing: 2) {
                            if selectedTip == .custom && customTipCents > 0 {
                                Text(dollars(customTipCents)).font(.price(16))
                                Text("Custom").font(.caption)
                            } else {
                                Text("Custom").font(.system(.headline, design: .default).weight(.semibold))
                            }
                        }
                    } action: {
                        customTipText = customTipCents > 0
                            ? String(format: "%.2f", Double(customTipCents) / 100) : ""
                        showCustomTipSheet = true
                    }
                }
                Button("No tip") { selectedTip = nil }
                    .font(.footnote).foregroundStyle(Paper.inkSoft)
                    .buttonStyle(.borderless).opacity(selectedTip == nil ? 0.45 : 1)
            }
            .padding(.vertical, 4)
            .listRowBackground(Paper.bg)
        }
        .listRowBackground(Paper.panel)
    }

    private func tipTile<Content: View>(selected: Bool,
                                        @ViewBuilder content: () -> Content,
                                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            content()
                .frame(maxWidth: .infinity).frame(height: 66)
                .foregroundStyle(selected ? Color.white : Paper.red)
                .background(selected ? Paper.red : Paper.bg)
                .overlay(Rectangle().stroke(Paper.red.opacity(selected ? 0 : 0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var customTipSheet: some View {
        VStack(spacing: 20) {
            Capsule().fill(Paper.line).frame(width: 36, height: 5).padding(.top, 10)
            Text("Custom tip").font(.headline).foregroundStyle(Paper.ink)
            HStack(spacing: 6) {
                Text("$").font(.system(size: 34, weight: .semibold)).foregroundStyle(Paper.inkSoft)
                TextField("0.00", text: $customTipText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 40, weight: .bold).monospacedDigit())
                    .focused($focused)
            }
            .padding(.horizontal, 40)
            Button("Set tip") {
                let normalized = customTipText.replacingOccurrences(of: ",", with: ".")
                let cents = Int(((Double(normalized) ?? 0) * 100).rounded())
                customTipCents = min(max(cents, 0), 100_000)   // server caps at $1,000
                selectedTip = customTipCents > 0 ? .custom : nil
                showCustomTipSheet = false
            }
            .buttonStyle(SignButtonStyle()).padding(.horizontal, 20)
            Button("Cancel") { showCustomTipSheet = false }
                .font(.subheadline).foregroundStyle(Paper.inkSoft)
            Spacer(minLength: 0)
        }
        .background(Paper.bg.ignoresSafeArea())
        .presentationDetents([.medium])
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer(); Button("Done") { focused = false }.tint(Paper.red)
            }
        }
    }

    // MARK: - Summary

    private func summaryRow(_ label: String, _ cents: Int) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(Paper.inkSoft)
            Spacer()
            Text(dollars(cents)).font(.price(14)).foregroundStyle(Paper.ink)
        }
    }

    // MARK: - Data

    private func loadOptions() async {
        if name.isEmpty { name = savedName }
        if phone.isEmpty { phone = savedPhone }
        if email.isEmpty { email = savedEmail }
        // Honour the Settings default-tip once, on first load.
        if !tipPrefilled {
            tipPrefilled = true
            if [10, 15, 20].contains(defaultTip) {
                selectedTip = .percent(defaultTip)          // matches a tip tile
            } else if defaultTip > 0 {
                // 18% / 25% have no tile — honor them as a prefilled custom amount.
                customTipCents = Int((Double(cart.subtotalCents) * Double(defaultTip) / 100).rounded())
                selectedTip = .custom
            }
        }

        hours = try? await APIClient.shared.hours()
        shifts = (try? await APIClient.shared.scheduleSlots())?.shifts ?? []
        if hours?.orderingOpen != true { pickupMode = .scheduled }
    }

    private func submit() async {
        submitting = true
        defer { submitting = false }
        errorMessage = nil
        do {
            let config = try await APIClient.shared.config()
            let payment = PaymentServiceFactory.make(config: config)
            let sourceId = try await payment.tokenizeCard()

            let req = CheckoutRequest(
                items: cart.checkoutItems,
                customer: CheckoutCustomer(
                    name: name.trimmingCharacters(in: .whitespaces),
                    phone: phone.filter(\.isNumber),
                    email: email.isEmpty ? nil : email
                ),
                sourceId: sourceId,
                idempotencyKey: idempotencyKey,     // stable across retries
                tipCents: tipCents > 0 ? tipCents : nil,
                scheduledPickupAt: pickupMode == .scheduled ? selectedSlot : nil
            )
            let resp = try await APIClient.shared.checkout(req)
            let lines = cart.lines.map {
                OrderLine(itemId: $0.item.id, name: $0.item.name,
                          option: $0.option, customizations: $0.customizations,
                          addOnCents: $0.addOnCents, quantity: $0.quantity)
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
