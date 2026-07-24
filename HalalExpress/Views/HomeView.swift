import SwiftUI

/// Home — the truck's front board: whether it's open, where to find it, your last
/// order, an auto-sliding menu showcase, and how to order (pickup or delivery).
struct HomeView: View {
    var goOrder: () -> Void

    @EnvironmentObject private var cart: CartStore
    @EnvironmentObject private var orders: OrderHistoryStore
    @AppStorage("loyaltyName") private var savedName = ""

    @State private var hours: HoursStatus?
    @State private var shifts: [Shift] = []
    @State private var catalog: Catalog?

    // Auto-advancing "On the menu" strip.
    @State private var scrolledItemID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let autoScroll = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    // Real Halal Express storefronts — universal links open the app if installed.
    private let doorDashURL = URL(string: "https://www.doordash.com/en/store/halal-express-wilmington-27459818/92292416/")!
    private let uberEatsURL = URL(string: "https://www.ubereats.com/store/halal-express-carolina-beach-rd-dba-two-brothers-enterprises-llc/efqybQ5OWrSEbn5TsYV4HA?diningMode=DELIVERY&surfaceName=")!

    private var firstName: String? { savedName.split(separator: " ").first.map(String.init) }
    private var isOpen: Bool { hours?.orderingOpen == true }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    VStack(alignment: .leading, spacing: 18) {
                        statusBlock
                        if let last = orders.orders.first { reorderBlock(last) }
                        if let catalog, !catalog.items.isEmpty { menuStrip(featuredItems(catalog)) }
                        startOrderButton
                        deliverySection
                        stopsSection
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .paperGround()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CatalogItem.self) { ItemDetailView(item: $0) }
            .task { await load() }
            .refreshable { await load() }
            .onReceive(autoScroll) { _ in advanceStrip() }
        }
    }

    /// Step the menu strip to the next card, looping back to the first at the end.
    /// Skipped under Reduce Motion so it never animates against the user's setting.
    private func advanceStrip() {
        guard !reduceMotion, let catalog else { return }
        let ids = featuredItems(catalog).map(\.id)
        guard ids.count > 1 else { return }
        let current = scrolledItemID.flatMap { ids.firstIndex(of: $0) } ?? 0
        let next = (current + 1) % ids.count
        withAnimation(.easeInOut(duration: 0.6)) { scrolledItemID = ids[next] }
    }

    // MARK: - Header

    private var header: some View {
        BoardHeader(eyebrow: "HALAL EXPRESS",
                    title: firstName.map { "HI, \($0.uppercased())" } ?? "WELCOME")
    }

    // MARK: - Status

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                StatusStamp(open: hours?.orderingOpen)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 12)

            Rule()
            HStack(spacing: 0) {
                if let url = findUsURL {
                    Link(destination: url) {
                        actionLabel("Find us", systemImage: "mappin.and.ellipse")
                    }
                    Rectangle().fill(Paper.line).frame(width: 1, height: 22)
                }
                if let url = Truck.phoneURL {
                    Link(destination: url) { actionLabel("Call", systemImage: "phone") }
                }
            }
        }
        .paperBox()
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage).font(.caption)
            Text(title).font(.system(.subheadline, design: .default).weight(.semibold))
        }
        .foregroundStyle(Paper.red)
        .frame(maxWidth: .infinity).padding(.vertical, 13)
    }

    // MARK: - Actions

    private var startOrderButton: some View {
        Button { goOrder() } label: {
            HStack(spacing: 14) {
                Image(systemName: "bag.fill").font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start an order")
                        .font(.system(.headline, design: .default).weight(.bold))
                    Text("Order ahead — ready for pickup at the truck")
                        .font(.caption).foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.right").font(.headline)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Paper.red, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private func reorderBlock(_ order: OrderRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ORDER AGAIN")
                    .font(.system(.caption, design: .default).weight(.heavy)).tracking(1)
                    .foregroundStyle(Paper.inkSoft)
                Spacer()
                Text(dollars(order.totalCents)).font(.price(14)).foregroundStyle(Paper.ink)
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 6)

            Text(order.summary).font(.subheadline).foregroundStyle(Paper.ink)
                .lineLimit(2).padding(.horizontal, 14).padding(.bottom, 12)

            Rule()
            Button { reorder(order) } label: {
                Text(catalog == nil ? "Loading menu…" : "Add these to cart")
                    .font(.system(.subheadline, design: .default).weight(.semibold))
                    .foregroundStyle(catalog == nil ? Paper.inkFaint : Paper.red)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .disabled(catalog == nil)
        }
        .paperBox()
    }

    // MARK: - Menu strip (a sliding showcase — not tappable)

    /// The dishes to feature: the Plates (signature platters), falling back to the
    /// first few items if the catalog is shaped differently.
    private func featuredItems(_ catalog: Catalog) -> [CatalogItem] {
        let plates = catalog.items.filter { $0.category.uppercased() == "PLATES" }
        return plates.isEmpty ? Array(catalog.items.prefix(6)) : plates
    }

    private func menuStrip(_ items: [CatalogItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ON THE MENU")
                    .font(.system(.caption, design: .default).weight(.heavy)).tracking(1)
                    .foregroundStyle(Paper.inkFaint)
                Spacer()
                HStack(spacing: 4) {
                    Text("Swipe").font(.caption2.weight(.semibold))
                    Image(systemName: "arrow.right").font(.caption2)
                }
                .foregroundStyle(Paper.inkFaint)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { menuCard($0) }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)   // aligns first card with the header
            }
            .scrollPosition(id: $scrolledItemID)
            .scrollTargetBehavior(.viewAligned)
            .padding(.horizontal, -20)      // let the strip bleed to the screen edges
        }
    }

    private func menuCard(_ item: CatalogItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuItemImage(item: item).frame(width: 168, height: 108)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.name).font(.board(18)).foregroundStyle(Paper.ink)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Spacer(minLength: 2)
                    Text(dollars(Int((item.price * 100).rounded())))
                        .font(.price(13)).foregroundStyle(Paper.ink)
                }
                if !item.desc.isEmpty {
                    Text(item.desc)
                        .font(.caption).foregroundStyle(Paper.inkSoft)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            Spacer(minLength: 0)
        }
        .frame(width: 168, height: 200, alignment: .top)
        .paperBox()
    }

    // MARK: - Delivery handoffs

    private var deliverySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PREFER DELIVERY?")
                .font(.system(.caption, design: .default).weight(.heavy)).tracking(1)
                .foregroundStyle(Paper.inkFaint)
            HStack(spacing: 10) {
                deliveryButton("DoorDash", color: Color(hex: 0xEB1700), url: doorDashURL)
                deliveryButton("Uber Eats", color: Color(hex: 0x06C167), url: uberEatsURL)
            }
        }
    }

    private func deliveryButton(_ name: String, color: Color, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 9) {
                Circle().fill(color).frame(width: 9, height: 9)
                Text(name).font(.system(.subheadline, design: .default).weight(.bold))
                    .foregroundStyle(Paper.ink)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(Paper.inkFaint)
            }
            .padding(.vertical, 14).padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .paperBox()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hours & locations preview

    private var stopsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink { LocationsView() } label: {
                HStack {
                    Text("HOURS & LOCATIONS")
                        .font(.system(.caption, design: .default).weight(.heavy)).tracking(1)
                        .foregroundStyle(Paper.inkFaint)
                    Spacer()
                    Text("See all").font(.caption.weight(.semibold)).foregroundStyle(Paper.red)
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Paper.red)
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                Rule()
                ForEach(Truck.spots) { spot in
                    NavigationLink { LocationsView() } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(spot.name).font(.board(20)).foregroundStyle(Paper.ink)
                            ForEach(Array(spot.hours.enumerated()), id: \.offset) { _, h in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(h.day).font(.footnote).foregroundStyle(Paper.inkSoft)
                                    Spacer()
                                    Text(h.range).font(.price(12)).foregroundStyle(Paper.ink)
                                }
                            }
                        }
                        .padding(.vertical, 12).padding(.horizontal, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Rule()
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(Truck.closedDay).font(.footnote).foregroundStyle(Paper.inkSoft)
                    Spacer()
                    Text("Closed").font(.price(12)).foregroundStyle(Paper.inkFaint)
                }
                .padding(.vertical, 12).padding(.horizontal, 14)
            }
            .paperBox()
        }
    }

    // MARK: - Data

    /// Opens Apple Maps at the truck's current/next spot — or the primary spot when
    /// the schedule feed has nothing (so "Find us" always works).
    private var findUsURL: URL? {
        let loc = hours?.location ?? shifts.first?.location
        let address = loc?.address ?? Truck.spots.first?.address
        let city = loc?.city ?? Truck.spots.first?.city
        guard let address else { return nil }
        let q = [address, city].compactMap { $0 }.joined(separator: ", ")
        guard let enc = q.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else { return nil }
        return URL(string: "http://maps.apple.com/?q=\(enc)")
    }

    private func reorder(_ order: OrderRecord) {
        guard let catalog else { return }
        for line in order.lines {
            if let item = catalog.items.first(where: { $0.id == line.itemId }) {
                cart.add(item, option: line.option, customizations: line.customizations,
                         addOnCents: line.addOnCents, quantity: line.quantity)
            }
        }
        goOrder()
    }

    private func load() async {
        async let cat = APIClient.shared.catalog()
        async let hrs = APIClient.shared.hours()
        async let sched = APIClient.shared.scheduleSlots()
        catalog = try? await cat
        hours = try? await hrs
        shifts = (try? await sched)?.shifts ?? []
    }
}
