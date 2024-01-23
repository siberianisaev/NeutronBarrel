//
//  DetectorMatchItem.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 16/06/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

class DetectorMatchItem {
    
    var stripConfiguration: StripsConfiguration!
    var subMatches: [SearchType: DetectorMatch?]?
    
    fileprivate var _energy: Double?
    var energy: Double? {
        return _energy
    }
    
    fileprivate var _stripDetector: StripDetector?
    var stripDetector: StripDetector? {
        return _stripDetector
    }
    
    var strip1_N: Int? {
        if let encoder = encoder {
            return stripConfiguration.strip1_N_For(channel: encoder)
        }
        return nil
    }
    
    fileprivate var _encoder: CUnsignedShort?
    var encoder: CUnsignedShort? {
        return _encoder
    }
    
    fileprivate var _side: StripsSide?
    var side: StripsSide? {
        return _side
    }
    
    fileprivate var _eventNumber: CUnsignedLongLong?
    var eventNumber: CUnsignedLongLong? {
        return _eventNumber
    }
    
    fileprivate var _time: UInt64?
    var time: UInt64? {
        return _time
    }
    
    fileprivate var _deltaTime: CLongLong?
    var deltaTime: CLongLong? {
        return _deltaTime
    }
    
    fileprivate var _overflow: UInt8?
    var overflow: UInt8? {
        return _overflow
    }
    
    fileprivate var _inBeam: UInt8?
    var inBeam: UInt8? {
        return _inBeam
    }
    
    fileprivate var _channel: CUnsignedShort?
    var channel: CUnsignedShort? {
        return _channel
    }
    
    fileprivate var _value: Double?
    var value: Double? {
        return _value
    }
    
    fileprivate var _type: SearchType?
    var type: SearchType? {
        return _type
    }
    
    init(type: SearchType, stripDetector: StripDetector?, energy: Double? = nil, encoder: CUnsignedShort? = nil, eventNumber: CUnsignedLongLong? = nil, deltaTime: CLongLong? = nil, time: UInt64? = nil, overflow: UInt8? = nil, inBeam: UInt8? = nil, channel: CUnsignedShort? = nil, value: Double? = nil, subMatches: [SearchType: DetectorMatch?]? = nil, back: DetectorMatch? = nil, side: StripsSide?, stripConfiguration: StripsConfiguration) {
        self._type = type
        self._stripDetector = stripDetector
        self._energy = energy
        self._encoder = encoder
        self._eventNumber = eventNumber
        self._deltaTime = deltaTime
        self._time = time
        self._overflow = overflow
        self._inBeam = inBeam
        self._channel = channel
        self._value = value
        self.subMatches = subMatches
        self._side = side
        self.stripConfiguration = stripConfiguration
    }
    
}
