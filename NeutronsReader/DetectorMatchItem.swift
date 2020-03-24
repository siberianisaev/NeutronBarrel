//
//  DetectorMatchItem.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 16/06/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

class DetectorMatchItem {
    
    var gamma: DetectorMatch?
    var back: DetectorMatch?
    
    fileprivate var _energy: Double?
    var energy: Double? {
        return _energy
    }
    
    fileprivate var _stripDetector: StripDetector?
    var stripDetector: StripDetector? {
        return _stripDetector
    }
    
    fileprivate var _strip1_N: Int?
    var strip1_N: Int? {
        if nil == _strip1_N, let strip0_15 = strip0_15, let encoder = encoder {
            if let side = side, let stripDetector = stripDetector {
                _strip1_N = StripDetectorManager.singleton.getStripConfigurations(stripDetector).strip1_N_For(side: side, encoder: Int(encoder), strip0_15: strip0_15)
            } else {
                print("Unable to calculate 'strip1_N': detector side was not determined!")
            }
        }
        return _strip1_N
    }
    
    fileprivate var _encoder: CUnsignedShort?
    var encoder: CUnsignedShort? {
        return _encoder
    }
    
    fileprivate var _strip0_15: CUnsignedShort?
    var strip0_15: CUnsignedShort? {
        return _strip0_15
    }
    
    fileprivate var _side: StripsSide?
    var side: StripsSide? {
        return _side
    }
    
    fileprivate var _eventNumber: CUnsignedLongLong?
    var eventNumber: CUnsignedLongLong? {
        return _eventNumber
    }
    
    fileprivate var _deltaTime: CLongLong?
    var deltaTime: CLongLong? {
        return _deltaTime
    }
    
    fileprivate var _marker: CUnsignedShort?
    var marker: CUnsignedShort? {
        return _marker
    }
    
    fileprivate var _channel: CUnsignedShort?
    var channel: CUnsignedShort? {
        return _channel
    }
    
    fileprivate var _value: Double?
    var value: Double? {
        return _value
    }
    
    init(stripDetector: StripDetector?, energy: Double? = nil, encoder: CUnsignedShort? = nil, strip0_15: CUnsignedShort? = nil, eventNumber: CUnsignedLongLong? = nil, deltaTime: CLongLong? = nil, marker: CUnsignedShort? = nil, channel: CUnsignedShort? = nil, value: Double? = nil, gamma: DetectorMatch? = nil, back: DetectorMatch? = nil, side: StripsSide?) {
        self._stripDetector = stripDetector
        self._energy = energy
        self._encoder = encoder
        self._strip0_15 = strip0_15
        self._eventNumber = eventNumber
        self._deltaTime = deltaTime
        self._marker = marker
        self._channel = channel
        self._value = value
        self.gamma = gamma
        self.back = back
        self._side = side
    }
    
}
