//
//  NeutronTotalEfficiency.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 12.04.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Foundation

enum SFSource: String {
    case U238 = "U238", Cm248 = "Cm248"
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
    
    fileprivate func neutronsCalculatedDistributionFor(efficiency: Double, measuredDistribution: [Double], source: SFSource) -> [Double]? {
        if source != .Cm248 {
            return nil
        }
        
        let maxMeasured = measuredDistribution.count
        let maxEmmited = 12

        var K: [[Double]] = Array(repeating: Array(repeating: 0, count: maxEmmited), count: maxMeasured) // Detector response matrix.
        for i in 0...maxMeasured-1 {
            for j in 0...maxEmmited-1 {
                if i <= j {
                    // Mukhin et al. PEPAN Letters P6-2021-6
                    K[i][j] = (j.factorial() / (i.factorial() * (j - i).factorial())) * pow(efficiency, Double(i)) * pow(1 - efficiency, Double(j - i))
                }
            }
        }
        print("K(i,j)\n")
        for i in 0...maxMeasured-1 {
            print(K[i].map{ String(format: "%.3f", $0) }.joined(separator: "\t"))
        }
        
        /*
        248Cm neutrons probabilities from work:
        Norman E. Holden & Martin S. Zucker (1986) Prompt neutron multiplicities for the transplutonium nuclides, Radiation Effects, 96:1-4, 289-292, DOI:
        10.1080/00337578608211755
         */
        let ideal248Cm = [0.00674,
                          0.05965,
                          0.22055,
                          0.35090,
                          0.25438,
                          0.08935,
                          0.01674,
                          0.00169,
                          0.00740]

        var result = [Double]()
        for i in 0...maxMeasured-1 {
            var sum = 0.0
            for j in 0...maxEmmited-1 {
                sum += ideal248Cm[j] * K[i][j]
            }
            result.append(sum)
        }
        print("\n\nResult K*Ideal:\n")
        for v in result {
            print(v)
        }
        return result
    }
    
}
