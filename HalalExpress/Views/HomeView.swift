import SwiftUI
import MapKit
import CoreLocation

/// Chipotle-style home: greeting, Order Now CTA, truck status + map, recents, rewards.
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    greeting
                    orderNowCard
                    truckCard
                    if let last = orders.orders.first {
                        recentOrderCard(last)
                    }
                    rewardsCard
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Halal Express")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: - Cards

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(firstName.map { "Salaam, \($0) 👋" } ?? "Salaam 👋")
                .font(.title.bold())
            Text(daypartLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var daypartLine: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case ..<11: return "Good morning — the grill fires up soon."
        case ..<16: return "Perfect time for a fresh platter."
        default:    return "Dinner's calling — fresh off the grill."
        }
    }

    private var orderNowCard: some View {
        Button {
            switchTab(.menu)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "truck.box.fill")
                    .font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Order Now")
                        .font(.title3.weight(.black))
                    Text("Fresh halal, made to order")
                        .font(.caption)
                        .opacity(0.9)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.headline)
            }
            .foregroundStyle(.white)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient.brand)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Brand.red.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var truckCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The Truck").font(.headline)

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
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18))
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
                    Spacer()
                    Text(dollars(order.totalCents))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Brand.red)
                }
                Text(order.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(order.date, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 18))
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
                        Text("Weekly truck spots + exclusive deals by text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("You're on the list\(firstName.map { ", \($0)" } ?? "")!")
                            .font(.headline)
                        Text("Watch your texts for deals and truck spots")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private func load() async {
        hours = try? await APIClient.shared.hours()
        shifts = (try? await APIClient.shared.scheduleSlots())?.shifts ?? []

        // Geocode today's spot once per address; hide the map quietly on failure.
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
