//
//  Calibration.swift
//  Modane
//
//  Created by Andrey Isaev on 29/10/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

class Efficiency {
    
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

class Calibration {
    
    var data = [Efficiency]()
    
    class var singleton : Calibration {
        struct Static {
            static let sharedInstance : Calibration = Calibration()
        }
        return Static.sharedInstance
    }
    
    init() {
        if let url = Bundle.main.url(forResource: "Fn_U238_12new", withExtension: "txt") {
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
                    let efficiency = Efficiency(value: value, probabilities: probabilities)
                    data.append(efficiency)
                }
            } catch {
                print(error)
            }
        }
    }
    
}
