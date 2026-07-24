import SwiftUI

/// Updates — an honest text-list sign-up (no points, no fake coupons) and the
/// customer's own order history. Members see where the truck's headed and get a
/// heads-up on specials; that's the whole deal, stated plainly.
struct RewardsView: View {
    @EnvironmentObject private var orders: OrderHistoryStore
    @AppStorage("loyaltyPhone") private var savedPhone = ""
    @AppStorage("loyaltyName")  private var savedName  = ""
    @AppStorage("loyaltyEmail") private var savedEmail = ""

    @State private var name  = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var busy  = false
    @State private var errorMsg: String?
    @FocusState private var focused: Bool

    private var isMember: Bool { !savedPhone.isEmpty }
    private var firstName: String? { savedName.split(separator: " ").first.map(String.init) }
    private var phoneValid: Bool { phone.filter(\.isNumber).count >= 10 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    BoardHeader(eyebrow: "HALAL EXPRESS", title: "UPDATES")
                    VStack(alignment: .leading, spacing: 20) {
                        Text(isMember ? "You're on the list" : "Get truck updates")
                            .font(.board(30)).foregroundStyle(Paper.ink)
                        if isMember { memberBody } else { signUp }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .paperGround()
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer(); Button("Done") { focused = false }.tint(Paper.red)
                }
            }
        }
    }

    // MARK: - Member

    private var memberBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(firstName.map { "Thanks, \($0)." } ?? "You're all set.")
                    .font(.system(.body, design: .default).weight(.semibold))
                    .foregroundStyle(Paper.ink)
                Text("We'll text you when the truck is heading somewhere new and when there's a special. That's it.")
                    .font(.subheadline).foregroundStyle(Paper.inkSoft)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).paperBox()

            if !orders.orders.isEmpty { orderHistory }

            Button("Leave the list") {
                savedPhone = ""; savedName = ""; savedEmail = ""
            }
            .font(.subheadline).foregroundStyle(Paper.inkFaint)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var orderHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR ORDERS")
                .font(.system(.caption, design: .default).weight(.heavy)).tracking(1)
                .foregroundStyle(Paper.inkFaint)
            VStack(spacing: 0) {
                Rule()
                ForEach(orders.orders.prefix(10)) { order in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(order.summary)
                                .font(.subheadline).foregroundStyle(Paper.ink).lineLimit(1)
                            Text(order.date, format: .dateTime.month().day().hour().minute())
                                .font(.caption).foregroundStyle(Paper.inkFaint)
                        }
                        Spacer()
                        Text(dollars(order.totalCents)).font(.price(14)).foregroundStyle(Paper.ink)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    Rule()
                }
            }
            .paperBox()
        }
    }

    // MARK: - Sign up

    private var signUp: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Join our text list and you'll be the first to know where we're parked and when we're running a special. No points, no spam — just the truck.")
                .font(.subheadline).foregroundStyle(Paper.inkSoft)

            VStack(spacing: 0) {
                Rule()
                field("Name", text: $name, keyboard: .default, content: .name)
                Rule()
                field("Phone", text: $phone, keyboard: .phonePad, content: .telephoneNumber)
                Rule()
                field("Email (optional)", text: $email, keyboard: .emailAddress, content: .emailAddress)
                Rule()
            }

            if let errorMsg {
                Label(errorMsg, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(Paper.red)
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
            .disabled(busy || !phoneValid)

            Text("Standard message rates apply. Reply STOP any time to leave the list.")
                .font(.caption2).foregroundStyle(Paper.inkFaint)
        }
    }

    private func field(_ placeholder: String, text: Binding<String>,
                       keyboard: UIKeyboardType, content: UITextContentType) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .textContentType(content)
            .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
            .autocorrectionDisabled(keyboard != .default)
            .focused($focused)
            .font(.body).foregroundStyle(Paper.ink)
            .padding(.horizontal, 14).padding(.vertical, 14)
    }

    private func join() async {
        busy = true
        defer { busy = false }
        errorMsg = nil
        do {
            let digits = phone.filter(\.isNumber)
            _ = try await APIClient.shared.loyaltyJoin(
                name: name, phone: digits, email: email.isEmpty ? nil : email)
            savedPhone = digits
            savedName  = name.trimmingCharacters(in: .whitespaces)
            savedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
