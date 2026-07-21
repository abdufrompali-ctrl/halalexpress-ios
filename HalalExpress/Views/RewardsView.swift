import SwiftUI

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
    @FocusState private var focused: Field?

    // `fileprivate` (not `private`) so the file-level InputRow struct can reference it.
    fileprivate enum Field: Hashable { case name, phone, email }
    private var isMember: Bool { !savedPhone.isEmpty }
    private var firstName: String? {
        savedName.split(separator: " ").first.map(String.init)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                ScrollView {
                    VStack(spacing: 0) {
                        if isMember { memberHero } else { guestHero }
                        perksRow
                        if isMember {
                            memberDeals
                            orderHistory
                            signOutButton
                        } else {
                            signUpForm
                        }
                    }
                    .padding(.bottom, 40)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Rewards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Brand.red, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Heroes

    private var guestHero: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Brand.ember, Brand.red, Color(hex: 0x6B0808)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 10) {
                Text("Deals. Drops.\nFirst Dibs.")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineSpacing(2)
                Text("Join free — get exclusive coupons,\nweekly truck spots, and member-only deals by text.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 56)
        }
        .clipShape(DiagonalSlash(rise: 50))
    }

    private var memberHero: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Brand.gold, Color(hex: 0xC8922A), Color(hex: 0x7A5510)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("MEMBER")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .kerning(1.5)
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(.black.opacity(0.2), in: Capsule())

                Text("Welcome back,\n\(firstName ?? savedName).")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 56)
        }
        .clipShape(DiagonalSlash(rise: 50))
    }

    // MARK: - Perks row

    private var perksRow: some View {
        HStack(spacing: 12) {
            PerkChip(icon: "tag.fill",        label: "Coupons",       locked: !isMember)
            PerkChip(icon: "mappin.circle.fill", label: "Truck Spots", locked: !isMember)
            PerkChip(icon: "bolt.fill",        label: "First Dibs",   locked: !isMember)
        }
        .padding(.horizontal, 20)
        .padding(.top, -22)
        .padding(.bottom, 20)
    }

    // MARK: - Member: deal cards

    private var memberDeals: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your Deals")

            DealCard(
                icon: "tag.fill",
                label: "10% Off Your Next Order",
                detail: "Use at checkout — valid this week",
                color: Brand.ember
            )
            DealCard(
                icon: "mappin.circle.fill",
                label: "Truck Spot Dropped",
                detail: "Check your texts every Monday",
                color: Brand.red
            )
            DealCard(
                icon: "star.fill",
                label: "Member-Only Special",
                detail: "Watch your texts for this week's drop",
                color: Brand.gold
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Member: order history

    private var orderHistory: some View {
        Group {
            if !orders.orders.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Order History")
                    ForEach(orders.orders.prefix(8)) { order in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(order.summary)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(order.date, format: .dateTime.month().day().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                            Spacer()
                            Text(dollars(order.totalCents))
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(Brand.emberSoft)
                        }
                        .padding(14)
                        .glassCard(cornerRadius: 14)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private var signOutButton: some View {
        Button(role: .destructive) {
            savedPhone = ""; savedName = ""; savedEmail = ""
        } label: {
            Text("Sign out")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.bottom, 8)
    }

    // MARK: - Guest: sign-up form

    private var signUpForm: some View {
        VStack(spacing: 16) {
            // FOMO deal previews
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Member Deals — Unlock Free")

                LockedDealCard(icon: "tag.fill",          label: "Exclusive Coupons",       sub: "Members-only discounts every week")
                LockedDealCard(icon: "mappin.circle.fill", label: "Weekly Truck Spots",       sub: "Know where we are before anyone else")
                LockedDealCard(icon: "bolt.fill",          label: "First-Dibs Specials",      sub: "Flash deals texted straight to you")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)

            // Form
            VStack(spacing: 0) {
                SectionHeader(title: "Join Free — Takes 10 Seconds")
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                VStack(spacing: 1) {
                    InputRow(placeholder: "Your name", text: $name, keyboard: .default, field: .name, focused: $focused)
                    InputRow(placeholder: "Phone number", text: $phone, keyboard: .phonePad, field: .phone, focused: $focused)
                    InputRow(placeholder: "Email (optional)", text: $email, keyboard: .emailAddress, field: .email, focused: $focused, isLast: true)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)

                if let errorMsg {
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundStyle(Brand.emberSoft)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

                Button {
                    focused = nil
                    Task { await join() }
                } label: {
                    HStack(spacing: 8) {
                        if busy { ProgressView().tint(.white).scaleEffect(0.8) }
                        Text(busy ? "Joining..." : "Join & Unlock Deals")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        phoneValid ? LinearGradient.brand : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: phoneValid ? Brand.red.opacity(0.4) : .clear, radius: 12, y: 6)
                }
                .disabled(busy || !phoneValid)
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Text("No spam. Just truck spots and deals. Unsubscribe anytime.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.25))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 10)
            }
        }
    }

    private var phoneValid: Bool { phone.filter(\.isNumber).count >= 10 }

    private func join() async {
        busy = true
        defer { busy = false }
        errorMsg = nil
        do {
            let digits = phone.filter(\.isNumber)
            _ = try await APIClient.shared.loyaltyJoin(
                name: name, phone: digits, email: email.isEmpty ? nil : email)
            savedPhone = digits
            savedName  = name.isEmpty ? "Guest" : name
            savedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}

// MARK: - Sub-components

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.heavy))
            .foregroundStyle(.white.opacity(0.4))
            .kerning(1.2)
    }
}

private struct PerkChip: View {
    let icon: String
    let label: String
    let locked: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(locked ? Color.white.opacity(0.05) : Brand.red.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: locked ? "lock.fill" : icon)
                    .font(.system(size: 18))
                    .foregroundStyle(locked ? .white.opacity(0.2) : Brand.ember)
            }
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(locked ? .white.opacity(0.25) : .white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 14)
    }
}

private struct DealCard: View {
    let icon: String
    let label: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
    }
}

private struct LockedDealCard: View {
    let icon: String
    let label: String
    let sub: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Brand.red.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Brand.ember.opacity(0.4))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
                Text(sub)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.25))
            }
            Spacer()
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.15))
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Brand.red.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct InputRow: View {
    let placeholder: String
    @Binding var text: String
    let keyboard: UIKeyboardType
    let field: RewardsView.Field
    @FocusState.Binding var focused: RewardsView.Field?
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled()
                .focused($focused, equals: field)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(hex: 0x222020))
                .submitLabel(isLast ? .done : .next)
                .onSubmit { focused = isLast ? nil : nextField }
            if !isLast {
                Divider().background(Color.white.opacity(0.06))
            }
        }
    }

    private var nextField: RewardsView.Field? {
        switch field {
        case .name:  return .phone
        case .phone: return .email
        case .email: return nil
        }
    }
}
