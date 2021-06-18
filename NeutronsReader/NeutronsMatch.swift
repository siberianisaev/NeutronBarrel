//
//  NeutronsMatch.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 12.03.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Foundation

struct NeutronCT {
    
    var R: UInt16 = 0
    var W: UInt16 = 0
    
    init(event: Event) {
        R = (event.param3 & 0xE0) >> 5
        W = (event.param3 & 0x700) >> 8
    }
}

class NeutronsMatch {
    
    var times = [Float]()
    var encoders = [UInt16]()
    var counters = [Int]()
    var NSum: CUnsignedLongLong = 0
    
    var averageTime: Float {
        return times.average()
    }
    
    var count: Int {
        return times.count
    }
    
    func isValidTimes() -> Bool {
        if encoders.count > 0 {
            var encWithTimes = [UInt16: [Float]]()
            for i in 0...encoders.count-1 {
                let enc = encoders[i]
                var values = encWithTimes[enc] ?? []
                values.append(times[i])
                encWithTimes[enc] = values
            }
            for (_, value) in encWithTimes {
                if !value.isAscending() { // ascending broken
                    return false
                }
            }
        }
        return true
    }
    
}
