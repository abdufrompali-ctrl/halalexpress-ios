import SwiftUI

// MARK: - Truck spots (owner-set)
//
// The two places the truck parks, with its regular weekly hours. Edit here — this
// is the single source for both the Home preview and the Hours & Locations screen.

struct TruckSpot: Identifiable {
    let name: String                       // short board name
    let address: String
    let city: String
    let hours: [(day: String, range: String)]
    var id: String { address }

    var directionsURL: URL? {
        let q = "\(address), \(city)"
        guard let enc = q.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else { return nil }
        return URL(string: "http://maps.apple.com/?q=\(enc)")
    }
}

enum Truck {
    static let phoneDisplay = "(910) 742-6679"
    static let phoneURL = URL(string: "tel:+19107426679")
    static let closedDay = "Sunday"

    static let spots: [TruckSpot] = [
        TruckSpot(
            name: "Carolina Beach Rd",
            address: "2069 Carolina Beach Rd",
            city: "Wilmington, NC",
            hours: [("Monday – Thursday", "11:00 AM – 8:00 PM")]
        ),
        TruckSpot(
            name: "Downtown · Late Night",
            address: "26 S 2nd St",
            city: "Wilmington, NC",
            hours: [("Friday – Saturday", "6:00 PM – 3:00 AM")]
        ),
    ]
}

// MARK: - Screen

/// Hours & Locations — the two spots the truck parks, with regular weekly hours,
/// directions, and a call button. Closed Sundays.
struct LocationsView: View {
    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("HOURS &\nLOCATIONS")
                        .font(.board(44)).foregroundStyle(Paper.ink)
                        .padding(.top, 4)

                    ForEach(Truck.spots) { spotCard($0) }
                    closedCard

                    Text("Hours can change on holidays and for weather — call ahead if you're not sure.")
                        .font(.caption).foregroundStyle(Paper.inkFaint)
                }
                .padding(.horizontal, 20).padding(.bottom, 32)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Hours & Locations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Paper.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func spotCard(_ spot: TruckSpot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(spot.name.uppercased()).font(.board(24)).foregroundStyle(Paper.ink)
                Text("\(spot.address) · \(spot.city)")
                    .font(.subheadline).foregroundStyle(Paper.inkSoft)
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 12)

            Rule()
            ForEach(Array(spot.hours.enumerated()), id: \.offset) { _, h in
                HStack(alignment: .firstTextBaseline) {
                    Text(h.day)
                        .font(.system(.subheadline, design: .default).weight(.semibold))
                        .foregroundStyle(Paper.ink)
                    Spacer()
                    Text(h.range).font(.price(13)).foregroundStyle(Paper.inkSoft)
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                Rule().padding(.leading, 14)
            }

            HStack(spacing: 0) {
                if let url = spot.directionsURL {
                    Link(destination: url) {
                        actionLabel("Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                    }
                }
                if spot.directionsURL != nil, Truck.phoneURL != nil {
                    Rectangle().fill(Paper.line).frame(width: 1, height: 22)
                }
                if let url = Truck.phoneURL {
                    Link(destination: url) { actionLabel("Call", systemImage: "phone") }
                }
            }
        }
        .paperBox()
    }

    /// Muted card marking the day the truck doesn't run. Same typography as the
    /// day/hours rows above (day label left, value right).
    private var closedCard: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(Truck.closedDay)
                .font(.system(.subheadline, design: .default).weight(.semibold))
                .foregroundStyle(Paper.ink)
            Spacer()
            Text("Closed").font(.price(13)).foregroundStyle(Paper.inkSoft)
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
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
}
