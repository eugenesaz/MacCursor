import CoreGraphics
import Foundation
import Testing

@testable import MacCursorRender

@Suite struct SVGArtTests {
    private func read(_ body: String) -> SVGArt {
        SVGArt.read(Data("<svg xmlns=\"http://www.w3.org/2000/svg\">\(body)</svg>".utf8))
    }

    private func messages(_ art: SVGArt) -> [String] { art.problems.map(\.description) }

    @Test func basicShapes() throws {
        let art = read(
            """
            <rect id="r" x="1" y="2" width="10" height="4"/>
            <rect id="rr" width="10" height="10" rx="3"/>
            <circle id="c" cx="5" cy="5" r="5"/>
            <ellipse id="e" cx="0" cy="0" rx="4" ry="2"/>
            <polygon id="pg" points="0,0 10,0 5,8"/>
            <polyline id="pl" points="0 0 4 4"/>
            <path id="p" d="M0 0 L3 3"/>
            """)
        #expect(art.problems.isEmpty)
        #expect(art.paths["r"]?.boundingBoxOfPath == CGRect(x: 1, y: 2, width: 10, height: 4))
        #expect(art.paths["rr"]?.contains(CGPoint(x: 0.2, y: 0.2)) == false)
        #expect(art.paths["c"]?.boundingBoxOfPath == CGRect(x: 0, y: 0, width: 10, height: 10))
        #expect(art.paths["e"]?.boundingBoxOfPath == CGRect(x: -4, y: -2, width: 8, height: 4))
        #expect(art.paths["pg"]?.contains(CGPoint(x: 5, y: 3)) == true)
        #expect(art.paths["pl"]?.boundingBoxOfPath == CGRect(x: 0, y: 0, width: 4, height: 4))
        #expect(art.paths["p"] != nil)
    }

    @Test func groupsMergeTheirShapes() {
        let art = read(
            """
            <g id="toes"><circle cx="0" cy="0" r="1"/><circle id="big" cx="10" cy="0" r="2"/></g>
            """)
        #expect(art.paths["toes"]?.boundingBoxOfPath == CGRect(x: -1, y: -2, width: 13, height: 4))
        #expect(art.paths["big"]?.boundingBoxOfPath == CGRect(x: 8, y: -2, width: 4, height: 4))
    }

    @Test func transformsCompose() {
        let art = read(
            """
            <g transform="translate(10 0)">
              <rect id="a" width="2" height="2" transform="scale(2)"/>
              <rect id="b" width="2" height="2" transform="translate(0,5) rotate(90)"/>
              <rect id="c" width="2" height="2" transform="matrix(1 0 0 1 1 1)"/>
            </g>
            """)
        #expect(art.problems.isEmpty)
        #expect(art.paths["a"]?.boundingBoxOfPath == CGRect(x: 10, y: 0, width: 4, height: 4))
        // rotate first (x,y → -y,x), then translate: x in 8…10, y in 5…7.
        let b = art.paths["b"]?.boundingBoxOfPath ?? .null
        #expect(abs(b.minX - 8) < 1e-9 && abs(b.minY - 5) < 1e-9)
        #expect(art.paths["c"]?.boundingBoxOfPath == CGRect(x: 11, y: 1, width: 2, height: 2))
    }

    @Test func rotateAboutAPointAndSkew() {
        let art = read(
            """
            <rect id="r" x="0" y="0" width="2" height="2" transform="rotate(180 1 1)"/>
            <rect id="s" width="2" height="2" transform="skewX(45)"/>
            """)
        let r = art.paths["r"]?.boundingBoxOfPath ?? .null
        #expect(abs(r.minX) < 1e-9 && abs(r.maxX - 2) < 1e-9)
        #expect(abs((art.paths["s"]?.boundingBoxOfPath.width ?? 0) - 4) < 1e-9)
    }

    @Test func evenOddFromAttributeOrStyle() {
        let art = read(
            """
            <path id="a" fill-rule="evenodd" d="M0 0h1v1z"/>
            <path id="b" style="fill:#000; fill-rule: evenodd" d="M0 0h1v1z"/>
            <path id="c" d="M0 0h1v1z"/>
            """)
        #expect(art.evenOdd == ["a", "b"])
    }

    @Test func editorExtrasAreSkipped() {
        let art = SVGArt.read(
            Data(
                """
                <?xml version="1.0" encoding="UTF-8"?>
                <svg xmlns="http://www.w3.org/2000/svg" xmlns:sodipodi="x" viewBox="0 0 10 10">
                  <title>Paw</title><desc>d</desc><metadata><x/></metadata>
                  <sodipodi:namedview id="nv"/>
                  <defs><clipPath id="clip"><rect width="1" height="1"/></clipPath></defs>
                  <path id="p" d="M0 0h1v1z" fill="#123456"/>
                </svg>
                """.utf8))
        #expect(art.problems.isEmpty)
        #expect(Set(art.paths.keys) == ["p"])
    }

    @Test(arguments: ["image", "use", "text", "style", "script", "foreignObject"])
    func forbiddenElementsAreRejected(name: String) {
        let art = read("<defs><\(name)/></defs><path id=\"p\" d=\"M0 0h1v1z\"/>")
        #expect(
            messages(art).contains(
                "art.svg: element <\(name)> isn't allowed in a style pack (no images, text, styles or links)"
            ))
    }

    @Test func unsupportedElementsAreRejected() {
        let art = read("<linearGradient id=\"g\"/>")
        #expect(
            messages(art) == [
                "art.svg: element <linearGradient> isn't supported; use only paths and basic shapes"
            ])
    }

    @Test func linksAndHandlersAreRejected() {
        let art = read(
            "<path id=\"p\" d=\"M0 0h1v1z\" xlink:href=\"x.svg\" onclick=\"x()\"/>")
        #expect(art.problems.count == 2)
        #expect(
            messages(art).contains("art.svg: element <path> must not link to anything (xlink:href)")
        )
    }

    @Test func doctypeAndEntitiesAreRejected() {
        let data = Data(
            "<!DOCTYPE svg [<!ENTITY a \"aaaa\">]><svg><path d=\"M0 0\"/></svg>".utf8)
        #expect(
            SVGArt.read(data).problems.map(\.description) == [
                "art.svg: must not contain a DOCTYPE or ENTITY declaration"
            ])
    }

    @Test func badShapesAndTransformsAreReported() {
        let art = read(
            """
            <rect id="a" width="wide" height="1"/>
            <circle id="b"/>
            <path id="c" d="L1 1"/>
            <rect id="d" width="1" height="1" transform="spin(3)"/>
            """)
        #expect(
            messages(art) == [
                "art.svg: element <rect> width must be a plain number (got \"wide\")",
                "art.svg: element <circle> needs a r attribute",
                "art.svg: element <path> path data must start with a move (M) command",
                "art.svg: element <rect> has a bad transform: spin() with 1 numbers isn't supported",
            ])
    }

    @Test func notXMLOrNotSVG() {
        #expect(SVGArt.read(Data("hello".utf8)).problems.count == 1)
        #expect(
            SVGArt.read(Data("<html/>".utf8)).problems.map(\.description) == [
                "art.svg: element <html> must be inside an <svg> root element"
            ])
    }

    @Test func strokesWarn() {
        let art = read("<path id=\"p\" d=\"M0 0h1\" stroke=\"#000\"/>")
        #expect(art.problems.isEmpty)
        #expect(art.warnings.count == 1)
    }
}
