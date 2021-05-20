//
//  NeutronTotalEfficiency.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 12.04.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Foundation

enum SFSource: Int {
    case Cm248 = 0, U238, Cf252, No252
    
    /*
    Neutrons probabilities from work:
    Norman E. Holden & Martin S. Zucker (1986) Prompt neutron multiplicities for the transplutonium nuclides, Radiation Effects, 96:1-4, 289-292, DOI:
    10.1080/00337578608211755
     */
    func idealDistribution() -> [Double]? {
        switch self {
        case .Cm248:
            return [0.00674,
                    0.05965,
                    0.22055,
                    0.35090,
                    0.25438,
                    0.08935,
                    0.01674,
                    0.00169,
                    0.00740]
        case .Cf252:
            return [0.00217,
                    0.02556,
                    0.12541,
                    0.27433,
                    0.30517,
                    0.18523,
                    0.06607,
                    0.01414,
                    0.00186,
                    0.00006]
        case .No252:
            return [0.052,
                    0.277,
                    0.366,
                    0.247,
                    0.050,
                    0.008]
        case .U238:
            // TODO: Multiplicity of prompt neutrons in spontaneous fission of 238U, Popeko, A.G., Ter-Akop'yan, G.M.
            return nil
        }
    }
    
}

fileprivate class NeutronSingleEfficiency {
    
    var value: Double = 0
    var probabilities = [Double]()
    
    init(value: Double, probabilities: [Double]) {
        self.value = value
        self.probabilities = probabilities
    }
    
    func probability(i: Int, j: Int) -> Double {
        return probabilities[i]/max(probabilities[j], 0.000000001)
    }
    
}

class NeutronTotalEfficiency {

    fileprivate var data = [NeutronSingleEfficiency]()
    fileprivate var sfSource: SFSource!
    
    init(sfSource: SFSource) {
        self.sfSource = sfSource
        // Source file contains probabilities and single neutron efficiencies: F0 F1 F2 ... F12, F1/F2 F1/F3 F2/F3 F3/F4 F2/F4
        if let url = Bundle.main.url(forResource: "SF_sources/\(sfSource)", withExtension: "txt") {
            do {
                let text = try String(contentsOf: url)
                let rows = text.components(separatedBy: CharacterSet.newlines).filter({ (s: String) -> Bool in
                    return !s.isEmpty
                })
                for row in rows {
                    let columns = row.components(separatedBy: CharacterSet.whitespaces).filter({ (s: String) -> Bool in
                        return !s.isEmpty
                    })
                    var value: Double = 0
                    var probabilities = [Double]()
                    let count = columns.count
                    if count > 0 {
                        for i in 0...count-1 {
                            switch i {
                            case 0:
                                value = Double(columns[i])!
                            case 1...13:
                                probabilities.append(Double(columns[i])!)
                            default:
                                break
                            }
                        }
                    }
                    let efficiency = NeutronSingleEfficiency(value: value, probabilities: probabilities)
                    data.append(efficiency)
                }
            } catch {
                print(error)
            }
        }
    }
    
    func calculate(info: [Int : Int]) -> String {
        guard let source = sfSource else {
            return ""
        }
        
        var result = "Efficiency calculation with \(source) source:"
        let n1 = Double(info[1] ?? 0)
        let n2 = Double(info[2] ?? 0)
        let n3 = Double(info[3] ?? 0)
        let n4 = max(Double(info[4] ?? 0), 1)
        let detected = ["1:2": n1/max(n2,1), "1:3": n1/max(n3,1), "2:3": n2/max(n3,1), "3:4": n3/max(n4,1), "2:4": n2/max(n4,1)]
        let ij = [(1, 2), (1, 3), (2, 3), (3, 4), (2, 4)]
        var dict = [String: NeutronSingleEfficiency]()
        for item in data {
            for t in ij {
                let i = t.0
                let j = t.1
                let new = item.probability(i: i, j: j)
                let key = "\(i):\(j)"
                let ratio = detected[key]!
                if let old = dict[key]?.probability(i: i, j: j) {
                    if fabs(new - ratio) < fabs(old - ratio) {
                        dict[key] = item
                    }
                } else {
                    dict[key] = item
                }
            }
        }
        for t in ij {
            let i = t.0
            let j = t.1
            let key = "\(i):\(j)"
            if let e = dict[key]?.value {
                result += "\n\(key) --- \(detected[key] ?? 0.0) --- \(e * 100)%"
            }
        }
        let efficiencies = dict.values.map { (e: NeutronSingleEfficiency) -> Double in
            return e.value
        }
        if efficiencies.count > 0 {
            result += "\nAverage efficiency: \(efficiencies.average() * 100) ± 1 %"
        }
        return result
    }
    
    class func efficiencyFor(measuredDistribution: [Double], sfCount: Int, source: SFSource) -> (Double, String)? {
        guard let ideal = source.idealDistribution() else {
            return nil
        }
        
        let maxMeasured = measuredDistribution.count
        let maxEmmited = ideal.count
        
        // Determine efficiency of detector
        var resultEfficiency: Double = 0
        var minSigma = Double.greatestFiniteMagnitude
        var chiSquaredInfo = [(Double, Double)]()
        for percent in 1...99 {
            let efficiency = Double(percent)/100.0
            print("\nEfficiency: \(efficiency)")
            var K: [[Double]] = Array(repeating: Array(repeating: 0, count: maxEmmited), count: maxMeasured) // Detector response matrix.
            for i in 0...maxMeasured-1 {
                for j in 0...maxEmmited-1 {
                    if i <= j {
                        // Mukhin et al. PEPAN Letters P6-2021-6
                        K[i][j] = (j.factorial() / (i.factorial() * (j - i).factorial())) * pow(efficiency, Double(i)) * pow(1 - efficiency, Double(j - i))
                    }
                }
            }
            print("Detector response matrix:")
            for i in 0...maxMeasured-1 {
                print(K[i].map{ String(format: "%.3f", $0) }.joined(separator: "\t"))
            }

            var expectedDistribution = [Double]()
            for i in 0...maxMeasured-1 {
                var sum = 0.0
                for j in 0...maxEmmited-1 {
                    sum += ideal[j] * K[i][j]
                }
                expectedDistribution.append(sum)
            }
            print("Expected distribution:")
            var sigma: Double = 0.0
            var chiSquared: Double = 0.0
            let count = expectedDistribution.count
            for i in 0...count-1 {
                print(expectedDistribution[i])
                sigma += pow(measuredDistribution[i] - expectedDistribution[i], 2)
                if measuredDistribution[i]*Double(sfCount) > 5.0 { // chi^2 limits
                    chiSquared += Double(sfCount)*pow(measuredDistribution[i] - expectedDistribution[i], 2)/expectedDistribution[i]
                }
            }
            sigma = sqrt(sigma)/Double(count)
            print("Sigma: \(sigma)")
            print("Chi^2: \(chiSquared)\n")
            chiSquaredInfo.append((efficiency, chiSquared))
            if sigma < minSigma {
                minSigma = sigma
                resultEfficiency = efficiency
            }
        }
        
        let chiSquaredString = chiSquaredInfo.map { return "\($0.0),\($0.1)" }.joined(separator: "\n")
        print("Efficiency | Chi^2:\n\(chiSquaredString)")
        
        print("Final efficiency: \(resultEfficiency)")
        return (resultEfficiency, chiSquaredString)
    }
    
}
