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
        public let style: PointerStyle
        public let palette: PaletteKind
        public let size: Double
        public let click: Bool

        public var name: String {
            let bg = palette == .forLightScreens ? "light-screen" : "dark-screen"
            return
                "\(style.rawValue)-\(bg)-\(String(format: "%.2f", size))x-\(click ? "click" : "idle")"
        }
    }

    /// Every style × palette at three sizes idle, plus a click at the default size.
    public static var allCases: [Case] {
        PointerStyle.allCases.flatMap { style in
            [PaletteKind.forLightScreens, .forDarkScreens].flatMap { palette in
                [0.4, 0.75, 1.6].map {
                    Case(style: style, palette: palette, size: $0, click: false)
                }
                    + [Case(style: style, palette: palette, size: 0.75, click: true)]
            }
        }
    }

    /// Writes a PNG of every case to `directory`, for design review.
    public static func run(directory: String) {
        let dir = URL(fileURLWithPath: directory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for c in allCases {
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

        let art = Skins.art(for: c.style)
        let tip = CGPoint(x: 120, y: 200)
        let angle: CGFloat = 18 * .pi / 180
        let scale = CGFloat(c.size)
        if c.click {
            let fx = ClickEffect(
                tip: tip, angle: angle, art: art, palette: palette, intensity: 2.6,
                scale: scale, contentsScale: pixelScale, start: 0, seed: 42)
            fx.render(t: 0.22)
            root.addSublayer(fx.layer)
        }
        let rig = PointerRig(contentsScale: pixelScale)
        rig.apply(art: art, palette: palette)
        rig.setPose(
            position: tip, angle: angle, scale: scale, squash: c.click && !art.isRing ? 0.8 : 0)
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

    public static func writePNG(_ image: CGImage, to url: URL) {
        guard
            let dest = CGImageDestinationCreateWithURL(
                url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
