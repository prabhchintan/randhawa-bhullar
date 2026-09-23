// The walk's film cut into contact sheets: for every gesture the walk marked,
// one sheet of frames every 250 ms from just before the gesture until the
// screen has settled, each frame lettered with its offset. Run by walk.sh.
//
//   swift frames.swift FILM STEPS START OUTDIR
//     FILM   the walk's recording (simctl io recordVideo)
//     STEPS  the walk's log: epoch, kind, name per line, tab separated
//     START  the epoch at which the film's first frame was taken
import AppKit
import AVFoundation

let args = CommandLine.arguments
guard args.count == 5, let start = Double(args[3]) else {
    FileHandle.standardError.write(Data("usage: frames.swift FILM STEPS START OUTDIR\n".utf8))
    exit(2)
}
let film = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[4])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

struct Mark { let at: Double; let name: String }
let marks: [Mark] = try String(contentsOfFile: args[2], encoding: .utf8)
    .split(separator: "\n")
    .compactMap { line in
        let f = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard f.count == 3, f[1] == "mark", f[2] != "end", let t = Double(f[0]) else { return nil }
        return Mark(at: t - start, name: String(f[2]))
    }

let asset = AVURLAsset(url: film)
let length = try await asset.load(.duration).seconds
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero

// Nine frames: one before the gesture, the gesture, and two seconds after.
let offsets = stride(from: -0.25, through: 1.75, by: 0.25).map { $0 }
let cell = CGSize(width: 220, height: 478)
let gap: CGFloat = 8
let caption: CGFloat = 26
let title: CGFloat = 34

for (n, mark) in marks.enumerated() {
    var frames: [(Double, CGImage?)] = []
    for dt in offsets {
        let t = min(max(mark.at + dt, 0), max(length - 0.01, 0))
        let image = try? await generator.image(at: CMTime(seconds: t, preferredTimescale: 600)).image
        frames.append((dt, image))
    }
    let width = gap + CGFloat(frames.count) * (cell.width + gap)
    let height = title + cell.height + caption + gap
    let sheet = NSImage(size: NSSize(width: width, height: height))
    sheet.lockFocus()
    NSColor(white: 0.08, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    let heading: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 20, weight: .semibold), .foregroundColor: NSColor.white]
    let small: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .regular), .foregroundColor: NSColor(white: 0.75, alpha: 1)]
    String(format: "%@  at %.2f s in the film", mark.name, mark.at).draw(at: NSPoint(x: gap, y: height - title + 6), withAttributes: heading)
    for (i, (dt, image)) in frames.enumerated() {
        let x = gap + CGFloat(i) * (cell.width + gap)
        let rect = NSRect(x: x, y: caption, width: cell.width, height: cell.height)
        if let image {
            NSImage(cgImage: image, size: .zero).draw(in: rect)
        } else {
            NSColor(white: 0.2, alpha: 1).setFill()
            rect.fill()
        }
        String(format: "%+d ms", Int((dt * 1000).rounded())).draw(at: NSPoint(x: x + 4, y: 4), withAttributes: small)
    }
    sheet.unlockFocus()
    guard let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    let file = out.appendingPathComponent(String(format: "%02d-%@.png", n + 1, mark.name))
    try png.write(to: file)
    print(file.path)
}
