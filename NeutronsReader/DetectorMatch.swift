//
//  DetectorMatch.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 12/03/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

class DetectorMatch {
    
    fileprivate var items = [DetectorMatchItem]()
    
    func itemAt(index: Int) -> DetectorMatchItem? {
        if index < items.count {
            return items[index]
        } else {
            return nil
        }
    }
    
    func removeAll() {
        items.removeAll()
    }
    
    var count: Int {
        return items.count
    }
    
    func append(_ item: DetectorMatchItem) {
        items.append(item)
    }
    
    func itemWithMaxEnergy() -> DetectorMatchItem? {
        let item = items.sorted(by: { (i1: DetectorMatchItem, i2: DetectorMatchItem) -> Bool in
            return (i1.energy ?? 0) > (i2.energy ?? 0)
        }).first
        return item
    }
    
    func filterItemsByMaxEnergy(maxStripsDelta: Int) {
        if count > 1, let item = itemWithMaxEnergy(), let strip1_N = item.strip1_N {
            let array = items.filter( { (i: DetectorMatchItem) -> Bool in
                if let s1_N = i.strip1_N {
                    return abs(Int32(strip1_N) - Int32(s1_N)) <= Int32(maxStripsDelta)
                } else {
                    return false
                }
            })
            items = array
        }
    }
    
    func getSummEnergyFrom() -> Double? {
        if items.count == 0 {
            return nil
        }
        
        var summ: Double = 0
        for item in items {
            if let energy = item.energy {
                summ += energy
            }
        }
        return summ
    }
    
}
