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
                    Section(category.capitalized) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                MenuRow(item: item)
                            }
                        }
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

struct MenuRow: View {
    let item: CatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name).font(.headline)
                Spacer()
                Text(String(format: "$%.2f", item.price))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
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
