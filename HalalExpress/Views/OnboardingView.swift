import SwiftUI

/// First-open sign-up: captures name/phone/email, joins Rewards, or skips.
struct OnboardingView: View {
    var onDone: () -> Void

    @AppStorage("loyaltyName")  private var savedName = ""
    @AppStorage("loyaltyPhone") private var savedPhone = ""
    @AppStorage("loyaltyEmail") private var savedEmail = ""
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var busy = false
    @State private var error: String?

    private var canJoin: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && phone.filter(\.isNumber).count >= 10
    }

    var body: some View {
        ZStack {
            LinearGradient.brand.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 62))
                            .foregroundStyle(.white)
                        Text("Join Halal Express Rewards")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text("Truck locations, exclusive deals, and one-tap reorders — free.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 44)

                    VStack(spacing: 14) {
                        field("Name", text: $name, icon: "person.fill")
                        field("Phone", text: $phone, icon: "phone.fill", keyboard: .phonePad)
                        field("Email (optional)", text: $email, icon: "envelope.fill",
                              keyboard: .emailAddress, lowercase: true)

                        if let error {
                            Text(error).font(.caption).foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task { await join() }
                        } label: {
                            HStack {
                                if busy { ProgressView().tint(.white) }
                                Text("Join Free")
                            }
                        }
                        .buttonStyle(BrandButtonStyle(enabled: canJoin && !busy))
                        .disabled(!canJoin || busy)
                    }
                    .padding(18)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))

                    Button("Skip for now") { finish() }
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.bottom, 20)
                }
                .padding(.horizontal)
            }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, icon: String,
                       keyboard: UIKeyboardType = .default, lowercase: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Brand.red).frame(width: 22)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(lowercase ? .never : .words)
                .autocorrectionDisabled(lowercase)
                .foregroundStyle(.black)
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
    }

    private func join() async {
        busy = true
        defer { busy = false }
        error = nil
        do {
            let digits = phone.filter(\.isNumber)
            _ = try await APIClient.shared.loyaltyJoin(
                name: name, phone: digits, email: email.isEmpty ? nil : email)
            savedName = name.trimmingCharacters(in: .whitespaces)
            savedPhone = digits
            savedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
            finish()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func finish() {
        onboardingComplete = true
        onDone()
    }
}
