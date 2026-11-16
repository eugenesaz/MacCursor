import CoreGraphics
import Foundation
import ImageIO
import MacCursorCore
import QuartzCore
import UniformTypeIdentifiers

/// Offscreen renders of the pointer art, for design review and README images.
public enum SnapshotRenderer {
    /// One snapshot case: what to draw and on which background.
    public struct Case: Sendable {
        public let pack: StylePack
        public let palette: PaletteKind
        public let size: Double
        public let click: Bool
        /// 0…1 share of the full tail. Only non-default lengths appear in the name.
        public var tailLength: Double = 1

        public var name: String {
            let bg = palette == .forLightScreens ? "light-screen" : "dark-screen"
            let tail = tailLength == 1 ? "" : "-tail\(String(format: "%.2f", tailLength))"
            return
                "\(pack.id)-\(bg)-\(String(format: "%.2f", size))x-\(click ? "click" : "idle")\(tail)"
        }
    }

    /// Every pack × palette at three sizes idle, plus a click at the default size.
    /// Packs with a tail also get no tail and a short tail at the default size.
    public static func cases(for packs: [StylePack]) -> [Case] {
        packs.flatMap { pack in
            [PaletteKind.forLightScreens, .forDarkScreens].flatMap { palette in
                [0.4, 0.75, 1.6].map {
                    Case(pack: pack, palette: palette, size: $0, click: false)
                }
                    + [Case(pack: pack, palette: palette, size: 0.75, click: true)]
                    + (pack.hasTail ? [0, 0.2] : []).map {
                        Case(
                            pack: pack, palette: palette, size: 0.75, click: false,
                            tailLength: $0)
                    }
            }
        }
    }

    /// Writes a PNG of every case to `directory`, for design review.
    public static func run(directory: String, packs: [StylePack]) {
        let dir = URL(fileURLWithPath: directory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for c in cases(for: packs) {
            let url = dir.appendingPathComponent("\(c.name).png")
            if let image = image(for: c) { writePNG(image, to: url) }
            print(url.path)
        }
    }

    /// Renders one case at 2× into an sRGB bitmap. Deterministic: the click effect is seeded.
    public static func image(for c: Case) -> CGImage? {
        let canvas = CGSize(width: 260, height: 300)
        let pixelScale: CGFloat = 2
        let palette = Palette.of(c.palette)
        let root = CALayer()
        root.anchorPoint = .zero
        root.bounds = CGRect(origin: .zero, size: canvas)
        root.backgroundColor = c.palette == .forLightScreens ? rgb(0xF5F5F5) : rgb(0x262626)

        let pack = c.pack
        // A shortened tail is drawn higher up, so all of it fits on the canvas.
        let tip = CGPoint(x: 120, y: c.tailLength < 1 ? 250 : 200)
        let angle: CGFloat = 18 * .pi / 180
        let scale = CGFloat(c.size)
        if c.click {
            let fx = ClickEffect(
                tip: tip, angle: angle, pack: pack, palette: palette, intensity: 2.6,
                scale: scale, contentsScale: pixelScale, start: 0, seed: 42)
            fx.render(t: 0.22)
            root.addSublayer(fx.layer)
        }
        let rig = PointerRig(contentsScale: pixelScale)
        rig.apply(pack: pack, palette: palette, tailLength: CGFloat(c.tailLength))
        rig.setPose(
            position: tip, angle: angle, scale: scale, squash: c.click && !pack.overlay ? 0.8 : 0)
        root.addSublayer(rig.root)

        guard
            let ctx = CGContext(
                data: nil, width: Int(canvas.width * pixelScale),
                height: Int(canvas.height * pixelScale),
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.scaleBy(x: pixelScale, y: pixelScale)
        root.render(in: ctx)
        return ctx.makeImage()
    }

    /// One image showing a pack at three sizes and clicking, on light and dark backgrounds
    /// (light on top). For `--preview`, the import dialog and gallery previews.
    /// - compact: only the default size, idle and clicking (for the import dialog).
    public static func sheet(for pack: StylePack, compact: Bool = false) -> CGImage? {
        let cell = CGSize(width: 260, height: 300)  // pixels per case (half of a snapshot)
        let columns: [(size: Double, click: Bool)] =
            compact
            ? [(0.75, false), (0.75, true)]
            : [(0.4, false), (0.75, false), (1.6, false), (0.75, true)]
        let rows: [PaletteKind] = [.forLightScreens, .forDarkScreens]
        guard
            let ctx = CGContext(
                data: nil, width: Int(cell.width) * columns.count,
                height: Int(cell.height) * rows.count, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.interpolationQuality = .high
        for (r, palette) in rows.enumerated() {
            for (c, col) in columns.enumerated() {
                let one = Case(pack: pack, palette: palette, size: col.size, click: col.click)
                guard let image = image(for: one) else { continue }
                // Row 0 (light) at the top; CG's origin is bottom-left.
                let y = CGFloat(rows.count - 1 - r) * cell.height
                ctx.draw(
                    image, in: CGRect(origin: CGPoint(x: CGFloat(c) * cell.width, y: y), size: cell)
                )
            }
        }
        return ctx.makeImage()
    }

    public static func writePNG(_ image: CGImage, to url: URL) {
        guard
            let dest = CGImageDestinationCreateWithURL(
                url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
