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
@main
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

// What the app shares with the widget through the App Group: the house
// address, and the last work hung in each frame, kept so an evening off the
// tailnet still has its picture.
enum Shared {
    static let group = "group.Prabhchintan.Chintan"

    static var house: String? {
        UserDefaults(suiteName: group)?.string(forKey: "houseAddress")
    }

    private static var folder: URL {
        let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = root.appendingPathComponent("wall", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func kept(_ frame: String) -> Hung? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(frame + ".json")),
              let record = try? JSONDecoder().decode(Record.self, from: data),
              let picture = UIImage(contentsOfFile: folder.appendingPathComponent(frame + ".jpg").path) else { return nil }
        return Hung(date: .now, record: record, picture: picture)
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
    static func fresh(_ frame: String) async -> Hung? {
        guard var address = Shared.house?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty else { return nil }
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
        Shared.keep(record, small, frame)
        return Hung(date: .now, record: record, picture: picture)
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

    // The house's word; the small frame has no room for the full card.
    private var letters: String {
        let word = work.record?.label?.lowercased() ?? "basic"
        return family == .systemSmall && word == "detailed" ? "basic" : word
    }

    private var margin: CGFloat { family == .systemSmall ? 11 : 14 }
    private var shade: CGFloat {
        switch family {
        case .systemSmall: return 150
        default: return letters == "detailed" ? 260 : 200
        }
    }
    private var titleSize: CGFloat { family == .systemSmall ? 11 : 13 }
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
            } else if !artist.isEmpty || !year.isEmpty {
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
