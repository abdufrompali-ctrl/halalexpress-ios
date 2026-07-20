import SwiftUI

struct MenuView: View {
    @State private var catalog: Catalog?
    @State private var hours: HoursStatus?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if let catalog {
                    menuList(catalog)
                } else if let error {
                    ContentUnavailableView {
                        Label("Menu unavailable", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                            .tint(Brand.red)
                    }
                } else {
                    ProgressView("Loading menu…")
                        .controlSize(.large)
                        .tint(Brand.red)
                }
            }
            .navigationTitle("Halal Express")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @ViewBuilder
    private func menuList(_ catalog: Catalog) -> some View {
        List {
            Section {
                BrandHeader()
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                HoursBanner(hours: hours)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            ForEach(catalog.categories, id: \.self) { category in
                let items = catalog.items.filter { $0.category == category }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                MenuRow(item: item)
                            }
                        }
                    } header: {
                        Label(category, systemImage: Brand.icon(for: category))
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(Brand.red)
                            .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: CatalogItem.self) { item in
            ItemDetailView(item: item)
        }
    }

    private func load() async {
        do {
            async let cat = APIClient.shared.catalog()
            async let hrs = APIClient.shared.hours()
            catalog = try await cat
            hours = try? await hrs   // hours banner is best-effort
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "truck.box.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("HALAL EXPRESS")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
                    .kerning(0.5)
                Text("Authentic halal, made fresh on the truck")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient.brand)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Brand.red.opacity(0.3), radius: 12, y: 6)
    }
}

/// Open/closed status pill fed by /api/hours.
struct HoursBanner: View {
    let hours: HoursStatus?

    var body: some View {
        if let hours {
            let open = hours.orderingOpen
            HStack(spacing: 10) {
                Image(systemName: open ? "checkmark.seal.fill" : "clock.badge.exclamationmark.fill")
                    .foregroundStyle(open ? .green : Brand.ember)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(open ? "Open now" : "Ordering closed")
                        .font(.subheadline.weight(.semibold))
                    Text(open
                         ? (hours.location?.display ?? "Tap an item to start your order")
                         : (hours.message ?? "You can still order ahead at checkout."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(12)
            .background((open ? Color.green : Brand.ember).opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct MenuRow: View {
    let item: CatalogItem

    var body: some View {
        HStack(spacing: 14) {
            MenuItemImage(item: item)
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                if !item.desc.isEmpty {
                    Text(item.desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    PricePill(cents: Int((item.price * 100).rounded()))
                    if item.options != nil || item.customize != nil {
                        Text("Customizable")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Brand.ember)
                    }
                }
            }
            Spacer(minLength: 4)
        }
        .padding(.vertical, 4)
    }
}
