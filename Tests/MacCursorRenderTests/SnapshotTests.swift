import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import MacCursorRender

/// Compares each rendered case with its reference PNG in `Snapshots/`.
/// After an intended art change, rewrite the references:
/// `UPDATE_SNAPSHOTS=1 ./scripts/swift-test.sh --filter Snapshot`, then review the PNGs.
@Suite struct SnapshotTests {
    static let referenceDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().appendingPathComponent("Snapshots")
    static let updating = ProcessInfo.processInfo.environment["UPDATE_SNAPSHOTS"] == "1"

    @Test(arguments: SnapshotRenderer.allCases.map(\.name))
    func matchesReference(name: String) throws {
        let c = try #require(SnapshotRenderer.allCases.first { $0.name == name })
        let image = try #require(SnapshotRenderer.image(for: c))
        let url = Self.referenceDir.appendingPathComponent("\(name).png")

        if Self.updating {
            try FileManager.default.createDirectory(
                at: Self.referenceDir, withIntermediateDirectories: true)
            SnapshotRenderer.writePNG(image, to: url)
            return
        }
        let reference = try #require(
            loadImage(url), "Missing reference \(name).png; run with UPDATE_SNAPSHOTS=1")
        #expect(
            image.width == reference.width && image.height == reference.height,
            "\(name): rendered \(image.width)×\(image.height), reference \(reference.width)×\(reference.height)"
        )
        let diff = try #require(differingFraction(image, reference))
        #expect(diff <= 0.001, "\(name): \(String(format: "%.3f", diff * 100))% of pixels differ")
    }

    @Test func everyReferenceHasACase() throws {
        let names = Set(SnapshotRenderer.allCases.map { "\($0.name).png" })
        let files =
            (try? FileManager.default.contentsOfDirectory(atPath: Self.referenceDir.path))
            ?? []
        let stale = files.filter { $0.hasSuffix(".png") && !names.contains($0) }
        #expect(stale.isEmpty, "Stale references: \(stale)")
    }

    private func loadImage(_ url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    /// Fraction of pixels where any channel differs by more than 8/255. nil if sizes differ.
    private func differingFraction(_ a: CGImage, _ b: CGImage) -> Double? {
        guard a.width == b.width, a.height == b.height else { return nil }
        guard let pa = rgba(a), let pb = rgba(b) else { return nil }
        var differing = 0
        for i in stride(from: 0, to: pa.count, by: 4) {
            for k in 0..<4 where abs(Int(pa[i + k]) - Int(pb[i + k])) > 8 {
                differing += 1
                break
            }
        }
        return Double(differing) / Double(a.width * a.height)
    }

    /// The image's pixels as sRGB RGBA bytes; nil if they can't be read.
    private func rgba(_ image: CGImage) -> [UInt8]? {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = data.withUnsafeMutableBytes { buf -> Bool in
            guard
                let ctx = CGContext(
                    data: buf.baseAddress, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return drawn ? data : nil
    }
}
