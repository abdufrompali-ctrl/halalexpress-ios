import SwiftUI
import MapKit
import CoreLocation

/// The Locate tab — where the truck is today and the rest of the week.
struct LocateView: View {
    @State private var hours: HoursStatus?
    @State private var shifts: [Shift] = []
    @State private var pin: CLLocationCoordinate2D?
    @State private var camera: MapCameraPosition = .automatic
    @State private var geocoded = ""

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground(animated: false)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        if pin != nil { mapCard }
                        statusCard
                        if !shifts.isEmpty { stopsSection }
                    }
                    .padding(.bottom, 20)
                }
                .scrollContentBackground(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Locate").font(.display(44)).foregroundStyle(.white)
            Text("Find the truck this week").font(.caption).foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 20).padding(.top, 8)
    }

    private var mapCard: some View {
        Map(position: $camera) {
            if let pin {
                Marker("Halal Express", systemImage: "flame.fill", coordinate: pin)
                    .tint(Brand.red)
            }
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: Brand.r))
        .overlay(RoundedRectangle(cornerRadius: Brand.r).strokeBorder(Brand.cardBrd, lineWidth: 1))
        .allowsHitTesting(false)
        .padding(.horizontal, 16)
    }

    private var statusCard: some View {
        let open = hours?.orderingOpen == true
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle().fill(open ? Color(hex: 0x3ECF7A) : Brand.ember)
                    .frame(width: 9, height: 9)
                    .shadow(color: open ? Color(hex: 0x3ECF7A) : Brand.ember, radius: 5)
                Text(open ? "Open now" : "Ordering closed")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                Spacer()
                Text(open ? "OPEN" : "CLOSED")
                    .font(.caption2.weight(.heavy)).kerning(0.5)
                    .foregroundStyle(open ? Color(hex: 0x3ECF7A) : Brand.ember)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background((open ? Color(hex: 0x3ECF7A) : Brand.ember).opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            if let loc = hours?.location {
                Text([loc.address, loc.city].compactMap { $0 }.joined(separator: ", "))
                    .font(.subheadline).foregroundStyle(.white.opacity(0.7))
            } else if let msg = hours?.message {
                Text(msg).font(.subheadline).foregroundStyle(.white.opacity(0.6))
            }
            if let url = directionsURL {
                Link(destination: url) {
                    Text("Get directions")
                        .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(LinearGradient.brand)
                        .clipShape(RoundedRectangle(cornerRadius: Brand.r))
                }
            }
        }
        .padding(15)
        .background(Brand.warmCard)
        .clipShape(RoundedRectangle(cornerRadius: Brand.r))
        .overlay(RoundedRectangle(cornerRadius: Brand.r).strokeBorder(Brand.cardBrd, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var stopsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("Where we'll be").font(.display(18)).foregroundStyle(.white)
                Rectangle().fill(LinearGradient(colors: [.white.opacity(0.14), .clear],
                                                startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 10)

            ForEach(shifts) { shift in
                HStack(alignment: .top, spacing: 14) {
                    Text(String(shift.label.prefix(3)).uppercased())
                        .font(.display(16)).foregroundStyle(Brand.emberSoft)
                        .frame(width: 42, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shift.location?.label ?? shift.location?.address ?? shift.label)
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        if let city = shift.location?.city {
                            Text(city).font(.caption).foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    Spacer()
                    if let first = shift.slots.first, let last = shift.slots.last {
                        Text("\(slotTimeLabel(first)) – \(slotTimeLabel(last))")
                            .font(.price(11.5)).foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .overlay(alignment: .top) {
                    Rectangle().fill(Brand.cardBrd).frame(height: 1)
                }
            }
        }
    }

    private var directionsURL: URL? {
        guard let loc = hours?.location else { return nil }
        let q = [loc.address, loc.city].compactMap { $0 }.joined(separator: ", ")
        guard !q.isEmpty,
              let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "http://maps.apple.com/?q=\(enc)")
    }

    private func load() async {
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
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
        }
    }
}
