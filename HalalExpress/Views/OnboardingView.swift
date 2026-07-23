import SwiftUI

/// First-open welcome. Offers the text list, but never blocks the door — "Skip
/// and start ordering" is right there. Paper, like the rest of the app.
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
    @FocusState private var focused: Bool

    private var phoneValid: Bool { phone.filter(\.isNumber).count >= 10 }

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("HALAL").font(.board(64)).foregroundStyle(Paper.ink)
                    Text("EXPRESS").font(.board(64)).foregroundStyle(Paper.red)
                    Rectangle().fill(Paper.red).frame(width: 120, height: 4).padding(.top, 10)

                    Text("Halal food truck · Wilmington, NC")
                        .font(.subheadline).foregroundStyle(Paper.inkSoft)
                        .padding(.top, 14)

                    Text("Join our text list for locations and specials — or skip and go straight to the menu.")
                        .font(.body).foregroundStyle(Paper.ink)
                        .padding(.top, 24)

                    VStack(spacing: 0) {
                        Rule()
                        field("Name", text: $name, keyboard: .default, content: .name)
                        Rule()
                        field("Phone", text: $phone, keyboard: .phonePad, content: .telephoneNumber)
                        Rule()
                    }
                    .padding(.top, 20)

                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(Paper.red).padding(.top, 10)
                    }

                    Button {
                        focused = false
                        Task { await join() }
                    } label: {
                        HStack(spacing: 8) {
                            if busy { ProgressView().tint(.white).scaleEffect(0.8) }
                            Text(busy ? "Joining…" : "Join the list")
                        }
                    }
                    .buttonStyle(SignButtonStyle(enabled: phoneValid && !busy))
                    .disabled(!phoneValid || busy)
                    .padding(.top, 20)

                    Button("Skip and start ordering") { finish() }
                        .font(.system(.subheadline, design: .default).weight(.semibold))
                        .foregroundStyle(Paper.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 28).padding(.top, 60).padding(.bottom, 32)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer(); Button("Done") { focused = false }.tint(Paper.red)
            }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>,
                       keyboard: UIKeyboardType, content: UITextContentType) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .textContentType(content)
            .textInputAutocapitalization(.words)
            .focused($focused)
            .font(.body).foregroundStyle(Paper.ink)
            .padding(.horizontal, 2).padding(.vertical, 14)
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
