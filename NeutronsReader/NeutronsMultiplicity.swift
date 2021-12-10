//
//  NeutronsMultiplicity.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 19.02.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Foundation

public class NeutronsMultiplicity {
    
    fileprivate var info: [Int: Int]
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
    
    class func averageNumberOf(neutrons: Int, events: Int) -> (Double, Double) {
        let average = Double(neutrons)/Double(events)
        let error = average*(1/Double(neutrons) + 1/Double(events)).squareRoot()
        return (average, error)
    }
    
    class func errorFor(neutronsCount: Int, multiplicity: Int) -> Double {
        return (Double(neutronsCount)/max(1, Double(multiplicity))).squareRoot()
    }
    
    /**
     Error formula from work:
     Hudson D.J. STATISTICS, 1970 (RU edition), equation 66
     delta = root square from sum of squares of d(Xi)/Xi.
     */
    class func averageNumberOf(neutrons: Int, events: Int, efficiency: Double, efficiencyError: Double) -> (Double, Double) {
        let average = Double(neutrons)/Double(events)
        let error = (average / (efficiency/100))*(1/Double(neutrons) + 1/Double(events) + pow(efficiencyError/efficiency, 2)).squareRoot()
        return (average * 100.0/efficiency, error)
    }
    
    public func stringValue() -> String {
        var string = "Multiplicity\tCount\tProbability\n"
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
        string += "\n[" + probErrors.map { String($0) }.joined(separator: ", ") + "]"
        string += "\nSF count: \(events)"
        string += "\nNeutrons count: \(neutrons)"
        if neutrons > 0 {
            let tuple = NeutronsMultiplicity.averageNumberOf(neutrons: neutrons, events: events)
            let average = tuple.0
            let averageError = tuple.1
            string += "\nAverage: \(average) ± \(averageError)\n---------------"
            if efficiency > 0, efficiencyError > 0 {
                string += "\nDetector efficiency: \(efficiency)%"
                string += "\nEfficiency error: \(efficiencyError)%"
                
                let tuple = NeutronsMultiplicity.averageNumberOf(neutrons: neutrons, events: events, efficiency: efficiency, efficiencyError: efficiencyError)
                let averageE = tuple.0
                let averageEError = tuple.1
                string += "\n*Average: \(averageE) ± \(averageEError)"
                let meanOfSquares =  Double(neutronsSquares)/Double(events)
                /*
                 Dispersion formula from work:
                 Dakowski M., Lazarev Yu.A., Turchin V.F., Turovtseva L.S.
                 Reconstruction of particle multiplicity distribution using the method of statistical regularization.
                 Nucl. Instr. Meth. 1973. V. 113. No 2. P. 195–200.
                 */
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
