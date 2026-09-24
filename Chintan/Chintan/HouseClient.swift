import CoreLocation
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
    case noDoor
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

    // A painting: its label from the house, the picture itself from the
    // house too, so the app still talks to one host. The shelf (since
    // 2026-09-23) is today's and the days ahead; each has an id and the path
    // of its picture, and the phone keeps them all so they are there offline.
    // `fit` names how the house composed the picture for the frame (since
    // 2026-09-24); a recut picture is a new key, so the kept one is let go.
    struct Painting: Codable, Equatable {
        let id: String?
        let title: String?
        let artist: String?
        let year: String?
        let credit: String?
        let date: String?
        let image: String?
        let fit: String?

        var key: String { (id ?? "today") + (fit.map { "-" + $0 } ?? "") }
        var imagePath: String { image ?? "/v1/painting.jpg" }
    }

    func painting() async throws -> Painting {
        guard let url = url("/v1/painting") else { throw HouseError.noAddress }
        let (data, _) = try await Self.session.data(from: url)
        return try JSONDecoder().decode(Painting.self, from: data)
    }

    // The shelf, today's first. A house without this door answers 404.
    func paintings() async throws -> [Painting] {
        guard let url = url("/v1/paintings") else { throw HouseError.noAddress }
        let (data, response) = try await Self.session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw HouseError.noDoor }
        struct Shelf: Decodable { let paintings: [Painting] }
        return try JSONDecoder().decode(Shelf.self, from: data).paintings
    }

    func paintingImage(_ painting: Painting? = nil) async throws -> Data {
        guard let url = url(painting?.imagePath ?? "/v1/painting.jpg") else { throw HouseError.noAddress }
        let (data, response) = try await Self.session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw HouseError.unreachable }
        return data
    }

    // The site's visitors as people (the house folds Pulse's sessions; bots
    // and datacenters are left out), and one person's visits with each page
    // and the time spent on it.
    struct Visit: Decodable, Identifiable {
        struct Step: Decodable {
            let page: String
            let seconds: Int
        }
        let id: String
        let at: Int
        let seconds: Int
        let pages: Int
        let source: String?
        let referrer: String?
        let device: String?
        let place: String?
        let network: String?
        let scroll: Int?
        let steps: [Step]
        let links: [String]?
    }

    struct Visitor: Decodable, Identifiable {
        let id: String
        let place: String
        let country: String?
        let network: String
        let kind: String
        let device: String
        let first: Int
        let last: Int
        let visits: Int
        let pages: Int
        let seconds: Int
        let returning: Bool
        let source: String
        let read: [String]
        let masked: Bool
        let realRegion: String?
        let languages: String?
        let visitList: [Visit]?
    }

    func visitors() async throws -> [Visitor] {
        guard let url = url("/v1/visitors") else { throw HouseError.noAddress }
        let (data, response) = try await Self.session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw HouseError.unreachable }
        if http.statusCode == 404 { throw HouseError.noDoor }
        guard http.statusCode == 200 else { throw HouseError.unreachable }
        struct Book: Decodable { let visitors: [Visitor] }
        return try JSONDecoder().decode(Book.self, from: data).visitors
    }

    func visitor(_ id: String) async throws -> Visitor {
        guard let url = url("/v1/visitors/\(id)") else { throw HouseError.noAddress }
        let (data, response) = try await Self.session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw HouseError.unreachable }
        struct One: Decodable { let visitor: Visitor }
        return try JSONDecoder().decode(One.self, from: data).visitor
    }

    // The usage meters, each with its name, how much is spent, and when it
    // comes back.
    struct Pulse: Decodable {
        struct Meter: Decodable {
            let key: String
            let name: String?
            let fraction: Double
            let resets: String?
            let words: String?
        }
        let meters: [Meter]
        // When the house last made its round.
        let tended: String?
    }

    func pulse() async throws -> Pulse {
        guard let url = url("/v1/pulse") else { throw HouseError.noAddress }
        let (data, response) = try await Self.session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw HouseError.unreachable }
        return try JSONDecoder().decode(Pulse.self, from: data)
    }

    func board() async throws -> String {
        guard let url = url("/v1/board") else { throw HouseError.noAddress }
        let (data, _) = try await Self.session.data(from: url)
        struct Board: Decodable { let text: String }
        return try JSONDecoder().decode(Board.self, from: data).text
    }

    // The house's short title for each open thing, by the line as the board
    // printed it: {"titles": [{"line", "title", "hour"}]}. A house without
    // this door answers 404 and the phone cuts its own.
    func titles() async throws -> [String: BoardItem.Short] {
        guard let url = url("/v1/titles") else { throw HouseError.noAddress }
        let (data, response) = try await Self.session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw HouseError.noDoor }
        struct Entry: Decodable { let line: String; let title: String; let hour: String? }
        struct Titles: Decodable { let titles: [Entry] }
        let entries = try JSONDecoder().decode(Titles.self, from: data).titles
        return Dictionary(entries.map { ($0.line, BoardItem.Short(title: $0.title, hour: $0.hour)) }) { a, _ in a }
    }

    // A thing marked done from the phone; the house runs `ghar done` with the
    // line as it printed it. A house without this door answers 404.
    func done(_ text: String) async throws {
        guard let doneURL = url("/v1/done") else { throw HouseError.noAddress }
        var request = URLRequest(url: doneURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["text": text])
        let (_, response) = try await Self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HouseError.unreachable }
        if http.statusCode == 404 || http.statusCode == 405 { throw HouseError.noDoor }
        guard (200..<300).contains(http.statusCode) else { throw HouseError.unreachable }
    }

    // Where the phone is, told to the house and forgotten: {"lat", "lon",
    // "acc", "at"}. The house answers with the place it knows it by (home,
    // work, out) or none yet. A house without this door answers 404.
    struct Heard: Decodable { let place: String? }

    func location(_ fix: CLLocation) async throws -> Heard {
        guard let whereURL = url("/v1/location") else { throw HouseError.noAddress }
        var request = URLRequest(url: whereURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        struct Fix: Encodable { let lat: Double; let lon: Double; let acc: Double; let at: String }
        request.httpBody = try JSONEncoder().encode(Fix(
            lat: fix.coordinate.latitude,
            lon: fix.coordinate.longitude,
            acc: fix.horizontalAccuracy,
            at: ISO8601DateFormatter().string(from: fix.timestamp)))
        let (data, response) = try await Self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HouseError.unreachable }
        if http.statusCode == 404 || http.statusCode == 405 { throw HouseError.noDoor }
        guard (200..<300).contains(http.statusCode) else { throw HouseError.unreachable }
        return (try? JSONDecoder().decode(Heard.self, from: data)) ?? Heard(place: nil)
    }

    // The three voices, each with its line and whether it is home. A house
    // without this door answers 404 and the study names the rooms alone.
    struct Voices: Decodable {
        struct Entry: Decodable {
            let name: String
            let line: String?
            let home: Bool?
        }
        let voices: [Entry]
    }

    func voices() async throws -> Voices {
        guard let url = url("/v1/voices") else { throw HouseError.noAddress }
        let (data, response) = try await Self.session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw HouseError.noDoor }
        return try JSONDecoder().decode(Voices.self, from: data)
    }

    func say(_ text: String, to voice: String = "chintan") async throws -> String {
        guard let sayURL = url("/v1/say") else { throw HouseError.noAddress }
        var request = URLRequest(url: sayURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["text": text, "to": voice])
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
