import XCTest
@testable import StrandAnalytics

final class HRVQualitySummaryTests: XCTestCase {

    func testEmptySeriesIsMissing() {
        let q = HRVAnalyzer.qualitySummary(rawRR: [])
        XCTAssertEqual(q.status, .missing)
        XCTAssertEqual(q.nInput, 0)
        XCTAssertEqual(q.nClean, 0)
        XCTAssertNil(q.rejectedFraction)
        XCTAssertNil(q.contiguousPairFraction)
    }

    func testCleanSeriesIsValidWithFullPairContinuity() {
        let rr = Array(repeating: 800.0, count: 30)
        let q = HRVAnalyzer.qualitySummary(rawRR: rr)
        XCTAssertEqual(q.status, .valid)
        XCTAssertEqual(q.nInput, 30)
        XCTAssertEqual(q.nClean, 30)
        XCTAssertEqual(q.nRejected, 0)
        XCTAssertEqual(q.rejectedFraction!, 0, accuracy: 1e-12)
        XCTAssertEqual(q.nPossibleCleanPairs, 29)
        XCTAssertEqual(q.nContiguousPairs, 29)
        XCTAssertEqual(q.contiguousPairFraction!, 1, accuracy: 1e-12)
    }

    func testTooFewCleanBeatsIsInsufficientCoverage() {
        let rr = Array(repeating: 800.0, count: HRVAnalyzer.minBeats - 1)
        let q = HRVAnalyzer.qualitySummary(rawRR: rr)
        XCTAssertEqual(q.status, .insufficientCoverage)
        XCTAssertEqual(q.nClean, HRVAnalyzer.minBeats - 1)
    }

    func testHighRejectionFractionIsPoorQualityEvenWhenEnoughBeatsSurvive() {
        var rr = Array(repeating: 800.0, count: 24)
        rr.append(contentsOf: Array(repeating: 100.0, count: 16))
        let q = HRVAnalyzer.qualitySummary(rawRR: rr, maxRejectedFraction: 0.35)
        XCTAssertEqual(q.nInput, 40)
        XCTAssertEqual(q.nClean, 24)
        XCTAssertEqual(q.nRejected, 16)
        XCTAssertEqual(q.rejectedFraction!, 0.40, accuracy: 1e-12)
        XCTAssertEqual(q.status, .poorQuality)
    }

    func testDroppedBeatReducesContiguousPairFractionInsteadOfSplicingNeighbours() {
        var rr = Array(repeating: 800.0, count: 30)
        rr[15] = 100.0 // range-rejected
        let q = HRVAnalyzer.qualitySummary(rawRR: rr)
        XCTAssertEqual(q.nClean, 29)
        XCTAssertEqual(q.nPossibleCleanPairs, 28)
        // Two accepted beats sit on either side of the dropped source beat; that joined pair is not real.
        XCTAssertEqual(q.nContiguousPairs, 27)
        XCTAssertEqual(q.contiguousPairFraction!, 27.0 / 28.0, accuracy: 1e-12)
        XCTAssertEqual(q.status, .valid)
    }
}
