import SwiftUI
import MapKit
import CoreLocation

/// Home tab — greeting + live truck status, quick order actions, this week's
/// stops, and the delivery-app handoffs.
struct HomeView: View {
    var goOrder: () -> Void

    @EnvironmentObject private var cart: CartStore
    @EnvironmentObject private var orders: OrderHistoryStore
    @AppStorage("loyaltyName") private var savedName = ""

    @State private var hours: HoursStatus?
    @State private var shifts: [Shift] = []
    @State private var catalog: Catalog?
    @State private var pin: CLLocationCoordinate2D?
    @State private var camera: MapCameraPosition = .automatic
    @State private var geocoded = ""

    // Real Halal Express storefronts — universal links open the app if installed.
    private let doorDashURL = URL(string: "https://www.doordash.com/en/store/halal-express-wilmington-27459818/92292416/")!
    private let uberEatsURL = URL(string: "https://www.ubereats.com/store/halal-express-carolina-beach-rd-dba-two-brothers-enterprises-llc/efqybQ5OWrSEbn5TsYV4HA?diningMode=DELIVERY&surfaceName=")!

    private var firstName: String? { savedName.split(separator: " ").first.map(String.init) }
    private var isOpen: Bool { hours?.orderingOpen == true }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground(animated: false)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        statusCard
                        startOrderButton
                        if let last = orders.orders.first { reorderCard(last) }
                        if let feat = catalog?.items.first { featuredCard(feat) }
                        deliverySection
                        if !shifts.isEmpty { stopsSection }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .scrollContentBackground(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CatalogItem.self) { ItemDetailView(item: $0) }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(firstName.map { "Hey, \($0)" } ?? "Hey there")
                .font(.display(46)).foregroundStyle(.white)
            Text(daypartLine).font(.subheadline).foregroundStyle(.white.opacity(0.45))
        }
        .padding(.top, 8).padding(.bottom, 2)
    }

    private var daypartLine: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case ..<11: return "The grill's firing up."
        case ..<16: return "Fresh off the grill."
        default:    return "Dinner's calling."
        }
    }

    // MARK: - Status + map

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(isOpen ? Color(hex: 0x3ECF7A) : Brand.ember)
                    .frame(width: 8, height: 8)
                    .shadow(color: isOpen ? Color(hex: 0x3ECF7A) : Brand.ember, radius: 5)
                Text(isOpen ? "Truck is live" : "Ordering closed")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                Spacer()
            }
            if let loc = hours?.location {
                Text([loc.label, loc.address, loc.city].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.white.opacity(0.65))
            } else if let msg = hours?.message {
                Text(msg).font(.subheadline).foregroundStyle(.white.opacity(0.6))
            }
            if pin != nil {
                Map(position: $camera) {
                    if let pin {
                        Marker("Halal Express", systemImage: "flame.fill", coordinate: pin).tint(Brand.red)
                    }
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .allowsHitTesting(false)
            }
            if let url = directionsURL {
                Link(destination: url) {
                    HStack(spacing: 7) {
                        Image(systemName: "location.fill").font(.caption)
                        Text("Get directions").font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(LinearGradient.brand)
                    .clipShape(RoundedRectangle(cornerRadius: Brand.r))
                }
            }
        }
        .padding(15).card()
    }

    // MARK: - Actions

    private var startOrderButton: some View {
        Button { goOrder() } label: {
            HStack {
                Text("Start an order").font(.headline)
                Spacer()
                Image(systemName: "arrow.right").font(.headline)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 17).padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(LinearGradient.brand)
            .clipShape(RoundedRectangle(cornerRadius: Brand.r))
            .shadow(color: Brand.red.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func reorderCard(_ order: OrderRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Order again").font(.display(18)).foregroundStyle(.white)
                Spacer()
                Text(dollars(order.totalCents)).font(.price(14)).foregroundStyle(Brand.emberSoft)
            }
            Text(order.summary).font(.subheadline).foregroundStyle(.white.opacity(0.5)).lineLimit(2)
            Button { reorder(order) } label: {
                Text("Add these to cart")
                    .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Brand.warmBg2)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Brand.ember.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(15).card()
    }

    private func featuredCard(_ item: CatalogItem) -> some View {
        NavigationLink(value: item) {
            HStack(spacing: 14) {
                MenuItemImage(item: item, corner: 2, iconSize: 30).frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 3) {
                    Text("TODAY'S PICK").font(.caption2.weight(.heavy)).kerning(1).foregroundStyle(Brand.emberSoft)
                    Text(item.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    Text(dollars(Int((item.price * 100).rounded()))).font(.price(14)).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.subheadline).foregroundStyle(.white.opacity(0.3))
            }
            .padding(14).card()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Delivery handoffs

    private var deliverySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prefer delivery?").font(.caption.weight(.heavy)).kerning(1)
                .foregroundStyle(.white.opacity(0.4)).textCase(.uppercase)
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
                Text(name).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.white.opacity(0.5))
            }
            .padding(.vertical, 14).padding(.horizontal, 14)
            .frame(maxWidth: .infinity).card()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekly stops

    private var stopsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("This week").font(.display(18)).foregroundStyle(.white)
                Rectangle().fill(LinearGradient(colors: [.white.opacity(0.14), .clear],
                                                startPoint: .leading, endPoint: .trailing)).frame(height: 1)
            }
            .padding(.bottom, 8).padding(.top, 4)

            VStack(spacing: 0) {
                ForEach(shifts) { shift in
                    HStack(alignment: .top, spacing: 14) {
                        Text(String(shift.label.prefix(3)).uppercased())
                            .font(.display(16)).foregroundStyle(Brand.emberSoft)
                            .frame(width: 40, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shift.location?.label ?? shift.location?.address ?? shift.label)
                                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            if let city = shift.location?.city {
                                Text(city).font(.caption).foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        Spacer()
                        if let first = shift.slots.first, let last = shift.slots.last {
                            Text("\(slotTimeLabel(first))–\(slotTimeLabel(last))")
                                .font(.price(11)).foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    .padding(14)
                    if shift.id != shifts.last?.id {
                        Rectangle().fill(Brand.cardBrd).frame(height: 1)
                    }
                }
            }
            .card()
        }
    }

    // MARK: - Data

    private var directionsURL: URL? {
        guard let loc = hours?.location else { return nil }
        let q = [loc.address, loc.city].compactMap { $0 }.joined(separator: ", ")
        guard !q.isEmpty, let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "http://maps.apple.com/?q=\(enc)")
    }

    private func reorder(_ order: OrderRecord) {
        guard let catalog else { return }
        for line in order.lines {
            if let item = catalog.items.first(where: { $0.id == line.itemId }) {
                cart.add(item, option: line.option, customizations: line.customizations, quantity: line.quantity)
            }
        }
        goOrder()
    }

    private func load() async {
        catalog = try? await APIClient.shared.catalog()
        hours = try? await APIClient.shared.hours()
        shifts = (try? await APIClient.shared.scheduleSlots())?.shifts ?? []

        let loc = hours?.location ?? shifts.first?.location
        guard let loc else { return }
        let addr = [loc.address, loc.city].compactMap { $0 }.joined(separator: ", ")
        guard !addr.isEmpty, addr != geocoded else { return }
        geocoded = addr
        if let placemark = try? await CLGeocoder().geocodeAddressString(addr).first,
           let coord = placemark.location?.coordinate {
            pin = coord
            camera = .region(MKCoordinateRegion(
                center: coord, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
        }
    }
}

/// Shared crisp warm-card surface used across the new screens.
extension View {
    func card(_ radius: CGFloat = Brand.r) -> some View {
        self
            .background(Brand.warmCard)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Brand.cardBrd, lineWidth: 1))
    }
}
