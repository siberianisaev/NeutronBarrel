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
    
    /**
     Note: use SearchDirection values in 'directions'.
     */
    @objc func search(directions: Set<NSNumber>, startTime: CUnsignedLongLong, minDeltaTime: CUnsignedLongLong, maxDeltaTime: CUnsignedLongLong, useCycleTime: Bool, updateCycleEvent: Bool, checker: @escaping ((ISAEvent, CUnsignedLongLong, CLongLong, UnsafeMutablePointer<Bool>)->())) {
        //TODO: работает в пределах одного файла
        if directions.contains(SearchDirection.backward.rawValue as NSNumber) {
            var initial = fpos_t()
            fgetpos(p.file, &initial)
            
            var cycleEvent = p.mainCycleTimeEvent
            var current = Int(initial)
            while current > -1 {
                current -= MemoryLayout<ISAEvent>.size
                fseek(p.file, current, SEEK_SET)
                
                var event = ISAEvent()
                fread(&event, MemoryLayout<ISAEvent>.size, 1, p.file)
                
                let id = Int(event.eventId)
                if id == p.dataProtocol.CycleTime {
                    cycleEvent = event
                    continue
                }
                
                if p.dataProtocol.isValidEventIdForTimeCheck(id) {
                    let relativeTime = event.param1
                    let time = useCycleTime ? p.time(relativeTime, cycle: cycleEvent) : CUnsignedLongLong(relativeTime)
                    let deltaTime = (time < startTime) ? (startTime - time) : (time - startTime)
                    if deltaTime <= maxDeltaTime {
                        if deltaTime < minDeltaTime {
                            continue
                        }
                        
                        var stop: Bool = false
                        checker(event, time, -(CLongLong)(deltaTime), &stop)
                        if stop {
                            return
                        }
                    } else {
                        break
                    }
                }
                
                fseek(p.file, Int(initial), SEEK_SET)
            }
        }
        
        if directions.contains(SearchDirection.forward.rawValue as NSNumber) {
            var cycleEvent = p.mainCycleTimeEvent
            while feof(p.file) != 1 {
                var event = ISAEvent()
                fread(&event, MemoryLayout<ISAEvent>.size, 1, p.file)
                
                let id = Int(event.eventId)
                if id == p.dataProtocol.CycleTime {
                    if updateCycleEvent {
                        p.mainCycleTimeEvent = event
                    }
                    cycleEvent = event
                    continue
                }
            
                if p.dataProtocol.isValidEventIdForTimeCheck(id) {
                    let relativeTime = event.param1
                    let time = useCycleTime ? p.time(relativeTime, cycle: cycleEvent) : CUnsignedLongLong(relativeTime)
                    let deltaTime = (time < startTime) ? (startTime - time) : (time - startTime)
                    if deltaTime <= maxDeltaTime {
                        if deltaTime < minDeltaTime {
                            continue
                        }
                        
                        var stop: Bool = false
                        checker(event, time, CLongLong(deltaTime), &stop)
                        if stop {
                            return
                        }
                    } else {
                        return
                    }
                }
            }
        }
    }

}
