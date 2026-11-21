import ImageIO
import SwiftUI
import UIKit
import WidgetKit

// The wall on the home screen (Prab, 2026-09-27 19:26: "i want it as a
// widget on the iphone"). The house does the composing: each refresh asks
// `GET /v1/wall/next?frame=large|medium|small` for one fresh work off the
// walls' own loop, already cut at the phone's size for that frame, and the
// widget hangs it edge to edge, lettered as the house says. Off the tailnet
// it keeps the last picture it hung, never a blank.
// Two widgets since 2026-11-21 (Prab: "the two widgets provide me art and
// insightful info about my day to day life as I peek the two widgets in
// passing"): the wall, and the day in the medium frame beside it.
@main
struct ChintanWidgets: WidgetBundle {
    var body: some Widget {
        ChintanWall()
        ChintanDay()
    }
}

struct ChintanWall: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "wall", provider: Hanger()) { work in
            WallFace(work: work)
        }
        .configurationDisplayName("The wall")
        .description("A painting from the house, turned through the day.")
        .supportedFamilies([.systemLarge, .systemMedium, .systemSmall])
        .contentMarginsDisabled()
    }
}

// One work as the widget hangs it: the house's record and its picture.
struct Hung: TimelineEntry {
    let date: Date
    let record: Record?
    let picture: UIImage?
    var line: Said? = nil
    var glance: Glance? = nil
}

// The widgets' one ask of the house (GET /v1/glance): the hour's line, the
// Imbox in three lines, and his day in three. Every part is short: a peek.
struct Glance: Codable {
    struct Mail: Codable {
        struct Line: Codable {
            let who: String
            let subject: String
        }
        let count: Int
        let lines: [Line]
        var known: Bool?
    }
    struct Day: Codable {
        struct Row: Codable {
            let k: String
            let t: String
            var hot: Bool?
        }
        let kicker: String
        let lines: [Row]
    }
    var line: Said?
    var mail: Mail?
    var day: Day?
}

// Home's one line as the house gives it (GET /v1/mirror, since 2026-11-20):
// whose it is, and a dozen words at most. The widget is where a three second
// look lands first, so the line hangs here too, on the larger frames.
struct Said: Codable {
    let kicker: String
    let text: String
}

// The house's record, the fields the widget letters.
struct Record: Codable {
    let id: String?
    let title: String?
    let artist: String?
    let year: String?
    let credit: String?
    let medium: String?
    let source: String?
    let label: String?
    let image: String?
}

// The last work hung in each frame, kept in the widget's own container so an
// evening off the tailnet still has its picture. The widget shares nothing
// with the app: it asks the house the build names (House.address) itself.
enum Shared {
    private static var folder: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = root.appendingPathComponent("wall", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func kept(_ frame: String) -> Hung? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(frame + ".json")),
              let record = try? JSONDecoder().decode(Record.self, from: data),
              let picture = UIImage(contentsOfFile: folder.appendingPathComponent(frame + ".jpg").path) else { return nil }
        return Hung(date: .now, record: record, picture: picture, line: keptLine(), glance: keptGlance())
    }

    // The glance as last heard. His day is good for a day; the Imbox goes
    // stale sooner, so past three hours it is left off rather than shown old.
    static func keptGlance() -> Glance? {
        let file = folder.appendingPathComponent("glance.json")
        guard let made = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date,
              Date.now.timeIntervalSince(made) < 86400,
              let data = try? Data(contentsOf: file),
              var glance = try? JSONDecoder().decode(Glance.self, from: data) else { return nil }
        if Date.now.timeIntervalSince(made) > 3 * 3600 { glance.mail = nil }
        return glance
    }

    static func keep(_ glance: Glance) {
        try? JSONEncoder().encode(glance).write(to: folder.appendingPathComponent("glance.json"), options: .atomic)
    }

    // The line as last heard, good for a day; an older one is left off.
    static func keptLine() -> Said? {
        let file = folder.appendingPathComponent("line.json")
        guard let made = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date,
              Date.now.timeIntervalSince(made) < 86400,
              let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(Said.self, from: data)
    }

    static func keep(_ line: Said) {
        try? JSONEncoder().encode(line).write(to: folder.appendingPathComponent("line.json"), options: .atomic)
    }

    static func keep(_ record: Record, _ jpeg: Data, _ frame: String) {
        try? jpeg.write(to: folder.appendingPathComponent(frame + ".jpg"), options: .atomic)
        try? JSONEncoder().encode(record).write(to: folder.appendingPathComponent(frame + ".json"), options: .atomic)
    }
}

