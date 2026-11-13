import Testing
@testable import PointerColors

struct SliderNudgeTests {
    @Test(arguments: [("%.2f s", 1.0, 0.01), ("%.1f×", 1.0, 0.1), ("%.0f pt", 1.0, 1.0),
                      ("%.0f%%", 100.0, 0.01), ("%.0f ms", 1000.0, 0.001)])
    func `a press moves the smallest change the label shows`(format: String, scale: Double, expected: Double) throws {
        let amount = try #require(SliderNudge.smallestShown(format: format, scale: scale))
        #expect(abs(amount - expected) < 1e-12)
    }

    @Test func `a slider's own step wins over its label`() {
        #expect(SliderNudge.amount(step: 5, format: "%.0f pt", scale: 1, range: 0...100) == 5)
    }

    @Test func `a label it can't read falls back to a hundredth of the range`() {
        #expect(SliderNudge.amount(step: nil, format: "%.2g×", scale: 1, range: 1...3) == 0.02)
    }

    @Test func `presses stay on the grid without drifting`() {
        var value = 0.35
        for _ in 0..<7 { value = SliderNudge.nudged(value, by: 0.01, in: 0.1...2) }
        #expect(String(format: "%.10f", value) == "0.4200000000")
    }

    @Test func `presses stop at the ends of the range`() {
        #expect(SliderNudge.nudged(1.995, by: 0.01, in: 0.1...2) == 2)
        #expect(SliderNudge.nudged(0.1, by: -0.01, in: 0.1...2) == 0.1)
    }
}
