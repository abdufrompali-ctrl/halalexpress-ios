import SwiftUI

/// The Order tab — Chipotle-warm: a featured "house favorite" hero, category
/// chips, big item cards with monospaced prices, and a floating cart bar.
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
                BrandBackground(animated: false)
                content
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CatalogItem.self) { ItemDetailView(item: $0) }
            .task { await load() }
            .sheet(isPresented: $showCart) { CartView() }
        }
    }

    @ViewBuilder private var content: some View {
        if let catalog {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if let feat = catalog.items.first {
                        FeaturedCard(item: feat)
                            .padding(.horizontal, 16)
                            .padding(.top, 2)
                    }
                    categoryBar(catalog)
                    itemList(catalog)
                }
                .padding(.bottom, 20)
            }
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                if !cart.isEmpty { cartBar }
            }
        } else if let error {
            ContentUnavailableView {
                Label("Menu unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") { Task { await load() } }
                    .buttonStyle(.borderedProminent).tint(Brand.red)
            }
        } else {
            ProgressView("Loading menu…")
                .controlSize(.large).tint(Brand.red)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Order")
                    .font(.display(44))
                    .foregroundStyle(.white)
                Text(hours?.orderingOpen == true ? "Pickup · open now" : "Pickup · order ahead")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            if let city = hours?.location?.city ?? hours?.location?.label {
                HStack(spacing: 6) {
                    Circle().fill(hours?.orderingOpen == true ? Color(hex: 0x3ECF7A) : Brand.ember)
                        .frame(width: 7, height: 7)
                    Text(city).font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.65))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Brand.warmCard)
                .clipShape(RoundedRectangle(cornerRadius: Brand.r))
                .overlay(RoundedRectangle(cornerRadius: Brand.r).strokeBorder(Brand.cardBrd, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Category chips

    private func categoryBar(_ catalog: Catalog) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(catalog.categories, id: \.self) { cat in
                    let on = (selected ?? catalog.categories.first) == cat
                    Button { selected = cat } label: {
                        Text(cat.capitalized)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(on ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 15).padding(.vertical, 9)
                            .background {
                                if on { LinearGradient.brand } else { Brand.warmCard }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: Brand.r))
                            .overlay(RoundedRectangle(cornerRadius: Brand.r)
                                .strokeBorder(on ? Color.clear : Brand.cardBrd, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
    }

    // MARK: - Item list

    private func itemList(_ catalog: Catalog) -> some View {
        let cat = selected ?? catalog.categories.first ?? ""
        let items = catalog.items.filter { $0.category == cat }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(cat.capitalized).font(.display(18)).foregroundStyle(.white)
                Rectangle().fill(LinearGradient(colors: [.white.opacity(0.14), .clear],
                                                startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
            }
            .padding(.horizontal, 20).padding(.bottom, 10)

            ForEach(items) { OrderRow(item: $0) }
        }
    }

    // MARK: - Floating cart

    private var cartBar: some View {
        Button { showCart = true } label: {
            HStack(spacing: 12) {
                Text("\(cart.itemCount)")
                    .font(.price(13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.black.opacity(0.26))
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                Text("View order").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text(dollars(cart.totalCents)).font(.price(17)).foregroundStyle(.white)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(LinearGradient.brand)
            .clipShape(RoundedRectangle(cornerRadius: Brand.r))
            .shadow(color: Brand.red.opacity(0.4), radius: 18, y: 8)
            .padding(.horizontal, 14).padding(.bottom, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private func load() async {
        do {
            async let cat = APIClient.shared.catalog()
            async let hrs = APIClient.shared.hours()
            catalog = try await cat
            hours = try? await hrs
            if selected == nil { selected = catalog?.categories.first }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Featured hero card

private struct FeaturedCard: View {
    let item: CatalogItem
    var body: some View {
        NavigationLink(value: item) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    MenuItemImage(item: item, corner: 0, iconSize: 46)
                        .frame(height: 150).frame(maxWidth: .infinity)
                    Text("HOUSE FAVORITE")
                        .font(.caption2.weight(.heavy)).kerning(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(Brand.ember)
                }
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name).font(.display(24)).foregroundStyle(.white)
                        if !item.desc.isEmpty {
                            Text(item.desc).font(.caption).foregroundStyle(.white.opacity(0.55)).lineLimit(2)
                        }
                        Text(dollars(Int((item.price * 100).rounded())))
                            .font(.price(15)).foregroundStyle(.white).padding(.top, 4)
                    }
                    Spacer()
                    Text("Add")
                        .font(.subheadline.weight(.heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(LinearGradient.brand)
                        .clipShape(RoundedRectangle(cornerRadius: Brand.r))
                }
                .padding(14)
            }
            .background(Brand.warmCard)
            .clipShape(RoundedRectangle(cornerRadius: Brand.r))
            .overlay(RoundedRectangle(cornerRadius: Brand.r).strokeBorder(Brand.cardBrd, lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Item row

private struct OrderRow: View {
    let item: CatalogItem
    var body: some View {
        NavigationLink(value: item) {
            HStack(spacing: 14) {
                MenuItemImage(item: item, corner: 2, iconSize: 26)
                    .frame(width: 66, height: 66)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    if !item.desc.isEmpty {
                        Text(item.desc)
                            .font(.caption).foregroundStyle(.white.opacity(0.5)).lineLimit(2)
                    }
                    HStack {
                        Text(dollars(Int((item.price * 100).rounded())))
                            .font(.price(14.5)).foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(LinearGradient.brand)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(12)
            .background(Brand.warmCard)
            .clipShape(RoundedRectangle(cornerRadius: Brand.r))
            .overlay(RoundedRectangle(cornerRadius: Brand.r).strokeBorder(Brand.cardBrd, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16).padding(.bottom, 10)
    }
}