struct Hanger: TimelineProvider {
    // WidgetKit allows some 40 to 70 refreshes a day; a quarter hour asked
    // lands at twenty to thirty minutes, and the app asks again on opening.
    private static let pace: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> Hung {
        Shared.kept(Self.frame(context.family)) ?? Hung(date: .now, record: nil, picture: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (Hung) -> Void) {
        let frame = Self.frame(context.family)
        if let kept = Shared.kept(frame) { return completion(kept) }
        Task { completion(await Self.fresh(frame) ?? Hung(date: .now, record: nil, picture: nil)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Hung>) -> Void) {
        let frame = Self.frame(context.family)
        Task {
            let work = await Self.fresh(frame) ?? Shared.kept(frame) ?? Hung(date: .now, record: nil, picture: nil)
            completion(Timeline(entries: [work], policy: .after(.now.addingTimeInterval(Self.pace))))
        }
    }

    static func frame(_ family: WidgetFamily) -> String {
        switch family {
        case .systemSmall: return "small"
        case .systemMedium: return "medium"
        default: return "large"
        }
    }

    // The house's next work for this frame, brought down, kept and hung;
    // nil when the house is out of reach.
    static func fresh(_ frame: String, keptAs: String? = nil) async -> Hung? {
        guard var address = House.address?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty else { return nil }
        if !address.contains("://") { address = "http://" + address }
        while address.hasSuffix("/") { address.removeLast() }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        let session = URLSession(configuration: config)
        guard let asked = URL(string: address + "/v1/wall/next?frame=" + frame),
              let (data, answer) = try? await session.data(from: asked),
              (answer as? HTTPURLResponse)?.statusCode == 200,
              let record = try? JSONDecoder().decode(Record.self, from: data),
              let path = record.image, let url = URL(string: address + path),
              let (jpeg, said) = try? await session.data(from: url),
              (said as? HTTPURLResponse)?.statusCode == 200,
              let picture = fitted(jpeg) else { return nil }
        let small = picture.jpegData(compressionQuality: 0.88) ?? jpeg
        Shared.keep(record, small, keptAs ?? frame)
        // The glance rides the same ask: the hour's line, the Imbox, his day.
        // A house without the door leaves the last one.
        if let asked = URL(string: address + "/v1/glance"),
           let (data, answer) = try? await session.data(from: asked),
           (answer as? HTTPURLResponse)?.statusCode == 200,
           let glance = try? JSONDecoder().decode(Glance.self, from: data) {
            Shared.keep(glance)
            if let line = glance.line { Shared.keep(line) }
        }
        return Hung(date: .now, record: record, picture: picture, line: Shared.keptLine(), glance: Shared.keptGlance())
    }

    // Decoded at no more than the large frame's own size: a widget that
    // carries a bigger picture than its archive allows is drawn blank.
    private static func fitted(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 1146,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// The picture edge to edge, the label bottom right over a short shade the
// way the walls letter it; a tap opens chintan on the painting alone.
struct WallFace: View {
    let work: Hung
    @Environment(\.widgetFamily) private var family

    private static let bone = Color(red: 0.925, green: 0.910, blue: 0.875)
    private static let lampBlack = Color(red: 0.071, green: 0.067, blue: 0.063)
    private static let gilt = Color(red: 0.788, green: 0.647, blue: 0.373)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if work.picture == nil {
                empty
            } else if letters != "off", let record = work.record, record.title != nil {
                RadialGradient(colors: [Self.lampBlack.opacity(0.66), Self.lampBlack.opacity(0)],
                               center: .bottomTrailing, startRadius: 0, endRadius: shade)
                label(record)
                    .shadow(color: .black.opacity(0.5), radius: 3)
                    .padding(.trailing, margin)
                    .padding(.bottom, margin)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        // The day's line at the head, on the frames with room for it.
        .overlay(alignment: .topLeading) {
            if family != .systemSmall, work.picture != nil, letters != "off", let line = work.line {
                ZStack(alignment: .topLeading) {
                    RadialGradient(colors: [Self.lampBlack.opacity(0.66), Self.lampBlack.opacity(0)],
                                   center: .topLeading, startRadius: 0, endRadius: 220)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plain(line.kicker))
                            .font(.system(size: 9, design: .serif).smallCaps())
                            .tracking(0.8)
                            .foregroundStyle(Self.gilt)
                            .lineLimit(1)
                        Text(plain(line.text))
                            .font(.system(size: 12.5, design: .serif).italic())
                            .foregroundStyle(Self.bone)
                            .lineLimit(3)
                    }
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.5), radius: 3)
                    .frame(maxWidth: family == .systemLarge && mail != nil ? 172 : 210, alignment: .leading)
                    .padding(.leading, margin)
                    .padding(.top, margin)
                }
            }
        }
        // The Imbox at the head's other end, on the large frame: how many
        // wait and the newest three, so the mail's own widget can go.
        .overlay(alignment: .topTrailing) {
            if family == .systemLarge, work.picture != nil, letters != "off", let mail {
                ZStack(alignment: .topTrailing) {
                    RadialGradient(colors: [Self.lampBlack.opacity(0.66), Self.lampBlack.opacity(0)],
                                   center: .topTrailing, startRadius: 0, endRadius: mail.lines.isEmpty ? 110 : 190)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(mail.count == 0 ? "Imbox clear" : "Imbox \u{00B7} \(mail.count)")
                            .font(.system(size: 9, design: .serif).smallCaps())
                            .tracking(0.8)
                            .foregroundStyle(Self.gilt)
                            .lineLimit(1)
                        ForEach(Array(mail.lines.prefix(3).enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(plain(row.who))
                                    .font(.system(size: 10.5, design: .serif).weight(.semibold))
                                    .foregroundStyle(Self.bone)
                                    .lineLimit(1)
                                Text(plain(row.subject))
                                    .font(.system(size: 9.5, design: .serif).italic())
                                    .foregroundStyle(Self.bone.opacity(0.82))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .multilineTextAlignment(.trailing)
                    .shadow(color: .black.opacity(0.5), radius: 3)
                    .frame(maxWidth: 132, alignment: .trailing)
                    .padding(.trailing, margin)
                    .padding(.top, margin)
                }
            }
        }
        .containerBackground(for: .widget) {
            if let picture = work.picture {
                Image(uiImage: picture)
                    .resizable()
                    .scaledToFill()
            } else {
                Self.lampBlack
            }
        }
        .widgetURL(URL(string: "chintan://painting/" + (work.record?.id ?? "")))
    }

    // The Imbox as the house last read it; nil when the house could not read it.
    private var mail: Glance.Mail? {
        guard let mail = work.glance?.mail, mail.known != false else { return nil }
        return mail
    }

    // The house's word; the small frame has no room for the full card.
    private var letters: String {
        let word = work.record?.label?.lowercased() ?? "basic"
        return family == .systemSmall && word == "detailed" ? "basic" : word
    }

    private var margin: CGFloat { family == .systemSmall ? 10 : 14 }
    private var shade: CGFloat {
        switch family {
        case .systemSmall: return 120
        default: return letters == "detailed" ? 260 : 200
        }
    }
    private var titleSize: CGFloat { family == .systemSmall ? 10.5 : 13 }
    private var restSize: CGFloat { family == .systemSmall ? 9 : 10 }
    private var width: CGFloat { family == .systemSmall ? 130 : family == .systemMedium ? 170 : 210 }

    private func label(_ r: Record) -> some View {
        let title = plain(r.title), artist = plain(r.artist), year = plain(r.year)
        return VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.system(size: titleSize, design: .serif).italic())
                .foregroundStyle(Self.bone)
                .lineLimit(family == .systemSmall ? 2 : 3)
            if letters == "detailed" {
                if !artist.isEmpty {
                    Text(artist).font(.system(size: restSize, design: .serif)).foregroundStyle(Self.bone.opacity(0.9))
                }
                if !year.isEmpty {
                    Text(year).font(.system(size: restSize, design: .serif).smallCaps()).tracking(0.6).foregroundStyle(Self.gilt)
                }
                if !plain(r.medium).isEmpty {
                    Text(plain(r.medium)).font(.system(size: restSize, design: .serif))
                        .foregroundStyle(Self.bone.opacity(0.78)).padding(.top, 2)
                }
                if !plain(r.credit).isEmpty {
                    Text(plain(r.credit)).font(.system(size: restSize, design: .serif)).foregroundStyle(Self.bone.opacity(0.66))
                }
            } else if family != .systemSmall, !artist.isEmpty || !year.isEmpty {
                // The small square letters the title alone; the rest crowds the work.
                (Text(artist).foregroundStyle(Self.bone.opacity(0.88))
                 + Text(!artist.isEmpty && !year.isEmpty ? ", " : "").foregroundStyle(Self.bone.opacity(0.88))
                 + Text(year).foregroundStyle(Self.gilt))
                    .font(.system(size: restSize, design: .serif))
                    .lineLimit(2)
            }
        }
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: width, alignment: .trailing)
    }

    // Before the house has ever hung one here: the wall's ground and one
    // quiet line, never a blank.
    private var empty: some View {
        VStack(spacing: 6) {
            Text("chintan")
                .font(.system(size: 12, design: .serif).lowercaseSmallCaps())
                .tracking(1.2)
                .foregroundStyle(Self.gilt)
            Text("The painting comes when the house is in reach.")
                .font(.system(size: 11, design: .serif).italic())
                .foregroundStyle(Self.bone.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // The museums' dashes, lettered as the house's plain hyphen and comma.
    private func plain(_ s: String?) -> String {
        (s ?? "").replacingOccurrences(of: "\u{2014}", with: ", ").replacingOccurrences(of: "\u{2013}", with: "-")
    }
}

// The day, in the medium frame (2026-11-21): a work off the same loop behind,
// and his day in three short lines over it, as the house composes them: what
// waits on his word first, the next dated thing, then his own numbers, which
// turn by the hour. A peek in passing, never a list to work through.
struct ChintanDay: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "day", provider: DayHanger()) { work in
            DayFace(work: work)
        }
        .configurationDisplayName("The day")
        .description("Your day in three lines, over a painting.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct DayHanger: TimelineProvider {
    private static let pace: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> Hung {
        Shared.kept("day") ?? Hung(date: .now, record: nil, picture: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (Hung) -> Void) {
        if let kept = Shared.kept("day") { return completion(kept) }
        Task { completion(await Hanger.fresh("medium", keptAs: "day") ?? Hung(date: .now, record: nil, picture: nil)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Hung>) -> Void) {
        Task {
            let work = await Hanger.fresh("medium", keptAs: "day") ?? Shared.kept("day") ?? Hung(date: .now, record: nil, picture: nil)
            completion(Timeline(entries: [work], policy: .after(.now.addingTimeInterval(Self.pace))))
        }
    }
}

struct DayFace: View {
    let work: Hung

    private static let bone = Color(red: 0.925, green: 0.910, blue: 0.875)
    private static let lampBlack = Color(red: 0.071, green: 0.067, blue: 0.063)
    private static let gilt = Color(red: 0.788, green: 0.647, blue: 0.373)
    private static let saffron = Color(red: 0.898, green: 0.588, blue: 0.180)

    var body: some View {
        ZStack(alignment: .leading) {
            // The lines stand on a shade drawn from their side; the work is whole on the other.
            LinearGradient(stops: [.init(color: Self.lampBlack.opacity(0.86), location: 0),
                                   .init(color: Self.lampBlack.opacity(0.62), location: 0.5),
                                   .init(color: Self.lampBlack.opacity(0), location: 0.82)],
                           startPoint: .leading, endPoint: .trailing)
            if let day = work.glance?.day, !day.lines.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text(plain(day.kicker))
                        .font(.system(size: 10, design: .serif).smallCaps())
                        .tracking(1)
                        .foregroundStyle(Self.bone.opacity(0.7))
                        .lineLimit(1)
                    ForEach(Array(day.lines.prefix(3).enumerated()), id: \.offset) { _, row in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(plain(row.k))
                                .font(.system(size: 8.5, design: .serif).smallCaps())
                                .tracking(0.9)
                                .foregroundStyle(row.hot == true ? Self.saffron : Self.gilt)
                                .lineLimit(1)
                            Text(plain(row.t))
                                .font(.system(size: 12.5, design: .serif))
                                .foregroundStyle(Self.bone)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
                .shadow(color: .black.opacity(0.5), radius: 3)
                .frame(maxWidth: 232, alignment: .leading)
                .padding(.leading, 16)
                .padding(.vertical, 12)
            } else {
                Text(work.picture == nil ? "The day comes when the house is in reach." : "")
                    .font(.system(size: 11, design: .serif).italic())
                    .foregroundStyle(Self.bone.opacity(0.72))
                    .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // The work's name, small at the foot's far end.
        .overlay(alignment: .bottomTrailing) {
            if let title = work.record?.title, work.picture != nil {
                Text(plain(title))
                    .font(.system(size: 9, design: .serif).italic())
                    .foregroundStyle(Self.bone.opacity(0.85))
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.7), radius: 3)
                    .frame(maxWidth: 110, alignment: .trailing)
                    .padding(.trailing, 12)
                    .padding(.bottom, 9)
            }
        }
        .containerBackground(for: .widget) {
            if let picture = work.picture {
                Image(uiImage: picture)
                    .resizable()
                    .scaledToFill()
            } else {
                Self.lampBlack
            }
        }
        .widgetURL(URL(string: "chintan://painting/" + (work.record?.id ?? "")))
    }

    private func plain(_ s: String?) -> String {
        (s ?? "").replacingOccurrences(of: "\u{2014}", with: ", ").replacingOccurrences(of: "\u{2013}", with: "-")
    }
}
