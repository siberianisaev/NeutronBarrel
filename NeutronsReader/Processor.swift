//
//  Processor.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 26/04/2017.
//  Copyright © 2017 Andrey Isaev. All rights reserved.
//

import Foundation

class Processor: NSObject {
    
    var p: ISAProcessor! // used during mirgation to Swift phase
    
    @objc func forwardSearch(checker: @escaping ((ISAEvent, UnsafeMutablePointer<Bool>)->())) {
        while feof(p.file) != 1 {
            var event = ISAEvent()
            fread(&event, MemoryLayout<ISAEvent>.size, 1, p.file)
            
            var stop: Bool = false
            checker(event, &stop)
            if stop {
                return
            }
        }
    }
    
    @objc func forwardSearch(startTime: CUnsignedLongLong, minDeltaTime: CUnsignedLongLong, maxDeltaTime: CUnsignedLongLong, useCycleTime: Bool, updateCycleEvent: Bool, checker: @escaping ((ISAEvent, CUnsignedLongLong, UnsafeMutablePointer<Bool>)->())) {
        
        while feof(p.file) != 1 {
            var event = ISAEvent()
            fread(&event, MemoryLayout<ISAEvent>.size, 1, p.file)
            
            let id = Int(event.eventId)
            if updateCycleEvent {
                if id == p.dataProtocol.CycleTime {
                    p.mainCycleTimeEvent = event
                    continue
                }
            }
            
            if p.dataProtocol.isValidEventIdForTimeCheck(id) {
                let relativeTime = event.param1
                let time = useCycleTime ? p.time(relativeTime, cycle: p.mainCycleTimeEvent) : CUnsignedLongLong(relativeTime)
                let deltaTime = (time < startTime) ? (startTime - time) : (time - startTime)
                if deltaTime <= maxDeltaTime {
                    if deltaTime < minDeltaTime {
                        continue
                    }
                    
                    var stop: Bool = false
                    checker(event, deltaTime, &stop)
                    if stop {
                        return
                    }
                } else {
                    return
                }
            }
        }
    }
    
    // TODO: implement backward search

}
