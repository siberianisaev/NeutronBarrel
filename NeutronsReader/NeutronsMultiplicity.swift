//
//  NeutronsMultiplicity.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 19.02.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Foundation

class NeutronsMultiplicity {
    
    fileprivate var info: [Int: Int]
    fileprivate var efficiency: Double
    fileprivate var efficiencyError: Double
    fileprivate var placedSFSource: SFSource?
    
    init(efficiency: Double, efficiencyError: Double, placedSFSource: SFSource?) {
        self.efficiency = efficiency
        self.efficiencyError = efficiencyError
        self.placedSFSource = placedSFSource
        self.info = [:]
    }
    
    func update(neutronsPerAct: [Float]) {
        let key = neutronsPerAct.count
        var sum = info[Int(key)] ?? 0
        sum += 1 // One event for all neutrons in one act of fission
        info[Int(key)] = sum
    }
    
    func stringValue() -> String {
        var string = "Multiplicity\tCount\n"
        let sortedKeys = Array(info.keys).sorted(by: { (i1: Int, i2: Int) -> Bool in
            return i1 < i2
        })
        var neutrons: Int = 0
        var neutronsSquares: Int = 0
        var events: Int = 0
        for key in sortedKeys {
            let count = info[key]!
            string += "\(key)\t\(count)\n"
            events += count
            neutrons += count * key
            neutronsSquares += count * Int(pow(Double(key), 2))
        }
        if neutrons > 0 {
            let average = Double(neutrons)/Double(events)
            let averageError = (Double(neutrons)/Double(events))*(1/Double(neutrons) + 1/Double(events)).squareRoot()
            string += "\nAverage: \(average) ± \(averageError)\n---------------"
            if efficiency > 0, efficiencyError > 0 {
                string += "\nDetector efficiency: \(efficiency)%"
                string += "\nEfficiency error: \(efficiencyError)%"
                /*
                 Error formula from work:
                 Hudson D.J. STATISTICS, 1970 (RU edition), equation 66
                 delta = root square from sum of squares of d(Xi)/Xi.
                 */
                let averageErrorWithEfficiency = (Double(neutrons)/(Double(events) * (efficiency/100)))*(1/Double(neutrons) + 1/Double(events) + pow(efficiencyError/efficiency, 2)).squareRoot()
                string += "\n*Average: \(average * 100.0/efficiency) ± \(averageErrorWithEfficiency)"
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
                let e = NeutronTotalEfficiency(sfSource: sfSource)
                string += "\n\(e.calculate(info: info))"
            }
        }
        return string
    }
    
}
