import CoreGraphics
import QuartzCore
import Testing

@testable import MacCursorRender

/// The engine features packs can ask for beyond the built-ins: jet flame, particle options,
/// dark-screen colours.
@Suite struct EngineFeatureTests {
    let rocket = BuiltinPacks.rocket

    @Test func rocketFixtureUsesEveryFeature() throws {
        #expect(rocket.leg == nil && rocket.click.stamp == nil)
        #expect(rocket.jet != nil)
        let p = try #require(rocket.click.particles)
        #expect(p.facesOutward && p.fromCenter && p.minimum == 8)
    }

    @Test(arguments: [1.0, 0.5, 0.2])
    func jetFollowsTheTailSlider(length: Double) throws {
        let rig = PointerRig(contentsScale: 2)
        let full = try #require(rocket.jet).flame.boundingBoxOfPath
        rig.apply(pack: rocket, palette: .forLightScreens, tailLength: CGFloat(length))
        #expect(!rig.jet.isHidden)
        let box = try #require(rig.jetFlame.path).boundingBoxOfPath
        // Shorter, same width, still attached at the join (its top stays put).
        #expect(abs(box.height - full.height * length) < 0.01)
        #expect(abs(box.width - full.width) < 0.01)
        #expect(abs(box.maxY - full.maxY * length) < 0.01)
        #expect(rig.jet.animation(forKey: "flicker") != nil)
    }

    @Test func noTailHidesTheJet() {
        let rig = PointerRig(contentsScale: 2)
        rig.apply(pack: rocket, palette: .forLightScreens, tailLength: 0)
        #expect(rig.jet.isHidden)
        #expect(rig.jet.animation(forKey: "flicker") == nil)
    }

    @Test func stylesWithoutAJetHideIt() {
        let rig = PointerRig(contentsScale: 2)
        rig.apply(pack: BuiltinPacks.pack("dogPaw"), palette: .forLightScreens)
        #expect(rig.jet.isHidden)
    }

    @Test(
        arguments: [
            (0, 1.0, 0), (0, 1.4, 4), (0, 2.6, 8), (8, 1.0, 8), (8, 2.6, 8), (8, 3.5, 11),
        ] as [(Int, Double, Int)])
    func particleCount(minimum: Int, intensity: Double, expected: Int) {
        #expect(
            ClickEffect.particleCount(minimum: minimum, intensity: CGFloat(intensity)) == expected)
    }

    @Test func minimumParticlesFireOnASlowClick() {
        let fx = ClickEffect(
            tip: .zero, angle: 0, pack: rocket, palette: .forLightScreens, intensity: 1,
            scale: 1, contentsScale: 2, start: 0, seed: 1)
        #expect(fx.particleLayers.count == 8)
        let dog = ClickEffect(
            tip: .zero, angle: 0, pack: BuiltinPacks.pack("dogPaw"), palette: .forLightScreens,
            intensity: 1, scale: 1, contentsScale: 2, start: 0, seed: 1)
        #expect(dog.particleLayers.isEmpty)
    }

    /// Each particle's "up" points away from the click, and it doesn't spin as it flies.
    @Test(arguments: [0.1, 0.5])
    func outwardParticlesFaceTheirFlight(t: Double) {
        let fx = ClickEffect(
            tip: .zero, angle: 0, pack: rocket, palette: .forLightScreens, intensity: 1,
            scale: 1, contentsScale: 2, start: 0, seed: 7)
        fx.render(t: t)
        for p in fx.particleLayers {
            let flight = atan2(p.position.y, p.position.x)
            let m = p.affineTransform()
            let up = atan2(m.d, m.c)  // where the art's +y axis points now
            let diff = remainder(up - flight, 2 * .pi)
            #expect(abs(diff) < 0.001, "particle at \(p.position) faces \(up), flies \(flight)")
        }
    }

    @Test func centreOriginStartsAtTheClick() {
        let fx = ClickEffect(
            tip: .zero, angle: 0, pack: rocket, palette: .forLightScreens, intensity: 1,
            scale: 1, contentsScale: 2, start: 0, seed: 7)
        fx.render(t: 0)
        for p in fx.particleLayers {
            #expect(hypot(p.position.x, p.position.y) < 4)
        }
    }

    @Test func darkScreenColoursApplyOnlyOnDarkScreens() throws {
        let body = rocket.body.color
        #expect(body.resolved(.forLightScreens) != body.resolved(.forDarkScreens))
        // A null in darkScreens.details keeps that layer's colour.
        #expect(rocket.details[1].color.forDarkScreens == rocket.details[1].color.forLightScreens)
        #expect(rocket.details[0].color.forDarkScreens != rocket.details[0].color.forLightScreens)
    }
}
