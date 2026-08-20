import Foundation

enum APIError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case server(code: String, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "Не настроен адрес сервера"
        case .invalidResponse: "Сервер вернул некорректный ответ"
        case let .server(_, message): message
        }
    }
}

struct APIErrorEnvelope: Decodable {
    struct Payload: Decodable {
        let code: String
        let message: String
    }
    let error: Payload
}

actor APIClient {
    static let live = APIClient()

    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder = JSONEncoder()
    private let keychain = KeychainStore()

    init(session: URLSession = .shared, baseURL: URL? = nil) {
        self.session = session
        let configured = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String
        self.baseURL = baseURL ?? URL(string: configured ?? "") ?? URL(string: "http://127.0.0.1:8080/api/v1")!
        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let standard = ISO8601DateFormatter()
            guard let date = standard.date(from: value) else {
                throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Invalid ISO-8601 date")
            }
            return date
        }
    }

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], authenticated: Bool = false) async throws -> T {
        try await request(path, method: "GET", query: query, body: Optional<String>.none, authenticated: authenticated)
    }

    func send<T: Decodable, Body: Encodable>(_ path: String, method: String, body: Body, authenticated: Bool = true) async throws -> T {
        try await request(path, method: method, query: [], body: body, authenticated: authenticated)
    }

    func sendEmpty<Body: Encodable>(_ path: String, method: String, body: Body? = nil, authenticated: Bool = true) async throws {
        let _: EmptyResponse = try await request(path, method: method, query: [], body: body, authenticated: authenticated)
    }

    private func request<T: Decodable, Body: Encodable>(
        _ path: String,
        method: String,
        query: [URLQueryItem],
        body: Body?,
        authenticated: Bool
    ) async throws -> T {
        guard var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidConfiguration
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidConfiguration }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authenticated {
            if let token = keychain.read("accessToken") {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else {
                #if DEBUG
                request.setValue("00000000-0000-0000-0000-000000000001", forHTTPHeaderField: "X-Debug-User-Id")
                #endif
            }
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data) {
                throw APIError.server(code: envelope.error.code, message: envelope.error.message)
            }
            throw APIError.invalidResponse
        }
        if T.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! T
        }
        return try decoder.decode(T.self, from: data)
    }
}

private struct EmptyResponse: Codable {}
