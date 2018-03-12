//
//  DetectorMatch.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 12/03/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

class DetectorMatch {
    
    fileprivate var items = [[String: Any]]()
    
    func getItems() -> [[String: Any]] {
        return items
    }
    
    func setItems(_ array: [[String: Any]]) {
        items = array
    }
    
    func itemAt(index: Int) -> [String: Any]? {
        if index < items.count {
            return items[index]
        } else {
            return nil
        }
    }
    
    func getValueAt(index: Int, key: String) -> Any? {
        return itemAt(index: index)?[key]
    }
    
    func removeAll() {
        items.removeAll()
    }
    
    var count: Int {
        return items.count
    }
    
    func append(_ item: [String: Any]) {
        items.append(item)
    }
    
    func itemWithMaxEnergy() -> [String: Any]? {
        let array: [Any] = items
        let dict = array.sorted(by: { (obj1: Any, obj2: Any) -> Bool in
            func energy(_ o: Any) -> Double {
                if let e = (o as! [String: Any])[Processor.singleton.kEnergy] {
                    return e as! Double
                }
                return 0
            }
            return energy(obj1) > energy(obj2)
        }).first as? [String: Any]
        return dict
    }
    
    func getSummEnergyFrom() -> Double? {
        if items.count == 0 {
            return nil
        }
        
        var summ: Double = 0
        for info in items {
            if let energy = info[Processor.singleton.kEnergy] {
                summ += energy as! Double
            }
        }
        return summ
    }
    
}
