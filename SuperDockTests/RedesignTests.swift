import Foundation
import Testing

struct ProductivityTextTests {
    /// Expected text is main and fraction joined; past an hour there is no fraction.
    @Test(arguments: [
        (0.0, "0:00|.0"), (0.06, "0:00|.0"), (84.6, "1:24|.6"), (84.69, "1:24|.6"), (599.95, "9:59|.9"),
        (3599.9, "59:59|.9"), (3600, "1:00:00|"), (3723.4, "1:02:03|"), (-5, "0:00|.0")
    ] as [(Double, String)])
    func stopwatch(seconds: Double, expected: String) {
        let text = StopwatchText.format(seconds)
        #expect("\(text.main)|\(text.fraction)" == expected)
    }

    @Test(arguments: [
        (0.0, "just now"), (59, "just now"), (60, "1m ago"), (59 * 60 + 59, "59m ago"), (3600, "1h ago"),
        (23 * 3600 + 59 * 60, "23h ago"), (86_400, "1d ago"), (9 * 86_400, "9d ago"), (-120, "just now")
    ] as [(Double, String)])
    func shortAge(secondsAgo: Double, text: String) {
        let now = Date(timeIntervalSince1970: 1_795_109_100)
        #expect(ShortAge.text(since: now.addingTimeInterval(-secondsAgo), now: now) == text)
    }
}

struct LimoPoseTests {
    @Test(arguments: [
        ("exclamationmark.triangle.fill", LimoPose.pokesIce), ("snowflake", .pokesIce), ("hand.raised.fill", .handUp),
        ("checkmark.seal.fill", .celebrates), ("checkmark.circle.fill", .celebrates), ("drop.fill", .takesSip),
        ("drop", .takesSip), ("link", .curious), ("questionmark.circle", .curious),
        ("gauge.with.dots.needle.67percent", .checksGauge), ("gauge.high", .checksGauge), ("bell", .saysHi), ("", .saysHi)
    ])
    func alertSymbolPicksPose(symbol: String, pose: LimoPose) {
        #expect(LimoPose(alertSymbol: symbol) == pose)
    }
}
