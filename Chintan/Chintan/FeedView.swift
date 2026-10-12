import SafariServices
import SwiftUI

// The feed: things to look at with nothing asked of him, a timeline in the
// shape he knows from the bird, lettered for the museum. Each card names its
// source in gilt, its title in the serif, a few lines of its text, how long
// ago, and a picture when the house has one; under it three small marks, a
// heart (more of this), a retweet (kept on his profile) and a star (kept and
// sent to the house). A swipe left folds a card away. The second face, Kept,
// is his profile. (Prab, 2026-10-11, the study line: "like my personal
// twitter feed except made of things I need to look at doom scrolling which
// don't have any immediate actions or needs from me".)
struct FeedView: View {
    enum Face { case feed, kept }

    @ObservedObject private var store = FeedStore.shared
    @State var face: Face = .feed
    // For the house's eyes: what to do once the rows are in.
    var eyes: String?
    @State private var expanded: Set<String> = []
    @State private var link: Link?
    @State private var likes = 0
    @State private var keeps = 0

    struct Link: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    private var shown: [FeedRow] { face == .feed ? store.rows : store.kept }

    // The walk's swipe folds a card on the phone alone (`--feed-staged`),
    // so the eyes never take a real row off his feed.
    private static let staged = ProcessInfo.processInfo.arguments.contains("--feed-staged")

