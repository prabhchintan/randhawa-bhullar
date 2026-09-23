import Foundation

// The one host this app ever talks to: the house, on the maintainer's own
// tailnet. Plain HTTP, no token, no login; the tailnet is the wire.
struct HouseHealth: Decodable {
    let ok: Bool
    let house: String
    let time: String
}

enum HouseError: Error {
    case noAddress
    case unreachable
}

struct HouseClient {
    var baseAddress: String

    // A reply may take a minute or more to think through, so this session's
    // timeout is generous; the default URLSession gives up after 60 seconds.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        return URLSession(configuration: config)
    }()

    private func url(_ path: String) -> URL? {
        var address = baseAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.contains("://") { address = "http://" + address }
        while address.hasSuffix("/") { address.removeLast() }
        return URL(string: address + path)
    }

    func health() async throws -> HouseHealth {
        guard let url = url("/v1/health") else { throw HouseError.noAddress }
        let (data, _) = try await Self.session.data(from: url)
        return try JSONDecoder().decode(HouseHealth.self, from: data)
    }

    func cockpit() async throws -> String {
        guard let url = url("/v1/cockpit") else { throw HouseError.noAddress }
        let (data, _) = try await Self.session.data(from: url)
        struct Cockpit: Decodable { let text: String }
        return try JSONDecoder().decode(Cockpit.self, from: data).text
    }

    // The day's painting: its label from the house, the picture itself from
    // the house too, so the app still talks to one host.
    struct Painting: Decodable {
        let title: String?
        let artist: String?
        let year: String?
        let credit: String?
    }

    func painting() async throws -> Painting {
        guard let url = url("/v1/painting") else { throw HouseError.noAddress }
        let (data, _) = try await Self.session.data(from: url)
        return try JSONDecoder().decode(Painting.self, from: data)
    }

    func paintingImage() async throws -> Data {
        guard let url = url("/v1/painting.jpg") else { throw HouseError.noAddress }
        let (data, response) = try await Self.session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw HouseError.unreachable }
        return data
    }

    func board() async throws -> String {
        guard let url = url("/v1/board") else { throw HouseError.noAddress }
        let (data, _) = try await Self.session.data(from: url)
        struct Board: Decodable { let text: String }
        return try JSONDecoder().decode(Board.self, from: data).text
    }

    func say(_ text: String) async throws -> String {
        guard let sayURL = url("/v1/say") else { throw HouseError.noAddress }
        var request = URLRequest(url: sayURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["text": text])
        let (data, response) = try await Self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HouseError.unreachable }
        struct SayResponse: Decodable { let id: String?; let reply: String? }
        let decoded = try JSONDecoder().decode(SayResponse.self, from: data)
        if http.statusCode == 202, let id = decoded.id {
            return try await pollSay(id: id)
        }
        return decoded.reply ?? ""
    }

    private func pollSay(id: String) async throws -> String {
        guard let pollURL = url("/v1/say/\(id)") else { throw HouseError.noAddress }
        struct SayResponse: Decodable { let reply: String? }
        while true {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let (data, response) = try await Self.session.data(from: pollURL)
            guard let http = response as? HTTPURLResponse else { throw HouseError.unreachable }
            if http.statusCode == 200, let reply = try? JSONDecoder().decode(SayResponse.self, from: data).reply {
                return reply
            }
        }
    }
}
