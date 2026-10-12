import CoreImage
import CryptoKit
import Foundation
import ImageIO
import SwiftUI
import UIKit

// One row of the feed as the house serves it: where it came from, what kind
// of thing it is, its title and text, a link and a picture when it has them,
// the house's score (90 and over is a slam dunk), and his mark on it.
// Read loosely, so a row the house letters a little differently still shows.
struct FeedRow: Codable, Identifiable, Equatable {
    let id: String
    let ts: String?
    let source: String
    let kind: String
    let title: String
    let url: String?
    let text: String
    let score: Double
    var status: String?
    let image: String?

    init?(_ d: [String: Any]) {
        func string(_ key: String) -> String? {
            switch d[key] {
            case let s as String: return s.isEmpty ? nil : s
            case let n as NSNumber: return n.stringValue
            default: return nil
            }
        }
        guard let id = string("id") else { return nil }
        self.id = id
        ts = string("ts")
        source = string("source") ?? "house"
        kind = string("kind") ?? ""
        let title = string("title") ?? ""
        let text = string("text") ?? ""
        guard !title.isEmpty || !text.isEmpty else { return nil }
        // A row with no title leads with its text.
        self.title = title.isEmpty ? text : title
        self.text = title.isEmpty ? "" : text
        url = string("url").flatMap { URL(string: $0)?.scheme?.hasPrefix("http") == true ? $0 : nil }
        score = (d["score"] as? NSNumber)?.doubleValue ?? Double(string("score") ?? "") ?? 0
        status = string("status")
        image = string("image")
    }

    var slamDunk: Bool { score >= 90 }
    // The day's painting, a card of its own.
    var art: Bool { kind.lowercased() == "art" }
    // On his profile: kept, and starred, which is kept and sent to the house.
    var kept: Bool { status == "kept" || status == "starred" }
    var starred: Bool { status == "starred" }

    // Read once per stamp and remembered: a card asks for its date on every
    // drawing, and a formatter made each time stalled the pane's opening
    // (sprint 67).
    var date: Date? {
        guard let ts else { return nil }
        return Self.when.withLock { known in
            if let d = known[ts] { return d }
            let d = Self.read(ts)
            known[ts] = .some(d)
            return d
        }
    }

