import CoreGraphics
import Foundation
import ImageIO
import QuartzCore
import UniformTypeIdentifiers

/// Offscreen renders of the pointer art, for design review and README images.
public enum SnapshotRenderer {
    public static func run(directory: String) {
        let dir = URL(fileURLWithPath: directory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let backgrounds: [(String, Palette, CGColor)] = [
            ("light-screen", .forLightScreens, rgb(0xF5F5F5)),
            ("dark-screen", .forDarkScreens, rgb(0x262626)),
        ]
        for kind in SkinKind.allCases {
            for (bgName, palette, bg) in backgrounds {
                for state in ["idle", "click"] {
                    let url = dir.appendingPathComponent("\(kind.rawValue)-\(bgName)-\(state).png")
                    render(kind: kind, palette: palette, background: bg, click: state == "click", to: url)
                    print(url.path)
                }
            }
        }
    }

    private static func render(kind: SkinKind, palette: Palette, background: CGColor, click: Bool, to url: URL) {
        let size = CGSize(width: 220, height: 300)
        let pixelScale: CGFloat = 2
        let root = CALayer()
        root.anchorPoint = .zero
        root.bounds = CGRect(origin: .zero, size: size)
        root.backgroundColor = background

        let art = Skins.art(for: kind)
        let tip = CGPoint(x: 100, y: 200)
        let angle: CGFloat = 18 * .pi / 180
        let scale: CGFloat = 1.3
        if click {
            let fx = ClickEffect(tip: tip, angle: angle, art: art, palette: palette, intensity: 2.6,
                                 scale: scale, contentsScale: pixelScale, start: 0)
            fx.render(t: 0.22)
            root.addSublayer(fx.layer)
        }
        let rig = PointerRig(contentsScale: pixelScale)
        rig.apply(art: art, palette: palette)
        rig.setPose(position: tip, angle: angle, scale: scale, squash: click && !art.isRing ? 0.8 : 0)
        root.addSublayer(rig.root)

        guard let ctx = CGContext(data: nil, width: Int(size.width * pixelScale), height: Int(size.height * pixelScale),
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.scaleBy(x: pixelScale, y: pixelScale)
        root.render(in: ctx)
        guard let image = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
