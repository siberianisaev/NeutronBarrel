//
//  NeutronDetector.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 11.05.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Foundation

class NeutronDetector {
    
    fileprivate var locations = [Int: CGPoint]()
    
    /**
     Counter coordinates (in mm).
     */
    class func pointFor(counter: Int) -> CGPoint? {
        return singleton.locations[counter]
    }
    
    class var singleton : NeutronDetector {
        struct Static {
            static let sharedInstance : NeutronDetector = NeutronDetector()
        }
        return Static.sharedInstance
    }
    
    init() {
        if let url = Bundle.main.url(forResource: "SFiNx_counters_geometry", withExtension: "csv") {
            do {
                let text = try String(contentsOf: url)
                for row in text.components(separatedBy: CharacterSet.newlines).filter({ !$0.isEmpty }) {
                    let values = row.components(separatedBy: ";")
                    if values.count == 3, let counter = Int(values[0]), let x = Double(values[1]), let y = Double(values[2]) {
                        // TODO: convert them to mm in csv
                        locations[counter] = CGPoint(x: x * 10, y: y * 10)
                    }
                }
            } catch {
                print(error)
            }
        }
    }
    
}
