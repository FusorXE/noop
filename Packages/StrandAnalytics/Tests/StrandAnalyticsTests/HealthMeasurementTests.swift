import XCTest
@testable import StrandAnalytics

final class HealthMeasurementTests: XCTestCase {

    func testValidZeroIsNotMissing() {
        let m = HealthMeasurement.valid(metric: "acceleration_x",
                                        value: 0,
                                        unit: "g",
                                        startTimestamp: 100,
                                        sourceDevice: "whoop-4",
                                        provenance: .directSensor,
                                        quality: 1,
                                        coverage: 1)
        XCTAssertEqual(m.value, 0)
        XCTAssertEqual(m.status, .valid)
        XCTAssertTrue(m.isUsable)
        XCTAssertTrue(m.validationIssues.isEmpty)
    }

    func testMissingIsNilNotZero() {
        let m = HealthMeasurement.unavailable(metric: "spo2",
                                              unit: "%",
                                              startTimestamp: 100,
                                              sourceDevice: "whoop-4",
                                              provenance: .experimental,
                                              status: .notCalculated)
        XCTAssertNil(m.value)
        XCTAssertEqual(m.status, .notCalculated)
        XCTAssertFalse(m.isUsable)
        XCTAssertTrue(m.validationIssues.isEmpty)
    }

    func testExperimentalProvenanceIsIndependentFromStatus() {
        let m = HealthMeasurement.valid(metric: "spo2_experimental",
                                        value: 96.5,
                                        unit: "%",
                                        startTimestamp: 100,
                                        sourceDevice: "whoop-4",
                                        provenance: .experimental,
                                        derivation: "red-ir-ratio-research",
                                        algorithmVersion: "0.1")
        XCTAssertEqual(m.provenance, .experimental)
        XCTAssertEqual(m.status, .valid)
        XCTAssertTrue(m.isUsable)
    }

    func testValidStatusWithoutValueIsRejectedStructurally() {
        let m = HealthMeasurement(metric: "hrv_rmssd",
                                  value: nil,
                                  unit: "ms",
                                  startTimestamp: 100,
                                  sourceDevice: "whoop-4",
                                  provenance: .localDerived,
                                  status: .valid)
        XCTAssertEqual(m.validationIssues, [.missingValueForValidStatus])
        XCTAssertFalse(m.isUsable)
    }

    func testNonFiniteAndOutOfRangeMetadataAreRejected() {
        let m = HealthMeasurement(metric: "hrv_rmssd",
                                  value: .nan,
                                  unit: "ms",
                                  startTimestamp: 200,
                                  endTimestamp: 100,
                                  sourceDevice: "whoop-4",
                                  provenance: .localDerived,
                                  quality: 1.2,
                                  coverage: -0.1,
                                  status: .valid)
        XCTAssertEqual(Set(m.validationIssues), Set([
            .nonFiniteValue,
            .qualityOutOfRange,
            .coverageOutOfRange,
            .endBeforeStart,
        ]))
        XCTAssertFalse(m.isUsable)
    }

    func testCodableRoundTripPreservesProvenanceAndNilValue() throws {
        let original = HealthMeasurement.unavailable(metric: "ecg",
                                                     unit: "mV",
                                                     startTimestamp: 1_000,
                                                     sourceDevice: "whoop-4",
                                                     provenance: .directSensor,
                                                     status: .unsupported)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HealthMeasurement.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.status, .unsupported)
        XCTAssertNil(decoded.value)
    }
}
