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
                    ContentUnavailableView("Menu unavailable",
                                           systemImage: "wifi.exclamationmark",
                                           description: Text(error))
                        .overlay(alignment: .bottom) {
                            Button("Retry") { Task { await load() } }
                                .buttonStyle(.borderedProminent)
                                .padding(.bottom, 40)
                        }
                } else {
                    ProgressView("Loading menu…")
                }
            }
            .navigationTitle("Halal Express")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @ViewBuilder
    private func menuList(_ catalog: Catalog) -> some View {
        List {
            Section {
                BrandHeader()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if let hours, !hours.orderingOpen {
                Section {
                    Label(hours.message ?? "Online ordering is closed right now — you can still order ahead at checkout.",
                          systemImage: "clock.badge.exclamationmark")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            } else if let loc = hours?.location {
                Section {
                    Label("Open now — \(loc.display)", systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
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
                        Text(category)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(Brand.red)
                    }
                }
            }
        }
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
                .font(.system(size: 34))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("HALAL EXPRESS")
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white)
                Text("Authentic halal, made fresh on the truck")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Brand.ember, Brand.red, Brand.redDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct MenuRow: View {
    let item: CatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name).font(.headline)
                Spacer()
                Text(String(format: "$%.2f", item.price))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Brand.ember)
            }
            if !item.desc.isEmpty {
                Text(item.desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
