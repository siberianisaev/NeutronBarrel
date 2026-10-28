//
//  NeutronsMultiplicity.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 19.02.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Foundation

public class NeutronsMultiplicity {
    
    var info: [Int: Int]
    fileprivate var efficiency: Double
    fileprivate var efficiencyError: Double
    fileprivate var placedSFSource: SFSource?
    fileprivate var broken: Int = 0
    
    public init(info: [Int: Int] = [:], efficiency: Double, efficiencyError: Double, placedSFSource: SFSource? = nil) {
        self.info = info
        self.efficiency = efficiency
        self.efficiencyError = efficiencyError
        self.placedSFSource = placedSFSource
    }
    
    func incrementBroken() {
        broken += 1
    }
    
    func increment(multiplicity: Int) {
        var sum = info[multiplicity] ?? 0
        sum += 1 // One event for all neutrons in one act of fission
        info[multiplicity] = sum
    }
    
    class func errorFor(neutronsCount: Int, multiplicity: Int) -> Double {
        return (Double(neutronsCount)/max(1, Double(multiplicity))).squareRoot()
    }
    
    public struct MeanEstimate {
        public let events: Int
        public let neutrons: Double
        public let mean: Double
        // nil means that fewer than two fissions are available.
        public let statisticalUncertainty: Double?
        public let efficiencyUncertainty: Double
        public let totalUncertainty: Double?
    }

    public enum MeanError: Error {
        case invalidHistogram, emptyHistogram, invalidEfficiency
    }

    /// Uses registered multiplicities per fission. No background correction.
    /// Efficiency and its absolute uncertainty are both in percentage points.
    public func meanEstimate() throws -> MeanEstimate {
        guard efficiency.isFinite, efficiency > 0, efficiency <= 100,
              efficiencyError.isFinite, efficiencyError >= 0 else {
            throw MeanError.invalidEfficiency
        }
        guard info.allSatisfy({ $0.key >= 0 && $0.value >= 0 }) else {
            throw MeanError.invalidHistogram
        }
        let n = info.values.reduce(0, +)
        guard n > 0 else { throw MeanError.emptyHistogram }
        let epsilon = efficiency / 100
        let epsilonSE = efficiencyError / 100
        let m = info.reduce(0.0) { $0 + Double($1.key) * Double($1.value) }
        let detectedMean = m / Double(n)
        let mean = detectedMean / epsilon
        // Two-pass centered sum is stable even for narrow distributions.
        let squares = info.reduce(0.0) {
            $0 + Double($1.value) * pow(Double($1.key) - detectedMean, 2)
        }
        let stat: Double? = n > 1
            ? sqrt(squares / (Double(n) * Double(n - 1))) / epsilon : nil
        let eff = abs(mean) * epsilonSE / epsilon
        return MeanEstimate(events: n, neutrons: m, mean: mean,
                            statisticalUncertainty: stat,
                            efficiencyUncertainty: eff,
                            totalUncertainty: stat.map { hypot($0, eff) })
    }

    public func stringValue() -> String {
        var info = self.info // Fill display gaps without mutating experimental counts.
        guard info.allSatisfy({ $0.key >= 0 && $0.value >= 0 }) else {
            return "Mean multiplicity unavailable: invalid histogram"
        }
        var string = "Multiplicity\tCount\tProbability\n"
        
        // Prevent gaps in multiplicity range
        if let maxMultiplicity = Array(info.keys).max(), maxMultiplicity > 0 {
            for key in 0...maxMultiplicity-1 {
                if !info.keys.contains(key) {
                    info[key] = 0
                }
            }
        }
        
        let sortedKeys = Array(info.keys).sorted(by: { (i1: Int, i2: Int) -> Bool in
            return i1 < i2
        })
        var neutrons: Int = 0
        var neutronsSquares: Int = 0
        let events: Int = info.map { $0.value }.sum()
        var probabilities = [Double]()
        var counts = [Int]()
        for key in sortedKeys {
            let count = info[key]!
            let probability = events > 0 ? (Double(count) / Double(events)) : 0
            probabilities.append(probability)
            string += "\(key)\t\(count)\t\(probability)\n"
            neutrons += count * key
            neutronsSquares += count * Int(pow(Double(key), 2))
            counts.append(count)
        }
        // Neutron counts with errors
        string += "\n[" + counts.map { String($0) }.joined(separator: ", ") + "]"
        var countErrors = [Double]()
        let count = counts.count
        if count > 0 {
            for i in 0...count-1 {
                countErrors.append(NeutronsMultiplicity.errorFor(neutronsCount: counts[i], multiplicity: i))
            }
        }
        string += "\n[" + countErrors.map { String($0) }.joined(separator: ", ") + "]"
        // Neutron probabilities with errors
        string += "\n[" + probabilities.map { String($0) }.joined(separator: ", ") + "]"
        var probErrors = [Double]()
        if count > 0 {
            for i in 0...count-1 {
                probErrors.append(NeutronsMultiplicity.errorFor(neutronsCount: counts[i], multiplicity: i)/Double(counts.sum()))
            }
        }
        string += "\nProbErrors: [" + probErrors.map { String($0) }.joined(separator: ", ") + "]"
        string += "\nSF count: \(events)"
        string += "\nNeutrons count: \(neutrons)"
        string += "\nDetector efficiency: \(efficiency) %"
        string += "\nEfficiency error: \(efficiencyError) %"
        do {
            let estimate = try meanEstimate()
            string += "\n\nMean multiplicity (no background correction): \(estimate.mean)"
            let stat = estimate.statisticalUncertainty.map { String($0) }
                ?? "unavailable (requires at least two fissions)"
            let total = estimate.totalUncertainty.map { String($0) }
                ?? "unavailable (requires at least two fissions)"
            string += "\nStatistical uncertainty: \(stat)"
            string += "\nEfficiency uncertainty: \(estimate.efficiencyUncertainty)"
            string += "\nTotal uncertainty: \(total)"
            if neutrons == 0 {
                string += "\nZero empirical scatter does not imply a zero upper confidence limit."
            }
        } catch {
            string += "\nMean multiplicity unavailable: \(error)"
        }
        if neutrons > 0 {
            if efficiency.isFinite, efficiency > 0, efficiency <= 100 {
                let average = Double(neutrons) / Double(events)
                let meanOfSquares = Double(neutronsSquares) / Double(events)
                // Historical physical-distribution moment, not an error of the mean.
                string += "\n*Dispersion: \((meanOfSquares - pow(average, 2) - average*(1 - efficiency/100))/pow(efficiency/100, 2))"
            }
            if let sfSource = placedSFSource {
                string += "\n"
                if sfSource.idealDistribution() == nil {
                    let e = NeutronTotalEfficiency(sfSource: sfSource)
                    string += "\(e.calculate(info: info))"
                } else if let tuple = NeutronTotalEfficiency.efficiencyFor(measuredDistribution: probabilities, sfCount: events, source: sfSource) {
                    string += "\(tuple.0)\n\(tuple.1)"
                }
            }
        }
        string += "\nBroken count: \(broken)"
        return string
    }
    
}
