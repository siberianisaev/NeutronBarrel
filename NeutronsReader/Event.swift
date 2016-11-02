//
//  Event.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 25.03.15.
//  Copyright (c) 2015 Andrey Isaev. All rights reserved.
//

import Foundation

enum EventId: Int {
    case fissionFront1 = 1
    case fissionFront2 = 2
    case fissionFront3 = 3
    case fissionBack1 = 4
    case fissionBack2 = 5
    case fissionBack3 = 6
    case fissionDaughterFront1 = 7
    case fissionDaughterFront2 = 8
    case fissionDaughterFront3 = 9
    case fissionDaughterBack1 = 10
    case fissionDaughterBack2 = 11
    case fissionDaughterBack3 = 12
    case fissionWell1 = 13
    case fissionWell2 = 14
    case gamma1 = 15
    case tof = 17
    case neutrons = 23
    case cycleTime = 24
    case fon = 29
    case recoilSpecial = 30
}

enum Mask: Int {
    case fission, fon, recoilSpecial = 0x0FFF
    case gamma, tof, recoil = 0x1FFF
}

struct Event {
    var eventId: CUnsignedShort
    var param1: CUnsignedShort
    var param2: CUnsignedShort
    var param3: CUnsignedShort
    
    var rawEventId: EventId? {
        return EventId(rawValue: Int(eventId))
    }
    /**
    Маркер отличающий осколок (0b000 = 0) от рекойла (0b100 = 4), записывается в первые 3 бита param3.
    */
    var marker: CUnsignedShort {
        return param3 >> 13
    }
    
    func isFissionMarkerPresent() -> Bool {
        return marker == 0b000
    }
    
    func isRecoilMarkerPresent() -> Bool {
        return marker == 0b100
    }
    
    func isFissionFront() -> Bool {
        return isFissionMarkerPresent() &&
            (EventId.fissionFront1 == rawEventId || EventId.fissionFront2 == rawEventId || EventId.fissionFront3 == rawEventId ||
                EventId.fissionDaughterFront1 == rawEventId || EventId.fissionDaughterFront2 == rawEventId || EventId.fissionDaughterFront3 == rawEventId)
    }
    
    func isFissionWel() -> Bool {
        return isFissionMarkerPresent() &&
            (EventId.fissionWell1 == rawEventId || EventId.fissionWell2 == rawEventId)
    }
    
    func isFissionBack() -> Bool {
        return isFissionMarkerPresent() &&
            (EventId.fissionBack1 == rawEventId || EventId.fissionBack2 == rawEventId || EventId.fissionBack3 == rawEventId
                || EventId.fissionDaughterBack1 == rawEventId || EventId.fissionDaughterBack2 == rawEventId || EventId.fissionDaughterBack3 == rawEventId)
    }
    
    func isRecoilFront() -> Bool {
        return isRecoilMarkerPresent() &&
            (EventId.fissionFront1 == rawEventId || EventId.fissionFront2 == rawEventId || EventId.fissionFront3 == rawEventId)
    }
    
    func isRecoilBack() -> Bool {
        return isRecoilMarkerPresent() &&
            (EventId.fissionBack1 == rawEventId || EventId.fissionBack2 == rawEventId || EventId.fissionBack3 == rawEventId)
    }
    
    /**
    Не у всех событий в базе, вторые 16 бит слова отводятся под время.
    */
    func isValidEventForTimeCheck() -> Bool {
        return (eventId <= CUnsignedShort(EventId.fissionWell2.rawValue) || EventId.tof == rawEventId || EventId.gamma1 == rawEventId || EventId.neutrons == rawEventId);
    }
}
