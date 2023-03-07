//
//  DetectorMatch.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 12/03/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

class DetectorMatch {
    
    fileprivate var items: [DetectorMatchItem]
    
    init() {
        self.items = []
    }
    
    init(items: [DetectorMatchItem]) {
        self.items = items
    }
    
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
        return DetectorMatch.getItemWithMaxEnergy(items)
    }
    
    /*
     Used for Recoil signals.
     */
    class func getItemWithMaxEnergy(_ items: [DetectorMatchItem]) -> DetectorMatchItem? {
        if items.count > 1 {
            let item = items.sorted(by: { (i1: DetectorMatchItem, i2: DetectorMatchItem) -> Bool in
                return (i1.energy ?? 0) > (i2.energy ?? 0)
            }).first
            return item
        } else {
            return items.first
        }
    }
    
    /*
     Used for divided per strips Fission fragments signals.
     */
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
    
    func getSumEnergy() -> Double? {
        if items.count == 0 {
            return nil
        }
        
        var sum: Double = 0
        for item in items {
            if let energy = item.energy {
                sum += energy
            }
        }
        return sum
    }
    
}