    var body: some View {
        ScrollViewReader { proxy in
        List {
            heading
                .listRowInsets(EdgeInsets(top: 26, leading: 22, bottom: 14, trailing: 22))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            if let word = store.word {
                Text(word)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .plaque()
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            if store.loaded && shown.isEmpty {
                Text(face == .feed ? "Nothing new to look at." : "Nothing kept yet.")
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(Theme.ink.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(shown) { row in
                FeedCard(row: row, liked: store.liked.contains(row.id), expanded: expanded.contains(row.id),
                         open: { open(row) }, like: { like(row) }, keep: { keep(row) }, star: { store.toggleStar(row) })
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation(.snappy) { store.dismiss(row, post: !Self.staged) }
                        } label: {
                            Label("Dismiss", systemImage: "xmark")
                        }
                        .tint(Theme.gilt)
                    }
                    .accessibilityAction(named: "Dismiss") { withAnimation(.snappy) { store.dismiss(row) } }
                    .id(row.id)
            }
            Color.clear
                .frame(height: 24)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                // Room at the foot, nothing to read.
                .accessibilityHidden(true)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        // A short fade at the foot, so the first card's marks read at rest.
        .fadedEdges(top: 18, bottom: 12)
        .accessibilityIdentifier("timeline")
        .refreshable { await store.refresh() }
        .task {
            await store.open()
            await look(proxy)
        }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: likes)
        .sensoryFeedback(.selection, trigger: keeps)
        .fullScreenCover(item: $link) { link in
            SafariView(url: link.url) { self.link = nil }
                .ignoresSafeArea()
        }
    }

    // The pane's two faces, the feed and his profile; the name he tapped on
    // Home is the pane's name, so it is not lettered again here.
    private var heading: some View {
        // On the last baseline, so the away line's second line, if it has
        // one, rises into the room above rather than lowering the names.
        HStack(alignment: .lastTextBaseline, spacing: 22) {
            faceButton("Feed", .feed)
            faceButton("Kept", .kept)
            // Away from the house, one thin line on the heading's baseline
            // says where the rows came from, so the first card keeps its room.
            if face == .feed, let away = store.away {
                Spacer(minLength: 0)
                Text(Self.said(away))
                    .font(.caption)
                    .foregroundStyle(Theme.ink.opacity(0.62))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .layoutPriority(-1)
                    .accessibilityIdentifier("feed-away")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func faceButton(_ name: String, _ which: Face) -> some View {
        Button {
            withAnimation(.snappy) { face = which }
        } label: {
            Text(name)
                .font(Theme.title())
                .foregroundStyle(Theme.ink.opacity(face == which ? 1 : 0.38))
                .padding(.bottom, 6)
                .overlay(alignment: .bottom) {
                    if face == which {
                        Rectangle().fill(Theme.gilt).frame(height: 1)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityAddTraits(face == which ? .isSelected : [])
        .accessibilityIdentifier("feed-face-\(name.lowercased())")
    }

    private static func said(_ away: FeedStore.Away) -> String {
        guard case .stale(let pushed) = away else { return "from the road" }
        guard let pushed else { return "the house has not pushed lately" }
        let when = Calendar.current.isDateInToday(pushed)
            ? pushed.formatted(date: .omitted, time: .shortened)
            : pushed.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        return "the house has not pushed since " + when
    }

    private func open(_ row: FeedRow) {
        store.seen(row)
        if let s = row.url, let url = URL(string: s) {
            link = Link(url: url)
        } else {
            withAnimation(.snappy) {
                if expanded.contains(row.id) { expanded.remove(row.id) } else { expanded.insert(row.id) }
            }
        }
    }

    private func like(_ row: FeedRow) {
        guard !store.liked.contains(row.id) else { return }
        withAnimation(.snappy) { store.like(row) }
        likes += 1
    }

    private func keep(_ row: FeedRow) {
        withAnimation(.snappy) { store.toggleKeep(row) }
        keeps += 1
    }

    // For the house's eyes, on the first row: `feed-like` likes it,
    // `feed-keep` keeps it and turns to Kept, `feed-unkeep` takes that one off
    // again, `feed-fold` folds it away without telling the
    // house, `feed-open` opens the first with a link, `feed-read` the first
    // without one; `feed-picture` scrolls to the first card of words with a
    // picture.
    private func look(_ proxy: ScrollViewProxy) async {
        guard let eyes else { return }
        try? await Task.sleep(for: .seconds(1.2))
        switch eyes {
        case "feed-like":
            if let row = store.rows.first(where: { !store.liked.contains($0.id) }) { like(row) }
        case "feed-keep":
            if let row = store.rows.first(where: { !$0.kept }) {
                keep(row)
                UserDefaults.standard.set(row.id, forKey: "feed.eyes.kept")
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.snappy) { face = .kept }
            }
        case "feed-unkeep":
            // Only what `feed-keep` kept, so his own keeps stay.
            face = .kept
            try? await Task.sleep(for: .seconds(1))
            let id = UserDefaults.standard.string(forKey: "feed.eyes.kept")
            if let row = store.kept.first(where: { $0.id == id }) { keep(row) }
        case "feed-fold":
            if let row = store.rows.first { withAnimation(.snappy) { store.dismiss(row, post: false) } }
        case "feed-open":
            if let row = store.rows.first(where: { $0.url != nil }) { open(row) }
        case "feed-picture":
            if let row = store.rows.first(where: { $0.image != nil && !$0.art }) {
                withAnimation(.snappy) { proxy.scrollTo(row.id, anchor: .top) }
            }
        case "feed-read":
            if let row = store.rows.first(where: { $0.url == nil }) { open(row) }
        default:
            break
        }
    }
}

// The pane's glass. In light the painting seen through bare glass read as
// brown, so a bone wash lies over it; in dark the glass alone.
struct PaneGlass: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(scheme == .light ? Theme.bone.opacity(0.9) : .clear)
    }
}

// One card on the timeline.
private struct FeedCard: View {
    let row: FeedRow
    let liked: Bool
    let expanded: Bool
    let open: () -> Void
    let like: () -> Void
    let keep: () -> Void
    let star: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        face
            .accessibilityElement(children: .ignore)
        .accessibilityLabel(said)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(row.url == nil ? "Reads the whole of it." : row.art ? "Opens the museum's page." : "Opens the link.")
        .accessibilityAction(.default, open)
        .accessibilityAction(named: liked ? "Liked" : "Like", like)
        .accessibilityAction(named: row.kept ? "Take off Kept" : "Keep", keep)
        .accessibilityAction(named: row.starred ? "Unstar" : "Star, for the house", star)
        .accessibilityIdentifier("feed-card")
    }

    @ViewBuilder private var face: some View {
        if row.art, let image = row.image {
            painting(image)
        } else {
            plain
        }
    }

    // A card of words, its picture at its head when the house has one, edge
    // to edge and held to 16:10 from the first paint.
    private var plain: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let image = row.image {
                FeedPicture(image: image)
                    .aspectRatio(16 / 10, contentMode: .fit)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.gilt.opacity(0.4)).frame(height: 0.5)
                    }
            }
            VStack(alignment: .leading, spacing: 8) {
                head(source: Theme.gilt, quiet: Theme.ink.opacity(0.55))
                Text(row.title)
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !row.text.isEmpty {
                    FeedText(text: row.text, expanded: expanded)
                }
                marks(Theme.gilt, quiet: Theme.ink.opacity(0.35))
            }
            .padding(.top, 14)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            // A slam dunk carries a thin gilt rule down its left edge.
            .overlay(alignment: .leading) {
                if row.slamDunk {
                    Rectangle()
                        .fill(Theme.gilt)
                        .frame(width: 2)
                        .padding(.vertical, 14)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .plaque()
    }

    // The day's painting: the picture to the card's edges, whole, over its
    // own colours drawn soft, and the label on a smoked mount at its foot,
    // the way the label sits under the painting on Home. A tap opens the
    // museum's page.
    private func painting(_ image: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            FeedPicture(image: image, whole: true)
                .aspectRatio(4 / 5, contentMode: .fit)
            VStack(alignment: .leading, spacing: 8) {
                head(source: Theme.giltOnArt, quiet: Theme.bone.opacity(0.6))
                Text(row.title)
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(Theme.bone)
                    .fixedSize(horizontal: false, vertical: true)
                if !row.text.isEmpty {
                    Text(row.text)
                        .font(.footnote)
                        .foregroundStyle(Theme.bone.opacity(0.72))
                        .lineLimit(expanded ? nil : 3)
                }
                marks(Theme.giltOnArt, quiet: Theme.bone.opacity(0.4))
            }
            .padding(.top, 14)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Theme.lampBlack.opacity(0.68))
                    .environment(\.colorScheme, .dark)
            }
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.giltOnArt.opacity(0.45)).frame(height: 0.5)
            }
            .overlay(alignment: .leading) {
                if row.slamDunk {
                    Rectangle()
                        .fill(Theme.giltOnArt)
                        .frame(width: 2)
                        .padding(.vertical, 14)
                }
            }
        }
        .background { FeedPicture(image: image, ground: true) }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.giltOnArt.opacity(0.55), lineWidth: 0.5))
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.lampBlack)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
    }

    private var said: String {
        var bits = [row.source, row.kind].filter { !$0.isEmpty }.joined(separator: ", ")
        if row.slamDunk { bits += ", a slam dunk" }
        return [bits, row.title, row.text, row.sinceSaid()].filter { !$0.isEmpty }.joined(separator: ". ")
    }

    // The source in gilt, the kind beside it, the time since at the right;
    // at the largest sizes the time takes its own line.
    private func head(source: Color, quiet: Color) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(row.source)
                    .font(Theme.label(.caption))
                    .tracking(1)
                    .foregroundStyle(source)
                // A kind that only repeats its source is said once.
                if !row.kind.isEmpty, row.kind.lowercased() != row.source.lowercased() {
                    Text(row.kind)
                        .font(Theme.label(.caption))
                        .tracking(0.6)
                        .foregroundStyle(quiet)
                }
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(row.since())
                .font(.caption)
                .foregroundStyle(quiet)
        }
    }

    private func marks(_ tint: Color, quiet: Color) -> some View {
        HStack(spacing: 0) {
            mark(liked ? "heart.fill" : "heart", on: liked, tint: tint, action: like)
            mark("arrow.2.squarepath", on: row.kept, tint: tint, action: keep)
            mark(row.starred ? "star.fill" : "star", on: row.starred, tint: tint, action: star)
            Spacer(minLength: 0)
            if row.url != nil {
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(quiet)
            }
        }
        .padding(.leading, -12)
    }

    private func mark(_ symbol: String, on: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                // The retweet mark has no filled glyph, so a mark that is on
                // is drawn heavier and in full gilt, one that is off is faint.
                .font(.footnote.weight(on ? .bold : .regular))
                .foregroundStyle(tint.opacity(on ? 1 : 0.6))
                .symbolEffect(.bounce, value: on)
                .frame(minWidth: 52, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }
}

