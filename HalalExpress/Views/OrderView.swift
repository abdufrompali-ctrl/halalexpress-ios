import SwiftUI

/// The Menu — a printed board on paper. A featured dish, category headings, and
/// dish rows that run name → dotted leader → price. A solid red order bar rides
/// the bottom once there's something in the cart.
struct OrderView: View {
    @EnvironmentObject private var cart: CartStore

    @State private var catalog: Catalog?
    @State private var hours: HoursStatus?
    @State private var selected: String?
    @State private var showCart = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PaperGroundLayer()
                content
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CatalogItem.self) { ItemDetailView(item: $0) }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showCart) { CartView(onFinished: { showCart = false }) }
        }
    }

    @ViewBuilder private var content: some View {
        if let catalog {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    header
                    if let feat = catalog.items.first {
                        FeaturedDish(item: feat).padding(.horizontal, 20).padding(.bottom, 8)
                    }
                    Section {
                        itemList(catalog)
                    } header: {
                        categoryBar(catalog)
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) { if !cart.isEmpty { orderBar } }
        } else if let error {
            ContentUnavailableView {
                Label("Menu unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button("Try again") { Task { await load() } }
                    .buttonStyle(.borderedProminent).tint(Paper.red)
            }
        } else {
            ProgressView().controlSize(.large).tint(Paper.red)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            BoardHeader(title: "MENU") { StatusStamp(open: hours?.orderingOpen) }
            Group {
                if let loc = hours?.location {
                    Text([loc.address, loc.city].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(Paper.inkSoft)
                } else {
                    Text("Pickup · order ahead").font(.subheadline).foregroundStyle(Paper.inkSoft)
                }
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 14)
        }
    }

    // MARK: - Category headings (pinned)

    private func categoryBar(_ catalog: Catalog) -> some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(catalog.categories, id: \.self) { cat in
                        let on = (selected ?? catalog.categories.first) == cat
                        Button { selected = cat } label: {
                            VStack(spacing: 5) {
                                Text(cat.capitalized)
                                    .font(.system(.subheadline, design: .default).weight(.bold))
                                    .foregroundStyle(on ? Paper.ink : Paper.inkFaint)
                                Rectangle().fill(on ? Paper.red : .clear).frame(height: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 6)
            Rule()
        }
        .background(Paper.bg)
    }

    // MARK: - Item list

    private func itemList(_ catalog: Catalog) -> some View {
        let cat = selected ?? catalog.categories.first ?? ""
        let items = catalog.items.filter { $0.category == cat }
        return VStack(spacing: 0) {
            ForEach(items) { item in
                NavigationLink(value: item) { DishRow(item: item) }
                    .buttonStyle(.plain)
                Rule().padding(.leading, 20)
            }
        }
    }

    // MARK: - Order bar

    private var orderBar: some View {
        Button { showCart = true } label: {
            HStack(spacing: 12) {
                Text("\(cart.itemCount)")
                    .font(.price(15)).foregroundStyle(Paper.red)
                    .frame(minWidth: 26).padding(.vertical, 4)
                    .background(Color.white)
                Text("View order").font(.system(.headline, design: .default).weight(.semibold))
                Spacer()
                Text(dollars(cart.totalCents)).font(.price(17))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Paper.red)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View order, \(cart.itemCount) items, \(dollars(cart.totalCents))")
    }

    // MARK: - Data

    private func load() async {
        do {
            async let cat = APIClient.shared.catalog()
            async let hrs = APIClient.shared.hours()
            let loaded = try await cat
            catalog = loaded
            hours = try? await hrs
            // Keep the selected category valid across reloads.
            if selected == nil || !(loaded.categories.contains(selected!)) {
                selected = loaded.categories.first
            }
            error = nil
        } catch {
            if catalog == nil { self.error = error.localizedDescription }
        }
    }
}

// MARK: - Featured dish

private struct FeaturedDish: View {
    let item: CatalogItem
    var body: some View {
        NavigationLink(value: item) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    MenuItemImage(item: item).frame(height: 190).frame(maxWidth: .infinity)
                    Text("FEATURED")
                        .font(.system(.caption, design: .default).weight(.heavy)).tracking(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Paper.red)
                        .padding(10)
                }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(item.name).font(.board(26)).foregroundStyle(Paper.ink)
                    Spacer()
                    Text(dollars(Int((item.price * 100).rounded())))
                        .font(.price(17)).foregroundStyle(Paper.ink)
                }
                .padding(.horizontal, 12).padding(.top, 10)
                if !item.desc.isEmpty {
                    Text(item.desc).font(.subheadline).foregroundStyle(Paper.inkSoft)
                        .lineLimit(2).padding(.horizontal, 12).padding(.top, 2).padding(.bottom, 12)
                } else {
                    Color.clear.frame(height: 12)
                }
            }
            .paperBox()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dish row

private struct DishRow: View {
    let item: CatalogItem
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MenuItemImage(item: item).frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.name)
                        .font(.system(.body, design: .default).weight(.semibold))
                        .foregroundStyle(Paper.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    DottedLeader()
                    Text(dollars(Int((item.price * 100).rounded())))
                        .font(.price(15)).foregroundStyle(Paper.ink)
                }
                if !item.desc.isEmpty {
                    Text(item.desc).font(.footnote).foregroundStyle(Paper.inkSoft).lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
