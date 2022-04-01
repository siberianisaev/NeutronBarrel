//
//  NeutronsMatch.swift
//  NeutronBarrel
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
    
}
