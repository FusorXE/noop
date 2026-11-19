import Foundation

/// Data-quality summary for an R-R window after the same range + ectopic cleaning used by `HRVAnalyzer`.
/// This is deliberately separate from the HRV value itself: severity/physiology and confidence/data quality
/// are different questions. A caller can refuse or down-rank a derived metric without replacing it with zero.
public struct HRVQualitySummary: Equatable, Sendable {
    public let nInput: Int
    public let nClean: Int
    public let nRejected: Int
    /// Fraction of input intervals rejected by range + ectopic cleaning, 0...1. nil when no input exists.
    public let rejectedFraction: Double?
    /// Number of accepted successive pairs that were adjacent in the ORIGINAL R-R stream.
    public let nContiguousPairs: Int
    /// Maximum number of successive pairs possible after cleaning (`max(nClean - 1, 0)`).
    public let nPossibleCleanPairs: Int
    /// `nContiguousPairs / nPossibleCleanPairs`, 0...1. nil when fewer than two clean intervals survive.
    public let contiguousPairFraction: Double?
    /// Availability/quality state for downstream normalized measurements.
    public let status: HealthMeasurementStatus

    public init(nInput: Int,
                nClean: Int,
                nRejected: Int,
                rejectedFraction: Double?,
                nContiguousPairs: Int,
                nPossibleCleanPairs: Int,
                contiguousPairFraction: Double?,
                status: HealthMeasurementStatus) {
        self.nInput = nInput
        self.nClean = nClean
        self.nRejected = nRejected
        self.rejectedFraction = rejectedFraction
        self.nContiguousPairs = nContiguousPairs
        self.nPossibleCleanPairs = nPossibleCleanPairs
        self.contiguousPairFraction = contiguousPairFraction
        self.status = status
    }
}

public extension HRVAnalyzer {
    /// Summarise R-R cleaning loss without changing any shipped RMSSD/SDNN/pNN50 calculation.
    ///
    /// `maxRejectedFraction` defaults to the existing live-spot honesty gate (35%). It is a QUALITY label
    /// here, not a mutation: all counts are still returned so research/debug views can show why a window was
    /// refused. Nightly callers that want a different acceptance policy can supply their own threshold.
    static func qualitySummary(rawRR: [Double],
                               maxRejectedFraction: Double = defaultSpotMaxRejectedFraction) -> HRVQualitySummary {
        let nInput = rawRR.count
        guard nInput > 0 else {
            return HRVQualitySummary(nInput: 0,
                                     nClean: 0,
                                     nRejected: 0,
                                     rejectedFraction: nil,
                                     nContiguousPairs: 0,
                                     nPossibleCleanPairs: 0,
                                     contiguousPairFraction: nil,
                                     status: .missing)
        }

        let cleaned = cleanRRGapAware(rawRR)
        let nClean = cleaned.nn.count
        let nRejected = max(0, nInput - nClean)
        let rejectedFraction = Double(nRejected) / Double(nInput)
        let nPossiblePairs = max(0, nClean - 1)
        let nContiguousPairs = cleaned.contiguous.dropFirst().reduce(into: 0) { count, isContiguous in
            if isContiguous { count += 1 }
        }
        let pairFraction: Double? = nPossiblePairs > 0
            ? Double(nContiguousPairs) / Double(nPossiblePairs)
            : nil

        let status: HealthMeasurementStatus
        if nClean < minBeats {
            status = .insufficientCoverage
        } else if rejectedFraction > maxRejectedFraction {
            status = .poorQuality
        } else {
            status = .valid
        }

        return HRVQualitySummary(nInput: nInput,
                                 nClean: nClean,
                                 nRejected: nRejected,
                                 rejectedFraction: rejectedFraction,
                                 nContiguousPairs: nContiguousPairs,
                                 nPossibleCleanPairs: nPossiblePairs,
                                 contiguousPairFraction: pairFraction,
                                 status: status)
    }
}
