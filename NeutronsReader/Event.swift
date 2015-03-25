//
//  Event.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 25.03.15.
//  Copyright (c) 2015 Andrey Isaev. All rights reserved.
//

import Foundation

enum EventId: Int {
    case FissionFront1 = 1
    case FissionFront2 = 2
    case FissionFront3 = 3
    case FissionBack1 = 4
    case FissionBack2 = 5
    case FissionBack3 = 6
    case FissionDaughterFront1 = 7
    case FissionDaughterFront2 = 8
    case FissionDaughterFront3 = 9
    case FissionDaughterBack1 = 10
    case FissionDaughterBack2 = 11
    case FissionDaughterBack3 = 12
    case FissionWell1 = 13
    case FissionWell2 = 14
    case Gamma1 = 15
    case TOF = 17
    case Neutrons = 23
    case CycleTime = 24
    case FON = 29
    case RecoilSpecial = 30
}

enum Mask: Int {
    case Fission, FON, RecoilSpecial = 0x0FFF
    case Gamma, TOF, Recoil = 0x1FFF
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
            (EventId.FissionFront1 == rawEventId || EventId.FissionFront2 == rawEventId || EventId.FissionFront3 == rawEventId ||
                EventId.FissionDaughterFront1 == rawEventId || EventId.FissionDaughterFront2 == rawEventId || EventId.FissionDaughterFront3 == rawEventId)
    }
    
    func isFissionWel() -> Bool {
        return isFissionMarkerPresent() &&
            (EventId.FissionWell1 == rawEventId || EventId.FissionWell2 == rawEventId)
    }
    
    func isFissionBack() -> Bool {
        return isFissionMarkerPresent() &&
            (EventId.FissionBack1 == rawEventId || EventId.FissionBack2 == rawEventId || EventId.FissionBack3 == rawEventId
                || EventId.FissionDaughterBack1 == rawEventId || EventId.FissionDaughterBack2 == rawEventId || EventId.FissionDaughterBack3 == rawEventId)
    }
    
    func isRecoilFront() -> Bool {
        return isRecoilMarkerPresent() &&
            (EventId.FissionFront1 == rawEventId || EventId.FissionFront2 == rawEventId || EventId.FissionFront3 == rawEventId)
    }
    
    func isRecoilBack() -> Bool {
        return isRecoilMarkerPresent() &&
            (EventId.FissionBack1 == rawEventId || EventId.FissionBack2 == rawEventId || EventId.FissionBack3 == rawEventId)
    }
    
    /**
    Не у всех событий в базе, вторые 16 бит слова отводятся под время.
    */
    func isValidEventForTimeCheck() -> Bool {
        return (eventId <= CUnsignedShort(EventId.FissionWell2.rawValue) || EventId.TOF == rawEventId || EventId.Gamma1 == rawEventId || EventId.Neutrons == rawEventId);
    }
}
