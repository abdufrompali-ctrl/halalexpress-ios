import Foundation

enum APIError: LocalizedError {
    case server(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .server(let msg): return msg
        case .badResponse: return "Unexpected response from the server."
        }
    }
}

/// Thin async client for the Halal Express API. The server is the source of
/// truth for prices, tax and availability — the app never computes a charge.
final class APIClient {
    static let shared = APIClient()
    let baseURL = URL(string: "https://halalexpressnc.com")!

    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        let (data, resp) = try await session.data(from: comps.url!)
        return try handle(data: data, response: resp)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        let (data, resp) = try await session.data(for: req)
        return try handle(data: data, response: resp)
    }

    private func handle<T: Decodable>(data: Data, response: URLResponse) throws -> T {
        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            // Server errors arrive as {"error": "human-readable message"}
            if let err = try? decoder.decode([String: String].self, from: data),
               let msg = err["error"] {
                throw APIError.server(msg)
            }
            throw APIError.badResponse
        }
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Endpoints

    func catalog() async throws -> Catalog { try await get("api/catalog") }
    func hours() async throws -> HoursStatus { try await get("api/hours") }
    func scheduleSlots() async throws -> ScheduleResponse { try await get("api/schedule-slots") }
    func config() async throws -> ServerConfig { try await get("api/config") }

    func checkout(_ request: CheckoutRequest) async throws -> CheckoutResponse {
        try await post("api/checkout", body: request)
    }

    func loyaltyJoin(name: String, phone: String, email: String?) async throws -> LoyaltyJoinResponse {
        struct Body: Encodable { let name: String; let phone: String; let email: String? }
        return try await post("api/loyalty/join", body: Body(name: name, phone: phone, email: email))
    }

    func loyaltyStatus(phone: String) async throws -> LoyaltyStatus {
        try await get("api/loyalty/status", query: [URLQueryItem(name: "phone", value: phone)])
    }
}
