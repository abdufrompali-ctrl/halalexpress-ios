import SwiftUI

struct RewardsView: View {
    @EnvironmentObject private var orders: OrderHistoryStore
    @AppStorage("loyaltyPhone") private var savedPhone = ""
    @AppStorage("loyaltyName") private var savedName = ""
    @AppStorage("loyaltyEmail") private var savedEmail = ""

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var busy = false
    @State private var message: String?

    private var isMember: Bool { !savedPhone.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                if isMember {
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Brand.gold)
                            Text("You're on the list, \(savedName.split(separator: " ").first.map(String.init) ?? savedName)!")
                                .font(.headline)
                            Text("We'll text you the truck location every week plus exclusive deals.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.clear)

                    if !orders.orders.isEmpty {
                        Section("Recent Orders") {
                            ForEach(orders.orders.prefix(10)) { order in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(order.date, format: .dateTime.month().day().hour().minute())
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text(dollars(order.totalCents))
                                            .font(.subheadline.monospacedDigit())
                                            .foregroundStyle(Brand.red)
                                    }
                                    Text(order.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    Section {
                        Button("Not you? Sign out", role: .destructive) {
                            savedPhone = ""; savedName = ""; savedEmail = ""
                        }
                    }
                } else {
                    Section("Join Halal Express Rewards") {
                        TextField("Name", text: $name)
                        TextField("Phone", text: $phone)
                            .keyboardType(.phonePad)
                        TextField("Email (optional)", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }

                    if let message {
                        Section { Text(message).foregroundStyle(.red) }
                    }

                    Section {
                        Button {
                            Task { await join() }
                        } label: {
                            HStack {
                                if busy { ProgressView().tint(.white).padding(.trailing, 4) }
                                Text("Join Free")
                            }
                        }
                        .buttonStyle(BrandButtonStyle(enabled: !busy && phone.filter(\.isNumber).count >= 10))
                        .disabled(busy || phone.filter(\.isNumber).count < 10)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Rewards")
        }
    }

    private func join() async {
        busy = true
        defer { busy = false }
        message = nil
        do {
            let digits = phone.filter(\.isNumber)
            _ = try await APIClient.shared.loyaltyJoin(
                name: name, phone: digits, email: email.isEmpty ? nil : email)
            savedPhone = digits
            savedName = name.isEmpty ? "Guest" : name
            savedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        } catch {
            message = error.localizedDescription
        }
    }
}
