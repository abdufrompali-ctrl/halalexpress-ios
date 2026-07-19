import SwiftUI

struct RewardsView: View {
    @AppStorage("loyaltyPhone") private var savedPhone = ""
    @AppStorage("loyaltyName") private var savedName = ""

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
                                .foregroundStyle(.orange)
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

                    Section {
                        Button("Not you? Sign out", role: .destructive) {
                            savedPhone = ""; savedName = ""
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
                                if busy { ProgressView().padding(.trailing, 4) }
                                Text("Join Free").frame(maxWidth: .infinity).fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(.borderedProminent)
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
        } catch {
            message = error.localizedDescription
        }
    }
}
