//
//  NeutronsMatch.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 12.03.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Foundation

class NeutronsMatch {
    
    var times = [Float]()
    var counters = [Int]()
    var NSum: CUnsignedLongLong = 0
    
    var averageTime: Float {
        return times.average()
    }
    
    var count: Int {
        return times.count
    }
    
}
