//
//  Event.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 26/04/2017.
//  Copyright © 2017 Andrey Isaev. All rights reserved.
//

import Foundation

class Event: NSObject {
    
    var data: ISAEvent
    
    init(data: ISAEvent) {
        self.data = data
        super.init()
    }
    
}
