import Foundation

// HealthMeasurement.swift — normalized provenance + availability semantics for the Personal Health OS.
//
// This is intentionally a DOMAIN layer, not a database migration. Existing NOOP storage remains untouched.
// Device/protocol records can be projected into this type incrementally as each metric is hardened.
//
// Core rule: provenance (where/how a value came from) is independent from status (whether that value is
// usable). An EXPERIMENTAL value can be valid data for research, while a DIRECT_SENSOR value can still be
// missing or poor quality. Keeping the two axes separate prevents UI/analytics from silently treating
// inferred values as direct measurements or missing values as physiological zero.

/// How a health value was produced. This describes provenance, not clinical validity or data quality.
public enum HealthMeasurementProvenance: String, Codable, CaseIterable, Sendable {
    /// A physical sensor channel or decoded sensor sample (for example heart rate / optical ADC / motion).
    case directSensor = "DIRECT_SENSOR"
    /// A value computed by the wearable/device firmware from its sensors.
    case deviceDerived = "DEVICE_DERIVED"
    /// A deterministic metric computed locally by NOOP / the Personal Health OS.
    case localDerived = "LOCAL_DERIVED"
    /// A local research inference that has not been validated strongly enough to present as an ordinary metric.
    case experimental = "EXPERIMENTAL"
    /// A value imported from another health platform, file, or external device.
    case imported = "IMPORTED"
    /// A value entered explicitly by the user.
    case manual = "MANUAL"
}

/// Availability / quality state for a measurement. This is deliberately orthogonal to provenance.
public enum HealthMeasurementStatus: String, Codable, CaseIterable, Sendable {
    /// A finite value exists and passed the caller's quality/coverage gates.
    case valid
    /// No observation exists for the requested interval.
    case missing
    /// The source cannot produce this metric (for example ECG on WHOOP 4.0).
    case unsupported
    /// The source was known to be off-body / not in physiological contact.
    case offBody
    /// A value exists but failed a signal-quality gate.
    case poorQuality
    /// Some data exists, but not enough of the requested interval was observed to trust the metric.
    case insufficientCoverage
    /// The source could support the metric, but the computation has not run / completed yet.
    case notCalculated
}

/// Structural problems that make a normalized measurement unsafe to consume as a normal health value.
public enum HealthMeasurementValidationIssue: String, Codable, Equatable, Sendable {
    case missingValueForValidStatus
    case nonFiniteValue
    case qualityOutOfRange
    case coverageOutOfRange
    case endBeforeStart
}

/// A normalized scalar health measurement with explicit provenance, status, quality, and coverage.
///
/// Timestamps are Unix seconds. `endTimestamp` is optional for point samples; when present it denotes an
/// interval and must not precede `startTimestamp`. `quality` and `coverage` are optional 0...1 fractions.
/// The type does NOT clamp malformed metadata: hidden correction would make audit trails dishonest. Callers
/// can inspect `validationIssues` / `isUsable` and preserve the original source value for diagnostics.
public struct HealthMeasurement: Codable, Equatable, Sendable {
    public let metric: String
    public let value: Double?
    public let unit: String
    public let startTimestamp: Int
    public let endTimestamp: Int?
    public let sourceDevice: String
    public let provenance: HealthMeasurementProvenance
    public let derivation: String?
    public let algorithmVersion: String?
    public let quality: Double?
    public let coverage: Double?
    public let status: HealthMeasurementStatus

    public init(metric: String,
                value: Double?,
                unit: String,
                startTimestamp: Int,
                endTimestamp: Int? = nil,
                sourceDevice: String,
                provenance: HealthMeasurementProvenance,
                derivation: String? = nil,
                algorithmVersion: String? = nil,
                quality: Double? = nil,
                coverage: Double? = nil,
                status: HealthMeasurementStatus) {
        self.metric = metric
        self.value = value
        self.unit = unit
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.sourceDevice = sourceDevice
        self.provenance = provenance
        self.derivation = derivation
        self.algorithmVersion = algorithmVersion
        self.quality = quality
        self.coverage = coverage
        self.status = status
    }

    /// Convenience constructor for a value that has passed the caller's physiological and quality gates.
    public static func valid(metric: String,
                             value: Double,
                             unit: String,
                             startTimestamp: Int,
                             endTimestamp: Int? = nil,
                             sourceDevice: String,
                             provenance: HealthMeasurementProvenance,
                             derivation: String? = nil,
                             algorithmVersion: String? = nil,
                             quality: Double? = nil,
                             coverage: Double? = nil) -> HealthMeasurement {
        HealthMeasurement(metric: metric,
                          value: value,
                          unit: unit,
                          startTimestamp: startTimestamp,
                          endTimestamp: endTimestamp,
                          sourceDevice: sourceDevice,
                          provenance: provenance,
                          derivation: derivation,
                          algorithmVersion: algorithmVersion,
                          quality: quality,
                          coverage: coverage,
                          status: .valid)
    }

    /// Convenience constructor for an unavailable value. Absence is represented by `nil`, never a sentinel 0.
    public static func unavailable(metric: String,
                                   unit: String,
                                   startTimestamp: Int,
                                   endTimestamp: Int? = nil,
                                   sourceDevice: String,
                                   provenance: HealthMeasurementProvenance,
                                   status: HealthMeasurementStatus,
                                   derivation: String? = nil,
                                   algorithmVersion: String? = nil,
                                   quality: Double? = nil,
                                   coverage: Double? = nil) -> HealthMeasurement {
        HealthMeasurement(metric: metric,
                          value: nil,
                          unit: unit,
                          startTimestamp: startTimestamp,
                          endTimestamp: endTimestamp,
                          sourceDevice: sourceDevice,
                          provenance: provenance,
                          derivation: derivation,
                          algorithmVersion: algorithmVersion,
                          quality: quality,
                          coverage: coverage,
                          status: status)
    }

    /// Structural validation only. Physiological plausibility belongs to each metric's own algorithm.
    public var validationIssues: [HealthMeasurementValidationIssue] {
        var issues: [HealthMeasurementValidationIssue] = []
        if status == .valid && value == nil { issues.append(.missingValueForValidStatus) }
        if let value, !value.isFinite { issues.append(.nonFiniteValue) }
        if let quality, !(0.0...1.0).contains(quality) { issues.append(.qualityOutOfRange) }
        if let coverage, !(0.0...1.0).contains(coverage) { issues.append(.coverageOutOfRange) }
        if let endTimestamp, endTimestamp < startTimestamp { issues.append(.endBeforeStart) }
        return issues
    }

    /// True only for an explicitly-valid, finite value with structurally sane metadata.
    public var isUsable: Bool {
        status == .valid && value?.isFinite == true && validationIssues.isEmpty
    }
}