    private static let when = Remembered<[String: Date?]>([:])
    private static let isoFraction: ISO8601DateFormatter = {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso
    }()
    private static let iso = ISO8601DateFormatter()
    // A time with no zone is the house's own, read as the phone's.
    private static let plain: [DateFormatter] = ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss"].map {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = $0
        return f
    }
    private static let relative = RelativeDateTimeFormatter()

    private static func read(_ ts: String) -> Date? {
        if let seconds = Double(ts) { return Date(timeIntervalSince1970: seconds > 1e11 ? seconds / 1000 : seconds) }
        if let d = isoFraction.date(from: ts) ?? iso.date(from: ts) { return d }
        for f in plain { if let d = f.date(from: ts) { return d } }
        return nil
    }

    // The time since, said the short way a timeline says it.
    func since(_ now: Date = .now) -> String {
        guard let date else { return "" }
        let s = max(0, now.timeIntervalSince(date))
        switch s {
        case ..<60: return "now"
        case ..<3600: return "\(Int(s / 60))m"
        case ..<86400: return "\(Int(s / 3600))h"
        case ..<(7 * 86400): return "\(Int(s / 86400))d"
        default: return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    // The same, in words for VoiceOver.
    func sinceSaid(_ now: Date = .now) -> String {
        guard let date else { return "" }
        return Self.relative.localizedString(for: date, relativeTo: now)
    }
}

// A value behind a lock, for what any thread may ask.
final class Remembered<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()
    init(_ value: Value) { self.value = value }
    func withLock<T>(_ body: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

// The feed on the phone: the house's rows and his kept ones, kept on the
// phone like the shelf so the pane opens at once, read again from the house
// when the copy is five minutes old or on a pull. Every mark shows at once
// and goes to the house behind it; what the house does not hear waits and
// goes when it answers; what it refuses goes back as it was, with a word.
@MainActor
final class FeedStore: ObservableObject {
    @Published private(set) var rows: [FeedRow] = []
    @Published private(set) var kept: [FeedRow] = []
    @Published private(set) var liked: Set<String> = []
    @Published private(set) var loaded = false
    @Published var word: String?
    private var at: Date?
    private var pending: [Mark] = []
    private var reading = false

    private struct Mark: Codable, Equatable {
        let id: String
        // "like", or the status posted.
        let what: String
    }

    private struct Saved: Codable {
        var rows: [FeedRow]
        var kept: [FeedRow]
        var liked: [String]
        var at: Date?
        var pending: [Mark]
    }

    private static let file: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("feed.json")
    }()

    private static let writer = DispatchQueue(label: "feed.save", qos: .utility)

    private var house: HouseClient? {
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else { return nil }
        return HouseClient(baseAddress: address)
    }

    // One copy for the app, so the pane rises on what Home has already read.
    static let shared = FeedStore()

    // While Home rests: the phone's copy read and decoded away from the
    // screen, and the first cards' pictures made ready, so the pane rises on
    // what is already in hand (the walk's "feed open", sprint 67).
    func warm() async {
        if !loaded {
            let file = Self.file
            let saved = await Task.detached(priority: .utility) { () -> Saved? in
                guard let data = try? Data(contentsOf: file) else { return nil }
                return try? JSONDecoder().decode(Saved.self, from: data)
            }.value
            if !loaded, let saved {
                rows = saved.rows
                kept = saved.kept
                liked = Set(saved.liked)
                at = saved.at
                pending = saved.pending
                loaded = true
            }
        }
        for row in rows.prefix(3) {
            guard let image = row.image else { continue }
            _ = await FeedPictures.shared.picture(image)
            if row.art { _ = await FeedPictures.shared.softPicture(image) }
        }
    }

    // On opening: the phone's copy at once, the house's when it is stale,
    // asked once the pane has risen so its rows never land mid-rise.
    func open() async {
        await warm()
        if let at, Date.now.timeIntervalSince(at) < 5 * 60 {
            await flush()
            return
        }
        try? await Task.sleep(for: .seconds(0.8))
        await refresh()
    }

    func refresh() async {
        guard let house else {
            word = "No house address yet. Add it in Settings."
            loaded = true
            return
        }
        guard !reading else { return }
        reading = true
        defer { reading = false }
        await flush()
        async let feed = Result { try await house.feed() }
        async let profile = Result { try await house.feedKept() }
        let (f, p) = await (feed, profile)
        switch f {
        case .success(var fresh):
            // A mark still on its way stands over what the house last said.
            for mark in pending where mark.what != "like" {
                if mark.what == "dismissed" { fresh.removeAll { $0.id == mark.id } }
                if let i = fresh.firstIndex(where: { $0.id == mark.id }) { fresh[i].status = mark.what }
            }
            // Only a changed list is drawn again.
            if rows != fresh { rows = fresh }
            if case .success(var profile) = p {
                for mark in pending where mark.what != "like" {
                    if let i = profile.firstIndex(where: { $0.id == mark.id }) {
                        if mark.what == "kept" || mark.what == "starred" { profile[i].status = mark.what } else { profile.remove(at: i) }
                    } else if mark.what == "kept" || mark.what == "starred", var row = fresh.first(where: { $0.id == mark.id }) {
                        row.status = mark.what
                        profile.insert(row, at: 0)
                    }
                }
                if kept != profile { kept = profile }
            }
            at = .now
            if word != nil { word = nil }
            FeedPictures.shared.keepOnly(rows + kept)
        case .failure(HouseError.noDoor):
            word = "The house does not keep a feed yet."
        case .failure:
            word = rows.isEmpty && kept.isEmpty
                ? "The house is not answering. Are you on the tailnet?"
                : "The house is not answering; this is the feed as it last was."
        }
        if !loaded { loaded = true }
        save()
    }

    // MARK: the marks

    func like(_ row: FeedRow) {
        guard !liked.contains(row.id) else { return }
        liked.insert(row.id)
        send(Mark(id: row.id, what: "like")) { $0.liked.remove(row.id) }
    }

    // The retweet mark: kept, or off his profile again.
    func toggleKeep(_ row: FeedRow) {
        mark(row, row.kept ? "seen" : "kept")
    }

    // The star: kept and sent to the house; off, it stays kept.
    func toggleStar(_ row: FeedRow) {
        mark(row, row.starred ? "kept" : "starred")
    }

    // Swiped away. `post` false only for the house's eyes, so a look never
    // takes a real row off his feed.
    func dismiss(_ row: FeedRow, post: Bool = true) {
        let before = (rows, kept)
        rows.removeAll { $0.id == row.id }
        kept.removeAll { $0.id == row.id }
        guard post else { return }
        save()
        send(Mark(id: row.id, what: "dismissed")) { store in
            store.rows = before.0
            store.kept = before.1
        }
    }

    // Opened or read: seen, once, and never over a keep.
    func seen(_ row: FeedRow) {
        let status = current(row.id)?.status
        guard status == nil || !["seen", "kept", "starred", "dismissed"].contains(status!) else { return }
        mark(row, "seen")
    }

    func current(_ id: String) -> FeedRow? {
        rows.first { $0.id == id } ?? kept.first { $0.id == id }
    }

    private func mark(_ row: FeedRow, _ status: String) {
        let before = (rows, kept)
        var marked = current(row.id) ?? row
        marked.status = status
        if let i = rows.firstIndex(where: { $0.id == row.id }) { rows[i].status = status }
        if marked.kept {
            if let i = kept.firstIndex(where: { $0.id == row.id }) { kept[i].status = status } else { kept.insert(marked, at: 0) }
        } else {
            kept.removeAll { $0.id == row.id }
        }
        send(Mark(id: row.id, what: status)) { store in
            store.rows = before.0
            store.kept = before.1
        }
    }

    private func send(_ mark: Mark, undo: @escaping (FeedStore) -> Void) {
        // The last status on a row is the one that counts.
        if mark.what != "like" { pending.removeAll { $0.id == mark.id && $0.what != "like" } }
        pending.append(mark)
        save()
        guard let house else { return }
        Task {
            let told = await post(mark, to: house)
            switch told {
            case .heard:
                pending.removeAll { $0 == mark }
            case .refused:
                pending.removeAll { $0 == mark }
                withAnimation(.snappy) { undo(self) }
                word = "The house would not take that; it is back as it was."
            case .unheard:
                break
            }
            save()
        }
    }

    private func post(_ mark: Mark, to house: HouseClient) async -> HouseClient.Told {
        mark.what == "like" ? await house.feedLike(mark.id) : await house.feedMark(mark.id, status: mark.what)
    }

    // What waited goes now, in the order it was made; it stops at the
    // first the house does not hear.
    private func flush() async {
        guard let house, !pending.isEmpty else { return }
        for mark in pending {
            let told = await post(mark, to: house)
            if told == .unheard { break }
            pending.removeAll { $0 == mark }
        }
        save()
    }

    private func save() {
        let saved = Saved(rows: rows, kept: kept, liked: Array(liked), at: at, pending: pending)
        let file = Self.file
        // Written in turn, away from the screen.
        Self.writer.async {
            try? JSONEncoder().encode(saved).write(to: file, options: .atomic)
        }
    }
}

// The feed's pictures, kept on the phone like the shelf's: brought down once,
// cut to the card's size, so a card scrolled back to or opened offline shows
// its picture at once. The house names each picture as a page's own image or
// a museum's open-access file; a house path is asked of the house, a picture
// elsewhere over https only, with no cookies and nothing of his sent. What
// leaves the feed leaves the phone.
@MainActor
final class FeedPictures {
    static let shared = FeedPictures()

    private var held: [String: UIImage] = [:]
    private var soft: [String: UIImage] = [:]
    private var asking: [String: Task<UIImage?, Never>] = [:]

    private static let folder: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = caches.appendingPathComponent("feed-pictures", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.httpShouldSetCookies = false
        return URLSession(configuration: config)
    }()

    private static func name(_ image: String) -> String {
        SHA256.hash(data: Data(image.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined() + ".jpg"
    }

    // The picture if it is already drawn this session, without waiting. A
    // kept file is never read here: read and decoded as the pane rose, it
    // stalled the pane's first frames (the walk's "feed open", sprint 66).
    func held(_ image: String) -> UIImage? {
        held[image]
    }

    func picture(_ image: String) async -> UIImage? {
        if let one = held(image) { return one }
        if let task = asking[image] { return await task.value }
        let file = Self.folder.appendingPathComponent(Self.name(image))
        let task = Task<UIImage?, Never> {
            // Kept on the phone: read and decoded away from the screen.
            if let one = await Task.detached(priority: .userInitiated, operation: {
                UIImage(contentsOfFile: file.path)?.preparingForDisplay()
            }).value {
                return one
            }
            guard let url = Self.source(image),
                  let (data, response) = try? await Self.session.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return await Task.detached(priority: .utility) { Self.cut(data, to: file) }.value
        }
        asking[image] = task
        let one = await task.value
        asking[image] = nil
        if let one { held[image] = one }
        return one
    }

    // The painting card's soft ground: the picture cut to a few dozen pixels
    // and blurred there once, away from the screen, then drawn large. A live
    // blur over the whole picture cost the pane's opening (sprint 67).
    func heldSoft(_ image: String) -> UIImage? {
        soft[image]
    }

    func softPicture(_ image: String) async -> UIImage? {
        if let one = soft[image] { return one }
        guard let whole = await picture(image), let cg = whole.cgImage else { return nil }
        let one = await Task.detached(priority: .userInitiated) { Self.soften(cg) }.value
        if let one { soft[image] = one }
        return one
    }

    nonisolated private static func soften(_ cg: CGImage) -> UIImage? {
        let long: CGFloat = 40
        let scale = long / CGFloat(max(cg.width, cg.height))
        let width = max(1, Int((CGFloat(cg.width) * scale).rounded()))
        let height = max(1, Int((CGFloat(cg.height) * scale).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let small = context.makeImage() else { return nil }
        let input = CIImage(cgImage: small)
        guard let blurred = input.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 2.5])
            .cropped(to: input.extent) as CIImage?,
              let out = CIContext(options: [.useSoftwareRenderer: false]).createCGImage(blurred, from: input.extent)
        else { return nil }
        return UIImage(cgImage: out)
    }

    // Only the pictures the feed and Kept still show stay on the phone.
    func keepOnly(_ rows: [FeedRow]) {
        let keep = Set(rows.compactMap { $0.image.map(Self.name) })
        let folder = Self.folder
        DispatchQueue.global(qos: .utility).async {
            for name in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] where !keep.contains(name) {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
            }
        }
        held = held.filter { keep.contains(Self.name($0.key)) }
        soft = soft.filter { keep.contains(Self.name($0.key)) }
    }

    private static func source(_ image: String) -> URL? {
        if image.hasPrefix("/") {
            guard let address = Keychain.loadHouseAddress(), !address.isEmpty else { return nil }
            return HouseClient(baseAddress: address).houseURL(image)
        }
        guard let url = URL(string: image), url.scheme == "https" else { return nil }
        return url
    }

    // A museum's print file runs to thousands of pixels; the card needs the
    // phone's width at 3x, so it is cut down once and kept at that size.
    nonisolated private static func cut(_ data: Data, to file: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1400,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let one = UIImage(cgImage: cg)
        if let jpeg = one.jpegData(compressionQuality: 0.85) { try? jpeg.write(to: file, options: .atomic) }
        return one
    }
}

private extension Result where Failure == Error {
    init(catching body: () async throws -> Success) async {
        do { self = .success(try await body()) } catch { self = .failure(error) }
    }
}
