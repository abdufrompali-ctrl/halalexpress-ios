import SwiftUI

struct SettingsView: View {
    @AppStorage("loyaltyName")  private var name = ""
    @AppStorage("loyaltyPhone") private var phone = ""
    @AppStorage("loyaltyEmail") private var email = ""
    @AppStorage("defaultTipPct") private var defaultTip = 15

    private var signedIn: Bool { !phone.isEmpty }
    private let shareURL = URL(string: "https://halalexpressnc.com")!

    var body: some View {
        NavigationStack {
            ZStack {
                PaperGroundLayer()
                VStack(spacing: 0) {
                    BoardHeader(eyebrow: "HALAL EXPRESS", title: "ACCOUNT")
                    List {
                        Section("Your info") {
                        if signedIn {
                            infoRow("Name", name.isEmpty ? "—" : name)
                            infoRow("Phone", phone)
                            if !email.isEmpty { infoRow("Email", email) }
                        } else {
                            Text("Not on the list. Join from the Updates tab to save your info.")
                                .font(.subheadline).foregroundStyle(Paper.inkSoft)
                        }
                    }
                    .listRowBackground(Paper.panel)

                    Section("The truck") {
                        NavigationLink {
                            LocationsView()
                        } label: {
                            Text("Hours & locations").foregroundStyle(Paper.ink)
                        }
                    }
                    .listRowBackground(Paper.panel)

                    Section("Order defaults") {
                        Picker(selection: $defaultTip) {
                            ForEach([10, 15, 18, 20, 25], id: \.self) { Text("\($0)%").tag($0) }
                        } label: {
                            Text("Default tip")
                        }
                        .tint(Paper.red)
                    }
                    .listRowBackground(Paper.panel)

                    Section("Spread the word") {
                        ShareLink(item: shareURL) {
                            HStack {
                                Text("Tell a friend").foregroundStyle(Paper.ink)
                                Spacer()
                                Image(systemName: "square.and.arrow.up").font(.subheadline)
                                    .foregroundStyle(Paper.inkFaint)
                            }
                        }
                    }
                    .listRowBackground(Paper.panel)

                    Section("Help") {
                        linkRow("Help & FAQ", "https://halalexpressnc.com")
                    }
                    .listRowBackground(Paper.panel)

                    Section("About") {
                        infoRow("Version", version)
                        infoRow("Location", "Wilmington, NC")
                        linkRow("halalexpressnc.com", "https://halalexpressnc.com")
                    }
                    .listRowBackground(Paper.panel)

                    Section("Legal") {
                        linkRow("Privacy Policy", "https://halalexpressnc.com/privacy")
                        linkRow("Terms of Service", "https://halalexpressnc.com/terms")
                    }
                    .listRowBackground(Paper.panel)

                    // Unsubscribe-style, tucked at the very bottom.
                    if signedIn {
                        Section {
                            Button { signOut() } label: {
                                Text("Leave the text list")
                                    .font(.caption).foregroundStyle(Paper.inkFaint)
                                    .frame(maxWidth: .infinity)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(Paper.ink)
                    .tint(Paper.red)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Paper.ink)
            Spacer()
            Text(value).foregroundStyle(Paper.inkSoft)
        }
    }

    private func linkRow(_ title: String, _ url: String) -> some View {
        Link(destination: URL(string: url) ?? URL(string: "https://halalexpressnc.com")!) {
            HStack {
                Text(title).foregroundStyle(Paper.ink)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(Paper.inkFaint)
            }
        }
    }

    private func signOut() { name = ""; phone = ""; email = "" }
}
