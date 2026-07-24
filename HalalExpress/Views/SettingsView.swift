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
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            yourInfo
                            theTruck
                            orderDefaults
                            spreadTheWord
                            help
                            about
                            legal
                            if signedIn { leaveList }
                        }
                        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 40)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .tint(Paper.red)
        }
    }

    // MARK: - Sections

    private var yourInfo: some View {
        section("Your info") {
            if signedIn {
                infoRow("Name", name.isEmpty ? "—" : name)
                divider
                infoRow("Phone", phone)
                if !email.isEmpty { divider; infoRow("Email", email) }
            } else {
                Text("Not on the list. Join from the Updates tab to save your info.")
                    .font(.subheadline).foregroundStyle(Paper.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
        }
    }

    private var theTruck: some View {
        section("The truck") {
            NavigationLink { LocationsView() } label: {
                navRow("Hours & locations")
            }
            .buttonStyle(.plain)
        }
    }

    private var orderDefaults: some View {
        section("Order defaults") {
            HStack {
                Text("Default tip").foregroundStyle(Paper.ink)
                Spacer()
                Picker("", selection: $defaultTip) {
                    ForEach([10, 15, 18, 20, 25], id: \.self) { Text("\($0)%").tag($0) }
                }
                .labelsHidden().tint(Paper.red)
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
        }
    }

    private var spreadTheWord: some View {
        section("Spread the word") {
            ShareLink(item: shareURL) {
                rowContent("Tell a friend", trailingSystemImage: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
        }
    }

    private var help: some View {
        section("Help") {
            linkRow("Help & FAQ", "https://halalexpressnc.com")
        }
    }

    private var about: some View {
        section("About") {
            infoRow("Version", version)
            divider
            infoRow("Location", "Wilmington, NC")
            divider
            linkRow("halalexpressnc.com", "https://halalexpressnc.com")
        }
    }

    private var legal: some View {
        section("Legal") {
            linkRow("Privacy Policy", "https://halalexpressnc.com/privacy")
            divider
            linkRow("Terms of Service", "https://halalexpressnc.com/terms")
        }
    }

    private var leaveList: some View {
        Button { signOut() } label: {
            Text("Leave the text list")
                .font(.subheadline).foregroundStyle(Paper.inkFaint)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Building blocks

    private var divider: some View { Rule().padding(.leading, 14) }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(.caption, design: .default).weight(.heavy)).tracking(1)
                .foregroundStyle(Paper.inkFaint)
            VStack(spacing: 0) { content() }.paperBox()
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Paper.ink)
            Spacer()
            Text(value).foregroundStyle(Paper.inkSoft)
        }
        .padding(14)
    }

    private func navRow(_ title: String) -> some View {
        rowContent(title, trailingSystemImage: "chevron.right")
    }

    private func linkRow(_ title: String, _ url: String) -> some View {
        Link(destination: URL(string: url) ?? shareURL) {
            rowContent(title, trailingSystemImage: "arrow.up.right")
        }
        .buttonStyle(.plain)
    }

    private func rowContent(_ title: String, trailingSystemImage: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Paper.ink)
            Spacer()
            Image(systemName: trailingSystemImage).font(.caption).foregroundStyle(Paper.inkFaint)
        }
        .padding(14)
        .contentShape(Rectangle())
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }

    private func signOut() { name = ""; phone = ""; email = "" }
}
