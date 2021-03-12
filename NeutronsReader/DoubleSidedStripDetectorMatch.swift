//
//  DoubleSidedStripDetectorMatch.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 12/03/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

class DoubleSidedStripDetectorMatch {
    
    var currentEventTime: CUnsignedLongLong = 0
    
    fileprivate var front = DetectorMatch()
    fileprivate var back = DetectorMatch()
    
    func matchFor(side: StripsSide) -> DetectorMatch {
        return side == .front ? front : back
    }
    
    func firstItemsFor(side: StripsSide) -> DetectorMatchItem? {
        return matchFor(side: side).itemAt(index: 0)
    }
    
    func append(_ item: DetectorMatchItem, side: StripsSide) {
        matchFor(side: side).append(item)
    }
    
    func removeAll() {
        front.removeAll()
        back.removeAll()
    }
    
    var count: Int {
        return max(front.count, back.count)
    }
    
}
