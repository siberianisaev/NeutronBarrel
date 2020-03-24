//
//  DoubleSidedStripDetectorSingleMatch.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 12/02/2019.
//  Copyright © 2019 Flerov Laboratory. All rights reserved.
//

import Cocoa

class DoubleSidedStripDetectorSingleMatch {

    fileprivate var front: DetectorMatchItem?
    fileprivate var back: DetectorMatchItem?
    
    func itemFor(side: StripsSide) -> DetectorMatchItem? {
        return side == .front ? front : back
    }
    
    func setItem(_ item: DetectorMatchItem?, forSide side: StripsSide) {
        side == .front ? (front = item) : (back = item)
    }
    
    func removeAll() {
        front = nil
        back = nil
    }
    
}