// The text, four lines and a fade, or the whole of it once read.
private struct FeedText: View {
    let text: String
    let expanded: Bool
    @State private var whole: CGFloat = 0
    @State private var shown: CGFloat = 0

    private var cut: Bool { !expanded && whole > shown + 1 }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(Theme.ink.opacity(0.82))
            .lineLimit(expanded ? nil : 4)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { shown = $0 }
            .background(alignment: .topLeading) {
                Text(text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { whole = $0 }
            }
            .mask {
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .black.opacity(cut ? 0.1 : 1)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 22)
                }
            }
    }
}

// A row's picture from the phone's copy, or brought down and faded in. The
// frame it fills is the card's from the first paint, smoked glass until the
// picture comes, so nothing below it moves. `whole` shows a painting entire,
// never cropped; `ground` is the same picture drawn soft behind it.
private struct FeedPicture: View {
    let image: String
    var whole = false
    var ground = false
    @State private var picture: UIImage?

    init(image: String, whole: Bool = false, ground: Bool = false) {
        self.image = image
        self.whole = whole
        self.ground = ground
        _picture = State(initialValue: ground ? FeedPictures.shared.heldSoft(image) : FeedPictures.shared.held(image))
    }

    var body: some View {
        // A whole painting stands over its own ground, which carries the glass.
        Rectangle()
            .fill(whole ? AnyShapeStyle(Color.clear) : AnyShapeStyle(.ultraThinMaterial))
            .overlay(whole ? .clear : Theme.lampBlack.opacity(ground ? 0.7 : 0.2))
            .environment(\.colorScheme, .dark)
            .overlay {
                if let picture {
                    if ground {
                        // A small cut, already soft, drawn large.
                        Image(uiImage: picture)
                            .resizable()
                            .interpolation(.medium)
                            .scaledToFill()
                            .overlay(Theme.lampBlack.opacity(0.35))
                            .transition(.opacity)
                    } else if whole {
                        Image(uiImage: picture)
                            .resizable()
                            .scaledToFit()
                            .transition(.opacity)
                    } else {
                        Image(uiImage: picture)
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
            .task(id: image) {
                guard picture == nil else { return }
                let pictures = FeedPictures.shared
                guard let one = await (ground ? pictures.softPicture(image) : pictures.picture(image)) else { return }
                withAnimation(.easeOut(duration: 0.45)) { picture = one }
            }
    }
}

// A link read inside the app, the way the bird opens one.
private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    let done: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let done: () -> Void
        init(done: @escaping () -> Void) { self.done = done }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) { done() }
    }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safari = SFSafariViewController(url: url)
        safari.delegate = context.coordinator
        safari.preferredControlTintColor = UIColor(Theme.gilt)
        safari.dismissButtonStyle = .done
        return safari
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
