import SwiftUI
import MapKit
import CoreLocation

struct HomeView: View {
    var switchTab: (AppTab) -> Void

    @EnvironmentObject private var orders: OrderHistoryStore
    @AppStorage("loyaltyName") private var savedName = ""
    @AppStorage("loyaltyPhone") private var savedPhone = ""

    @State private var hours: HoursStatus?
    @State private var shifts: [Shift] = []
    @State private var pin: CLLocationCoordinate2D?
    @State private var camera: MapCameraPosition = .automatic
    @State private var geocodedAddress = ""

    private var firstName: String? {
        savedName.split(separator: " ").first.map(String.init)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                ScrollView {
                    VStack(spacing: 0) {
                        heroSlash
                        VStack(alignment: .leading, spacing: 14) {
                            orderNowCard.appearFadeUp(delay: 0.05)
                            truckCard.appearFadeUp(delay: 0.12)
                            if let last = orders.orders.first {
                                recentOrderCard(last).appearFadeUp(delay: 0.19)
                            }
                            rewardsCard.appearFadeUp(delay: 0.26)
                        }
                        .padding(.horizontal)
                        .padding(.top, -28)
                        .padding(.bottom, 24)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Halal Express")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Brand.red, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: - Hero

    private var heroSlash: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Brand.ember, Brand.red, Color(hex: 0x6B0808)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 8) {
                if hours?.orderingOpen == true {
                    liveBadge
                }
                Text(firstName.map { "Hey, \($0)" } ?? "Hey there")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)
                Text(daypartLine)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 56)
        }
        .clipShape(DiagonalSlash(rise: 60))
    }

    private var liveBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: 0x4ADE80))
                .frame(width: 6, height: 6)
                .shadow(color: Color(hex: 0x22C55E), radius: 4)
            Text("TRUCK IS LIVE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(hex: 0x4ADE80))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.black.opacity(0.25), in: Capsule())
    }

    private var daypartLine: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case ..<11: return "The grill fires up soon."
        case ..<16: return "Perfect time for a fresh platter."
        default:    return "Dinner's calling — fresh off the grill."
        }
    }

    // MARK: - Cards

    private var orderNowCard: some View {
        Button {
            switchTab(.menu)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "truck.box.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Brand.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Order Now")
                        .font(.title3.weight(.black))
                        .foregroundStyle(Brand.ink)
                    Text("Fresh halal, made to order")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Go")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(LinearGradient.brand, in: RoundedRectangle(cornerRadius: 10))
                    .shadow(color: Brand.red.opacity(0.4), radius: 8, y: 4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.45), radius: 20, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var truckCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The Truck")
                .font(.headline)
                .foregroundStyle(.white)

            HoursBanner(hours: hours)

            if pin != nil {
                Map(position: $camera) {
                    if let pin {
                        Marker("Halal Express", systemImage: "truck.box.fill", coordinate: pin)
                            .tint(Brand.red)
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .allowsHitTesting(false)
            }

            if let next = nextShiftLine {
                Label(next, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(14)
        .glassCard()
    }

    private var nextShiftLine: String? {
        guard let shift = shifts.first,
              let first = shift.slots.first, let last = shift.slots.last else { return nil }
        return "\(shift.label): pickup \(slotTimeLabel(first)) – \(slotTimeLabel(last))"
    }

    private func recentOrderCard(_ order: OrderRecord) -> some View {
        Button {
            switchTab(.rewards)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Last Order", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(dollars(order.totalCents))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Brand.emberSoft)
                }
                Text(order.summary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(2)
                Text(order.date, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private var rewardsCard: some View {
        Button {
            switchTab(.rewards)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Brand.gold)
                VStack(alignment: .leading, spacing: 2) {
                    if savedPhone.isEmpty {
                        Text("Join Rewards — free")
                            .font(.headline)
                            .foregroundStyle(Brand.gold)
                        Text("Weekly truck spots + exclusive deals by text")
                            .font(.caption)
                            .foregroundStyle(Brand.gold.opacity(0.5))
                    } else {
                        Text("You're on the list\(firstName.map { ", \($0)" } ?? "")!")
                            .font(.headline)
                            .foregroundStyle(Brand.gold)
                        Text("Watch your texts for deals and truck spots")
                            .font(.caption)
                            .foregroundStyle(Brand.gold.opacity(0.5))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(Brand.gold.opacity(0.35))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Brand.gold.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private func load() async {
        hours = try? await APIClient.shared.hours()
        shifts = (try? await APIClient.shared.scheduleSlots())?.shifts ?? []

        let loc = hours?.location ?? shifts.first?.location
        guard let loc else { return }
        let addr = [loc.address, loc.city].compactMap { $0 }.joined(separator: ", ")
        guard !addr.isEmpty, addr != geocodedAddress else { return }
        geocodedAddress = addr
        if let placemark = try? await CLGeocoder().geocodeAddressString(addr).first,
           let coord = placemark.location?.coordinate {
            pin = coord
            camera = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
        }
    }
}
