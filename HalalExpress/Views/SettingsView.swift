import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var cart: CartStore
    @EnvironmentObject private var orders: OrderHistoryStore
    @AppStorage("loyaltyName")  private var name = ""
    @AppStorage("loyaltyPhone") private var phone = ""
    @AppStorage("loyaltyEmail") private var email = ""
    @AppStorage("notifyDeals")  private var notifyDeals = true
    @AppStorage("defaultTipPct") private var defaultTip = 15
    @State private var showDelete = false

    private var signedIn: Bool { !phone.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground(animated: false)
                List {
                    Text("Settings").font(.display(46)).foregroundStyle(.white)
                        .padding(.top, 8).padding(.bottom, 2)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)

                    Section("Account") {
                        if signedIn {
                            infoRow("person.fill", "Name", name.isEmpty ? "—" : name)
                            infoRow("phone.fill", "Phone", phone)
                            if !email.isEmpty { infoRow("envelope.fill", "Email", email) }
                            Button { signOut() } label: {
                                rowLabel("rectangle.portrait.and.arrow.right", "Sign out", tint: Brand.emberSoft)
                            }
                        } else {
                            Text("Not signed in. Join Rewards to save your info.")
                                .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .listRowBackground(Brand.warmCard)

                    Section("Notifications") {
                        Toggle(isOn: $notifyDeals) {
                            rowLabel("bell.fill", "Deals & truck-spot texts")
                        }.tint(Brand.ember)
                    }
                    .listRowBackground(Brand.warmCard)

                    Section("Order defaults") {
                        Picker(selection: $defaultTip) {
                            ForEach([0, 10, 15, 18, 20, 25], id: \.self) { Text("\($0)%").tag($0) }
                        } label: {
                            rowLabel("percent", "Default tip")
                        }
                        .pickerStyle(.menu).tint(Brand.emberSoft)
                    }
                    .listRowBackground(Brand.warmCard)

                    Section("Support") {
                        linkRow("envelope.fill", "Message us", "mailto:contact@halalexpressnc.com")
                        linkRow("questionmark.circle.fill", "Help & FAQ", "https://halalexpressnc.com")
                    }
                    .listRowBackground(Brand.warmCard)

                    Section("About") {
                        infoRow("info.circle.fill", "Version", version)
                        linkRow("globe", "halalexpressnc.com", "https://halalexpressnc.com")
                        infoRow("mappin.circle.fill", "Made in", "Winston-Salem, NC")
                    }
                    .listRowBackground(Brand.warmCard)

                    Section("Legal") {
                        linkRow("hand.raised.fill", "Privacy Policy", "https://halalexpressnc.com/privacy")
                        linkRow("doc.text.fill", "Terms of Service", "https://halalexpressnc.com/terms")
                    }
                    .listRowBackground(Brand.warmCard)

                    Section {
                        Button(role: .destructive) { showDelete = true } label: {
                            rowLabel("trash.fill", "Delete account", tint: Brand.red)
                        }
                    }
                    .listRowBackground(Brand.warmCard)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
            }
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog("Delete your account?", isPresented: $showDelete, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) { deleteAccount() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes your saved info and order history from this device.")
            }
        }
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }

    private func rowLabel(_ icon: String, _ title: String, tint: Color = .white) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon).font(.system(size: 15))
                .foregroundStyle(tint == .white ? Brand.emberSoft : tint).frame(width: 24)
            Text(title).foregroundStyle(tint)
        }
    }

    private func infoRow(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Brand.emberSoft).frame(width: 24)
            Text(title).foregroundStyle(.white)
            Spacer()
            Text(value).foregroundStyle(.white.opacity(0.45))
        }
    }

    private func linkRow(_ icon: String, _ title: String, _ url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 13) {
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Brand.emberSoft).frame(width: 24)
                Text(title).foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    private func signOut() { name = ""; phone = ""; email = "" }

    private func deleteAccount() {
        name = ""; phone = ""; email = ""
        orders.clear()
        cart.clear()
    }
}
