//
//  EventStack.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 30.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

import Foundation

class EventStack: NSObject {
    
    fileprivate var data = [NSValue]()
    var maxSize: UInt = 5
    
    func events() -> [NSValue] {
        let data = self.data
        return data
    }
    
    func pushEvent(_ eventValue: NSValue?) {
        if let eventValue = eventValue {
            if (self.data.count > Int(self.maxSize)) {
                self.data.remove(at: 0)
            }
            self.data.append(eventValue)
        }
    }
    
    func clear() {
        self.data.removeAll(keepingCapacity: false)
    }
    
}
